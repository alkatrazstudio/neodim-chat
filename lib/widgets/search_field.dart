// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

class SearchField extends StatefulWidget {
  const SearchField({
    required this.onChanged
  });

  final void Function(String) onChanged;

  @override
  State<SearchField> createState() => SearchFieldState();
}

class SearchFieldState extends State<SearchField> {
  final controller = TextEditingController();

  @override
  Widget build(context) {
    return TextField(
      onChanged: (text) {
        text = text.trim().toLowerCase();
        widget.onChanged(text);
      },
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search...',
        contentPadding: const EdgeInsets.all(10),
        suffixIcon: IconButton(
          onPressed: () {
            controller.clear();
            widget.onChanged('');
          },
          icon: const Icon(Icons.clear)
        )
      ),
    );
  }
}