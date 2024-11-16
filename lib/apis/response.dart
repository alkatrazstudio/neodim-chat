// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

class ApiResponse {
  const ApiResponse({
    required this.sequences,
    required this.usedPrompt,
    required this.gpus
  });

  final List<ApiResponseSequence> sequences;
  final String usedPrompt;
  final List<ApiResponseGpu> gpus;
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

class ApiResponseGpu {
  const ApiResponseGpu({
    required this.memoryFreeMin,
    required this.memoryTotal
  });

  final int memoryFreeMin;
  final int memoryTotal;
}
