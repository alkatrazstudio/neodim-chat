// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

Future<String?> showInputDialog(
    BuildContext context,
    String title,
    String initialText
) async {
  void submit(BuildContext ctx, String text) {
    text = text.trim();
    if(text.isEmpty || text == initialText)
      Navigator.of(context).pop();
    else
      Navigator.of(context).pop(text);
  }

  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final inputController = TextEditingController();
      inputController.text = initialText;

      return AlertDialog(
        title: Text(title),
        content: TextField(
          minLines: 1,
          maxLines: 5,
          autofocus: true,
          controller: inputController,
          textInputAction: TextInputAction.go,
          onSubmitted: (text) {
            submit(context, text);
          }
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              submit(context, inputController.text);
            }
          )
        ]
      );
    }
  );
}

Future<bool> showConfirmDialog(
    BuildContext context,
    String title,
    String text
) async {
  return (await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(context).pop()
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.of(context).pop(true)
          )
        ]
      );
    }
  )) ?? false;
}
