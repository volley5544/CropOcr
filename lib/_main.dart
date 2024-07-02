import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'result_page.dart'; // Import the new page

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => DrawingModel(),
      child: MaterialApp(
        title: 'Draw Rectangles on Image',
        home: DrawingPage(),
      ),
    ),
  );
}

class DrawingPage extends StatelessWidget {
  final GlobalKey _globalKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Draw Rectangles on Image'),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: () => _pickImage(context),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              Provider.of<DrawingModel>(context, listen: false).clearRectangles();
            },
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () => _sendDataToServer(context),
          ),
        ],
      ),
      body: Consumer<DrawingModel>(
        builder: (context, drawingModel, child) {
          return drawingModel.imageFile == null
              ? Center(child: Text('No image selected.'))
              : Stack(
            children: [
              RepaintBoundary(
                key: _globalKey,
                child: GestureDetector(
                  onPanStart: (details) {
                    drawingModel.startDrawing(details.localPosition);
                  },
                  onPanUpdate: (details) {
                    drawingModel.updateDrawing(details.localPosition);
                  },
                  onPanEnd: (details) {
                    drawingModel.endDrawing();
                  },
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            File(drawingModel.imageFile!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: DrawingPainter(drawingModel.rectangles),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      Provider.of<DrawingModel>(context, listen: false).setImageFile(image);
    }
  }

  Future<void> _sendDataToServer(BuildContext context) async {
    final drawingModel = Provider.of<DrawingModel>(context, listen: false);

    if (drawingModel.imageFile == null || drawingModel.rectangles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image or rectangles to send.')),
      );
      return;
    }

    File imageFile = File(drawingModel.imageFile!.path);
    img.Image? image = img.decodeImage(await imageFile.readAsBytes());

    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decode image.')),
      );
      return;
    }

    int imageWidth = image.width;
    int imageHeight = image.height;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height - kToolbarHeight;

    var request = http.MultipartRequest('POST', Uri.parse('https://ef0b-115-31-145-24.ngrok-free.app/extract-position'));

    List<String> topLefts = [];
    List<String> bottomRights = [];

    for (var rect in drawingModel.rectangles) {
      double topLeftX = rect.left * imageWidth / screenWidth;
      double topLeftY = (rect.top * imageHeight / screenHeight);
      double bottomRightX = rect.right * imageWidth / screenWidth;
      double bottomRightY = (rect.bottom * imageHeight / screenHeight);

      topLefts.add('[${topLeftX.toStringAsFixed(2)},${topLeftY.toStringAsFixed(2)}]');
      bottomRights.add('[${bottomRightX.toStringAsFixed(2)},${bottomRightY.toStringAsFixed(2)}]');
    }
    print(topLefts);
    print(bottomRights);
    request.fields.addAll({
      'top_left': topLefts.join(','),
      'bottom_right': bottomRights.join(','),
    });
    request.files.add(await http.MultipartFile.fromPath('image', drawingModel.imageFile!.path));

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);
      List<String> texts = (jsonResponse['texts'] as List).map((item) => item['text'] as String).toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(texts: texts),
        ),
      );
    }  else {
      print(response.reasonPhrase);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send data: ${response.reasonPhrase}')),
      );
    }
  }
}

class DrawingPainter extends CustomPainter {
  final List<Rect> rectangles;

  DrawingPainter(this.rectangles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final rect in rectangles) {
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class DrawingModel with ChangeNotifier {
  XFile? _imageFile;
  List<Rect> _rectangles = [];
  Rect? _currentRect;

  XFile? get imageFile => _imageFile;
  List<Rect> get rectangles => _rectangles;

  void setImageFile(XFile imageFile) {
    _imageFile = imageFile;
    notifyListeners();
  }

  void clearRectangles() {
    _rectangles.clear();
    notifyListeners();
  }

  void startDrawing(Offset startPoint) {
    _currentRect = Rect.fromPoints(startPoint, startPoint);
    _rectangles.add(_currentRect!); // Start drawing immediately
    notifyListeners();
  }

  void updateDrawing(Offset currentPoint) {
    if (_currentRect != null) {
      _currentRect = Rect.fromPoints(_currentRect!.topLeft, currentPoint);
      _rectangles[_rectangles.length - 1] = _currentRect!;
      notifyListeners();
    }
  }

  void endDrawing() {
    _currentRect = null;
    notifyListeners();
  }
}
