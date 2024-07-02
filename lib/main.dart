import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'result_page.dart';
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

class DrawingPage extends StatefulWidget {
  @override
  _DrawingPageState createState() => _DrawingPageState();
}


class _DrawingPageState extends State<DrawingPage> {
  String? _selectedField;
  GlobalKey _appBarKey = GlobalKey();
  double _appBarHeight = kToolbarHeight;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBarHeight = _appBarKey.currentContext?.size?.height ?? kToolbarHeight;
      setState(() {
        _appBarHeight = appBarHeight;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        key: _appBarKey,
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
      body: Column(
        children: [
          DropdownButton<String>(
            hint: Text("Select field to draw"),
            value: _selectedField,
            onChanged: (String? newValue) {
              setState(() {
                _selectedField = newValue;
              });
            },
            items: <String>[
              'car_regis', 'body_number', 'thai_ID', 'name',
              'book_number', 'engine_number', 'car_type', 'brand'
            ].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          Expanded(
            child: Consumer<DrawingModel>(
              builder: (context, drawingModel, child) {
                return drawingModel.imageFile == null
                    ? Center(child: Text('No image selected.'))
                    : GestureDetector(
                  onPanStart: (details) {
                    if (_selectedField != null) {
                      drawingModel.startDrawing(details.localPosition, _selectedField!);
                    }
                  },
                  onPanUpdate: (details) {
                    drawingModel.updateDrawing(details.localPosition);
                  },
                  onPanEnd: (details) {
                    drawingModel.endDrawing();
                  },
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
                );
              },
            ),
          ),
        ],
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
    print(_appBarHeight);
    print(kToolbarHeight);
    int imageWidth = image.width;
    int imageHeight = image.height;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    // print("imageWidth: $imageWidth");
    // print("imageHeight: $imageHeight");
    // print("screenWidth: $screenWidth");
    // print("screenHeight: $screenHeight");
    var request = http.MultipartRequest('POST', Uri.parse('https://69d6-115-31-145-24.ngrok-free.app/detect-position'));
    var halfkToolbarHeight = (kToolbarHeight+_appBarHeight)/2;
    drawingModel.rectangleFields.forEach((rect, field) {
      double topLeftX = rect.left * imageWidth / screenWidth;
      double topLeftY = (rect.top+kToolbarHeight) * imageHeight / screenHeight;
      double bottomRightX = rect.right * imageWidth / screenWidth;
      double bottomRightY = (rect.bottom+kToolbarHeight) * imageHeight / screenHeight;
      print("topLeftY: $topLeftY");
      print("bottomRightY: $bottomRightY");
      request.fields[field] = '[[${topLeftX.toInt()},${topLeftY.toInt()}],[${bottomRightX.toInt()},${bottomRightY.toInt()}]]';
    });

    request.files.add(await http.MultipartFile.fromPath('image', drawingModel.imageFile!.path));

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (jsonResponse['texts'] is Map<String, dynamic>) {
        Map<String, String> detectedFields = jsonResponse['texts'].cast<String, String>();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultPage(texts: detectedFields),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected response format: "texts" is not a map.')),
        );
      }
    } else {
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
  Map<Rect, String> _rectangleFields = {};
  Rect? _currentRect;
  String? _currentField;

  XFile? get imageFile => _imageFile;
  List<Rect> get rectangles => _rectangles;
  Map<Rect, String> get rectangleFields => _rectangleFields;

  void setImageFile(XFile imageFile) {
    _imageFile = imageFile;
    _rectangles.clear();
    _rectangleFields.clear();
    notifyListeners();
  }

  void startDrawing(Offset startPoint, String field) {
    _currentRect = Rect.fromPoints(startPoint, startPoint);
    _currentField = field;
    notifyListeners();
  }

  void updateDrawing(Offset currentPoint) {
    if (_currentRect != null) {
      _currentRect = Rect.fromPoints(_currentRect!.topLeft, currentPoint);
      notifyListeners();
    }
  }

  void endDrawing() {
    if (_currentRect != null && _currentField != null) {
      _rectangles.add(_currentRect!);
      _rectangleFields[_currentRect!] = _currentField!;
      _currentRect = null;
      _currentField = null;
      notifyListeners();
    }
  }

  void clearRectangles() {
    _rectangles.clear();
    _rectangleFields.clear();
    notifyListeners();
  }
}
