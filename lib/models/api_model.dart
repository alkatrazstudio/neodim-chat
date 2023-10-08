// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/foundation.dart';

import '../apis/response.dart';

class ApiModel extends ChangeNotifier {
  ApiResponse? lastResponse;
  bool isApiRunning = false;

  void setResponse(ApiResponse response) {
    lastResponse = response;
    notifyListeners();
  }

  void setApiRunning(bool newValue) {
    isApiRunning = newValue;
    notifyListeners();
  }
}
