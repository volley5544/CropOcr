import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DrawingModel extends ChangeNotifier {
  List<Rect> _rectangles = [];
  Offset? _startPoint;
  Offset? _endPoint;
  double? _canvasWidth;
  double? _canvasHeight;
  XFile? _imageFile;

  List<Rect> get rectangles => _rectangles;
  XFile? get imageFile => _imageFile;

  void setImageFile(XFile imageFile) {
    _imageFile = imageFile;
    notifyListeners();
  }

  void startDrawing(Offset startPoint) {
    _startPoint = startPoint;
    notifyListeners();
  }

  void updateDrawing(Offset endPoint) {
    _endPoint = endPoint;
    notifyListeners();
  }

  void endDrawing() {
    if (_startPoint != null && _endPoint != null) {
      final rect = Rect.fromPoints(_startPoint!, _endPoint!);
      _rectangles.add(rect);
    }
    _startPoint = null;
    _endPoint = null;
    notifyListeners();
  }

  void clearDrawings() {
    _rectangles.clear();
    notifyListeners();
  }

  void setCanvasSize(double width, double height) {
    _canvasWidth = width;
    _canvasHeight = height;
    notifyListeners();
  }

  List<Rect> getScaledRectangles(double targetWidth, double targetHeight) {
    if (_canvasWidth == null || _canvasHeight == null) return [];

    double widthRatio = targetWidth / _canvasWidth!;
    double heightRatio = targetHeight / _canvasHeight!;

    return _rectangles.map((rect) {
      return Rect.fromLTRB(
        rect.left * widthRatio,
        rect.top * heightRatio,
        rect.right * widthRatio,
        rect.bottom * heightRatio,
      );
    }).toList();
  }
}
