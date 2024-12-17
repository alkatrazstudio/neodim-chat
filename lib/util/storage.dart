// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/services.dart';

abstract class Storage {
  static const platform = MethodChannel('neodim_chat.alkatrazstudio.net/storage');

  static Future<String?> saveFile(String initialFilename, String mime, Uint8List bytes) async {
    var uri = await platform.invokeMethod<String?>('saveFile', {
      'initialFilename': initialFilename,
      'mime': mime,
      'bytes': bytes
    });
    return uri;
  }

  static Future<Uint8List?> loadFile(String mime) async {
    var bytes = await platform.invokeMethod<Uint8List?>('loadFile', {
      'mime': mime
    });
    return bytes;
  }
}
