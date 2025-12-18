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
    required this.stopStringMatch,
    required this.stopStringMatchIsSentenceEnd
  });

  final String generatedText;
  final String stopStringMatch;
  final bool stopStringMatchIsSentenceEnd;

  String get outputText {
    var text = generatedText;
    if(stopStringMatchIsSentenceEnd)
      text = text + stopStringMatch;
    return text.trimRight();
  }
}
