import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/drawing_model.dart';
import '../widgets/drawing_painter.dart';
import 'result_page.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => DrawingModel(),
      child: MaterialApp(
        title: 'Crop Image',
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
  GlobalKey _containerKey = GlobalKey();
  double _appBarHeight = kToolbarHeight;
  Size? _imageSize;
  Size? _containerSize;
  Rect? _draggedRect;
  Offset? _dragStartOffset;
  Offset? _rectStartOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBarHeight =
          _appBarKey.currentContext?.size?.height ?? kToolbarHeight;
      setState(() {
        _appBarHeight = appBarHeight;
      });
    });
  }

  Future<Size> _getImageSize(File imageFile) async {
    final Completer<Size> completer = Completer();
    final Image image = Image.file(imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(
            Size(info.image.width.toDouble(), info.image.height.toDouble()));
      }),
    );
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        key: _appBarKey,
        title: Text('Crop Image'),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: () => _pickImage(context),
          ),
          IconButton(
            icon: Icon(Icons.undo),
            onPressed: () {
              Provider.of<DrawingModel>(context, listen: false).removeLastRectangle();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              Provider.of<DrawingModel>(context, listen: false)
                  .clearRectangles();
            },
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: () => _sendDataToServer(context),
          ),
        ],
      ),
      body: Center(child:
        Column(
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
              'car_regis',
              'body_number',
              'thai_ID',
              'name',
              'book_number',
              'engine_number',
              'car_type',
              'brand'
            ].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          // if (_imageSize != null)
          //   Text('Image Size: ${_imageSize!.width} x ${_imageSize!.height}'),
          // Text(
          //     'Screen Size: ${screenSize.width} x ${screenSize.height - _appBarHeight}'),
          Expanded(
            child: Consumer<DrawingModel>(
              builder: (context, drawingModel, child) {
                return drawingModel.imageFile == null
                    ? Center(child: Text('No image selected.'))
                    : FutureBuilder<Size>(
                  future:
                  _getImageSize(File(drawingModel.imageFile!.path)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      _imageSize = snapshot.data;
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onPanStart: (details) => _onPanStart(details, drawingModel),
                          onPanUpdate: (details) => _onPanUpdate(details, drawingModel),
                          onPanEnd: (details) => _onPanEnd(details, drawingModel),
                          child: Container(
                            key: _containerKey,
                            color: Colors.blue,
                            child: Stack(
                              children: [
                                Image.file(
                                  File(drawingModel.imageFile!.path),
                                  fit: BoxFit.cover,
                                ),
                                CustomPaint(
                                  painter: DrawingPainter(drawingModel.rectangles, drawingModel.rectangleFields),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      ),

    );
  }

  void _onPanStart(DragStartDetails details, DrawingModel drawingModel) {
    final tappedRect = drawingModel.rectangles.firstWhere(
          (rect) => rect.contains(details.localPosition),
      orElse: () => Rect.zero,
    );
    if (tappedRect != Rect.zero) {
      drawingModel.startDragging(tappedRect, details.localPosition);
    } else if (_selectedField != null) {
      drawingModel.startDrawing(details.localPosition, _selectedField!);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, DrawingModel drawingModel) {
    drawingModel.updateDraggedRect(details.localPosition);
    if (_selectedField != null) {
      drawingModel.updateDrawing(details.localPosition);
    }
  }

  void _onPanEnd(DragEndDetails details, DrawingModel drawingModel) {
    drawingModel.endDragging();
    if (_selectedField != null) {
      drawingModel.endDrawing();
    }
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

    // Get the RenderBox of the Container using the GlobalKey
    final containerBox =
    _containerKey.currentContext!.findRenderObject() as RenderBox;
    _containerSize = containerBox.size;

    // Now you can access _containerSize.width and _containerSize.height

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

    var request = http.MultipartRequest(
        'POST', Uri.parse('https://eb4d-49-231-1-82.ngrok-free.app/detect-position'));
    drawingModel.rectangleFields.forEach((rect, field) {
      double topLeftX = rect.left * imageWidth / _containerSize!.width;
      double topLeftY = rect.top * imageHeight / _containerSize!.height;
      double bottomRightX = rect.right * imageWidth / _containerSize!.width;
      double bottomRightY = rect.bottom * imageHeight / _containerSize!.height;

      request.fields[field] =
      '[[${topLeftX.toInt()},${topLeftY.toInt()}],[${bottomRightX.toInt()},${bottomRightY.toInt()}]]';
    });

    request.files.add(await http.MultipartFile.fromPath(
        'image', drawingModel.imageFile!.path));

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      String responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);

      if (jsonResponse['texts'] is Map<String, dynamic>) {
        Map<String, String> detectedFields =
        jsonResponse['texts'].cast<String, String>();

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




