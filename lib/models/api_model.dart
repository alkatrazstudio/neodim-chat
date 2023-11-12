// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/foundation.dart';

import '../apis/response.dart';

class ApiModel extends ChangeNotifier {
  ApiResponse? lastResponse;
  bool isApiRunning = false;

  Map<String, dynamic>? rawRequest;
  Map<String, dynamic>? rawResponse;

  void setResponse(ApiResponse response) {
    lastResponse = response;
    notifyListeners();
  }

  void setApiRunning(bool newValue) {
    isApiRunning = newValue;
    notifyListeners();
  }

  void setRawRequest(Map<String, dynamic>? req) {
    rawRequest = req;
    notifyListeners();
  }

  void setRawResponse(Map<String, dynamic>? resp) {
    rawResponse = resp;
    notifyListeners();
  }
}
