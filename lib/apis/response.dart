// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

class ApiResponse {
  const ApiResponse({
    required this.sequences
  });

  final List<ApiResponseSequence> sequences;
}

class ApiResponseSequence {
  const ApiResponseSequence({
    required this.generatedText,
    required this.stopStringMatch
  });

  final String generatedText;
  final String stopStringMatch;

  String get outputText {
    var text = generatedText;
    return text.trimRight();
  }
}
