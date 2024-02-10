// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/foundation.dart';

import '../apis/response.dart';

class ApiModel extends ChangeNotifier {
  ApiResponse? lastResponse;
  bool isApiRunning = false;

  Map<String, dynamic>? rawRequest;
  Map<String, dynamic>? rawResponse;
  int requestStartMsecs = 0;
  int requestMsecs = 0;

  void setResponse(ApiResponse response) {
    lastResponse = response;
    notifyListeners();
  }

  void setApiRunning(bool newValue) {
    isApiRunning = newValue;
    notifyListeners();
  }

  void startRawRequest(Map<String, dynamic>? req) {
    rawRequest = req;
    rawResponse = null;
    requestStartMsecs = DateTime.now().millisecondsSinceEpoch;
    requestMsecs = 0;
    notifyListeners();
  }

  void endRawRequest(Map<String, dynamic>? resp) {
    rawResponse = resp;
    requestMsecs = DateTime.now().millisecondsSinceEpoch - requestStartMsecs;
    notifyListeners();
  }
}
