// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

void showPopupMsg(BuildContext ctx, String msg) {
  if(!ctx.mounted)
    return;
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg))
  );
}
