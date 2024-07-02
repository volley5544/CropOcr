import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  final Map<String, String> texts;

  ResultPage({required this.texts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: texts.length,
          itemBuilder: (context, index) {
            String key = texts.keys.elementAt(index);
            return ListTile(
              title: Text('$key: ${texts[key]}'),
            );
          },
        ),
      ),
    );
  }
}