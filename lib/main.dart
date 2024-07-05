import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/drawing_model.dart';
import 'screens/drawing_page.dart';

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