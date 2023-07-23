// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

class ChatButton extends StatelessWidget {
  const ChatButton({
    required this.onPressed,
    required this.isEnabled,
    required this.icon,
    this.flipIcon = false
  });

  final Function(bool isLong) onPressed;
  final bool isEnabled;
  final IconData icon;
  final bool flipIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: isEnabled ? () => onPressed(true) : null,
      child: IconButton(
        onPressed: isEnabled ? () => onPressed(false) : null,
        icon: Transform.scale(
          scaleX: flipIcon ? -1 : 1,
          child: Icon(icon),
        )
      )
    );
  }
}
