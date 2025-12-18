// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/foundation.dart';

import '../apis/response.dart';

class ApiModel extends ChangeNotifier {
  ApiResponse? lastResponse;
  var isApiRunning = false;
  var maxContextLength = 0;
  var currentContextLength = 0;
  var promptProgressTotal = 0;
  var promptProgressProcessed = 0;

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

  void setContextStats(int maxLength, int currentLength) {
    maxContextLength = maxLength;
    currentContextLength = currentLength;
    notifyListeners();
  }

  void setPromptProgress(int total, int processed) {
    promptProgressTotal = total;
    promptProgressProcessed = processed;
    notifyListeners();
  }

  void resetStats() {
    setContextStats(0, 0);
    setPromptProgress(0, 0);
  }
}

class ApiCancelModel extends ChangeNotifier {
  void Function()? cancelFunc;

  void setCancelFunc(void Function()? newCancelFunc) {
    cancelFunc = newCancelFunc;
    notifyListeners();
  }
}

class ApiCancelException implements Exception {
}
