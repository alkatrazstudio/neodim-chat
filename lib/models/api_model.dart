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
  double requestSecs = 0;
  double tokensPerSecond = 0;

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
    requestSecs = 0;
    tokensPerSecond = 0;
    notifyListeners();
  }

  void endRawRequest(Map<String, dynamic>? resp, int generatedTokensCount) {
    rawResponse = resp;
    requestSecs = (DateTime.now().millisecondsSinceEpoch - requestStartMsecs) / 1000;
    if(requestSecs > 0 && generatedTokensCount > 0)
      tokensPerSecond = generatedTokensCount / requestSecs;
    notifyListeners();
  }
}
