import 'package:flutter/material.dart';

class TextToolDialog extends StatefulWidget {
  final Color color;
  const TextToolDialog({super.key, required this.color});

  @override
  State<TextToolDialog> createState() => _TextToolDialogState();
}

class _TextToolDialogState extends State<TextToolDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add text'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(fontSize: 20, color: widget.color),
        decoration: InputDecoration(
          hintText: 'Type something...',
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black),
          ),
        ),
        onSubmitted: (text) {
          if (text.trim().isNotEmpty) Navigator.pop(context, text.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.black)),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: const Text('Add', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
