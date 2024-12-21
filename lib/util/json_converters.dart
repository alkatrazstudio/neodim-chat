// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

class ColorJsonConverter implements JsonConverter<Color, int> {
  const ColorJsonConverter();

  @override
  Color fromJson(int json) => Color(json);

  static int _floatToInt8(double x) {
    return (x * 255.0).round() & 0xff;
  }

  static int colorToInt(Color color) {
    return _floatToInt8(color.a) << 24 |
      _floatToInt8(color.r) << 16 |
      _floatToInt8(color.g) << 8 |
      _floatToInt8(color.b) << 0;
  }

  @override
  int toJson(Color object) => colorToInt(object);
}
