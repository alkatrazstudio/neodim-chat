// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/foundation.dart';

import '../util/neodim_api.dart';

class NeodimModel extends ChangeNotifier {
  NeodimRequest? lastRequest;
  NeodimResponse? lastResponse;
  bool isApiRunning = false;

  void setRequest(NeodimRequest request) {
    lastRequest = request;
    notifyListeners();
  }

  void setResponse(NeodimResponse response) {
    lastResponse = response;
    notifyListeners();
  }

  void setApiRunning(bool newValue) {
    isApiRunning = newValue;
    notifyListeners();
  }
}
