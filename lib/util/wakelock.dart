// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/services.dart';

abstract class Wakelock {
  static const platform = MethodChannel('net.alkatrazstudio.neodim_chat/wakelock');

  static Future<void> set(bool enable) async {
    await platform.invokeMethod('set', enable);
  }
}
