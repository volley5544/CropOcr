import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DrawingModel with ChangeNotifier {
  XFile? _imageFile;
  List<Rect> _rectangles = [];
  Map<Rect, String> _rectangleFields = {};
  Rect? _currentRect;
  String? _currentField;
  XFile? get imageFile => _imageFile;
  List<Rect> get rectangles => _rectangles;
  Map<Rect, String> get rectangleFields => _rectangleFields;
  Rect? _draggedRect;
  Offset? _dragOffset;

  void setImageFile(XFile imageFile) {
    _imageFile = imageFile;
    _rectangles.clear();
    _rectangleFields.clear();
    notifyListeners();
  }

  void startDrawing(Offset startPoint, String field) {
    _currentRect = Rect.fromPoints(startPoint, startPoint);
    _currentField = field;
    _rectangles.add(_currentRect!);
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
    if (_currentRect != null && _currentField != null) {
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

  void updateRectPosition(Rect oldRect, Offset newTopLeft) {
    final index = _rectangles.indexOf(oldRect);
    if (index != -1) {
      final newRect = Rect.fromLTWH(newTopLeft.dx, newTopLeft.dy, oldRect.width, oldRect.height);
      _rectangles[index] = newRect;
      final field = _rectangleFields.remove(oldRect);
      if (field != null) {
        _rectangleFields[newRect] = field;
      }
      notifyListeners();
    }
  }
  void startDragging(Rect rect, Offset position) {
    _draggedRect = rect;
    _dragOffset = rect.topLeft - position;
    notifyListeners();
  }

  void updateDraggedRect(Offset newPosition) {
    if (_draggedRect != null && _dragOffset != null) {
      final newTopLeft = newPosition + _dragOffset!;
      final newRect = Rect.fromLTWH(
        newTopLeft.dx,
        newTopLeft.dy,
        _draggedRect!.width,
        _draggedRect!.height,
      );

      final index = _rectangles.indexOf(_draggedRect!);
      if (index != -1) {
        _rectangles[index] = newRect;
        final field = _rectangleFields.remove(_draggedRect!);
        if (field != null) {
          _rectangleFields[newRect] = field;
        }
        _draggedRect = newRect;
        notifyListeners();
      }
    }
  }
  void endDragging() {
    _draggedRect = null;
    _dragOffset = null;
    notifyListeners();
  }
}
