// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/foundation.dart';

import '../apis/response.dart';

enum ApiAvailabilityMode {
  notAvailable,
  loading,
  available
}

class ApiResponseProcessingStats {
  const ApiResponseProcessingStats({
    required this.index,
    required this.totalPromptTokensCount,
    required this.processedPromptTokensCount,
    required this.promptProcessingSecs,
    required this.generatedTokensCount,
    required this.tokenGenerationSecs,
  });

  final int index;
  final int totalPromptTokensCount;
  final int processedPromptTokensCount;
  final double promptProcessingSecs;
  final int generatedTokensCount;
  final double tokenGenerationSecs;
}

class ApiModel extends ChangeNotifier {
  ApiResponse? lastResponse;
  var isApiRunning = false;
  var maxContextLength = 0;
  var currentContextLength = 0;
  var promptProgressTotal = 0;
  var promptProgressProcessed = 0;
  var availability = ApiAvailabilityMode.notAvailable;

  Map<String, dynamic>? rawRequest;
  dynamic rawResponse;

  DateTime? requestStart;
  DateTime? requestEnd;
  var processingStatsArray = <ApiResponseProcessingStats>[];

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
    requestStart = DateTime.now();
    requestEnd = null;
    processingStatsArray = [];
    notifyListeners();
  }

  void endRawRequest(dynamic resp, List<ApiResponseProcessingStats> stats) {
    rawResponse = resp;
    requestEnd = DateTime.now();
    processingStatsArray = stats;
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

  void setAvailability(ApiAvailabilityMode newAvailability) {
    availability = newAvailability;
    notifyListeners();
  }
}

class ApiCancelModel extends ChangeNotifier {
  void Function()? cancelFunc;

  void setCancelFunc(void Function()? newCancelFunc) {
    cancelFunc = newCancelFunc;
    notifyListeners();
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

class ApiCancelException implements Exception {
}
