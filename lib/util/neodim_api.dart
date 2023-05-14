// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';

import 'package:http/http.dart' as http;

class NeodimRepPenGenerated {
  static const String ignore = 'ignore';
  static const String expand = 'expand';
  static const String slide = 'slide';
}

class StopStringsType {
  static const String string = 'string';
  static const String regex = 'regex';
}

class NeodimWarper {
  static const String repetitionPenalty = 'repetition_penalty';
  static const String temperature = 'temperature';
  static const String topK = 'top_k';
  static const String topP = 'top_p';
  static const String typical = 'typical';
  static const String tfs = 'tfs';
  static const String topA = 'top_a';

  static const List<String> defaultOrder = [
    repetitionPenalty,
    temperature,
    topK,
    topP,
    tfs,
    typical,
    topA
  ];
}

class NeodimRequest {
  const NeodimRequest({
    required this.prompt,
    required this.generatedTokensCount,
    required this.maxTotalTokens,
    this.temperature,
    this.topK,
    this.topP,
    this.tfs,
    this.typical,
    this.topA,
    this.penaltyAlpha,
    this.warpersOrder,
    this.repetitionPenalty,
    this.repetitionPenaltyRange,
    this.repetitionPenaltySlope,
    this.repetitionPenaltyIncludePreamble = false,
    this.repetitionPenaltyIncludeGenerated = NeodimRepPenGenerated.slide,
    this.repetitionPenaltyTruncateToInput = false,
    this.repetitionPenaltyPrompt,
    this.preamble = '',
    this.sequencesCount = 1,
    this.stopStrings = const [],
    this.stopStringsType = StopStringsType.string,
    this.stopStringsRequiredMatchesCount = 1,
    this.truncatePromptUntil = const [],
    this.wordsWhitelist,
    this.wordsBlacklist,
    this.requiredServerVersion,
    this.noRepeatNGramSize
  });

  final String prompt;
  final String preamble;
  final int generatedTokensCount;
  final int maxTotalTokens;
  final double? temperature;
  final int? topK;
  final double? topP;
  final double? tfs;
  final double? typical;
  final double? topA;
  final double? penaltyAlpha;
  final List<String>? warpersOrder;
  final double? repetitionPenalty;
  final int? repetitionPenaltyRange;
  final double? repetitionPenaltySlope;
  final bool repetitionPenaltyIncludePreamble;
  final String repetitionPenaltyIncludeGenerated;
  final bool repetitionPenaltyTruncateToInput;
  final String? repetitionPenaltyPrompt;
  final int sequencesCount;
  final List<String> stopStrings;
  final String stopStringsType;
  final int stopStringsRequiredMatchesCount;
  final List<String> truncatePromptUntil;
  final List<String>? wordsWhitelist;
  final List<String>? wordsBlacklist;
  final String? requiredServerVersion;
  final int? noRepeatNGramSize;

  Map<String, dynamic> toApiRequestMap() {
    return <String, dynamic> {
      'prompt': prompt,
      'preamble': preamble,
      'generated_tokens_count': generatedTokensCount,
      'max_total_tokens': maxTotalTokens,
      'temperature': temperature,
      'top_k': topK,
      'top_p': topP,
      'tfs': tfs,
      'typical': typical,
      'top_a': topA,
      'penalty_alpha': penaltyAlpha,
      'warpers_order': warpersOrder,
      'repetition_penalty': repetitionPenalty,
      'repetition_penalty_range': repetitionPenaltyRange,
      'repetition_penalty_slope': repetitionPenaltySlope,
      'repetition_penalty_include_preamble': repetitionPenaltyIncludePreamble,
      'repetition_penalty_include_generated': repetitionPenaltyIncludeGenerated,
      'repetition_penalty_truncate_to_input': repetitionPenaltyTruncateToInput,
      'repetition_penalty_prompt': repetitionPenaltyPrompt,
      'sequences_count': sequencesCount,
      'stop_strings': stopStrings,
      'stop_strings_type': stopStringsType,
      'stop_strings_required_matches_count': stopStringsRequiredMatchesCount,
      'truncate_prompt_until': truncatePromptUntil,
      'words_whitelist': wordsWhitelist,
      'words_blacklist': wordsBlacklist,
      'required_server_version': requiredServerVersion,
      'no_repeat_ngram_size': noRepeatNGramSize
    };
  }
}

class NeodimSequence {
  const NeodimSequence({
    required this.generatedText,
    required this.stopString,
    required this.stopStringMatch,
    required this.trimmedTail,
    required this.repetitionPenaltyTextAtEnd
  });

  final String generatedText;
  final String stopString;
  final String stopStringMatch;
  final String trimmedTail;
  final String repetitionPenaltyTextAtEnd;

  static NeodimSequence fromApiResponseMap(Map<String, dynamic> data) {
    return NeodimSequence(
      generatedText: data['generated_text'] as String,
      stopString: data['stop_string'] as String,
      stopStringMatch: data['stop_string_match'] as String,
      trimmedTail: data['trimmed_tail'] as String,
      repetitionPenaltyTextAtEnd: data['repetition_penalty_text_at_end'] as String
    );
  }
}

class NeodimGpu {
  NeodimGpu({
    required this.name,
    required this.memoryTotal,
    required this.memoryReservedStart,
    required this.memoryAllocatedStart,
    required this.memoryFreeStart,
    required this.memoryReservedEnd,
    required this.memoryAllocatedEnd,
    required this.memoryFreeEnd,
    required this.memoryReservedMin,
    required this.memoryAllocatedMin,
    required this.memoryFreeMin,
    required this.memoryReservedMax,
    required this.memoryAllocatedMax,
    required this.memoryFreeMax
  });

  final String name;
  final int memoryTotal;
  final int memoryReservedStart;
  final int memoryAllocatedStart;
  final int memoryFreeStart;
  final int memoryReservedEnd;
  final int memoryAllocatedEnd;
  final int memoryFreeEnd;
  final int memoryReservedMin;
  final int memoryAllocatedMin;
  final int memoryFreeMin;
  final int memoryReservedMax;
  final int memoryAllocatedMax;
  final int memoryFreeMax;

  static NeodimGpu fromApiResponseMap(Map<String, dynamic> data) {
    return NeodimGpu(
      name: data['name'] as String,
      memoryTotal: data['memory_total'] as int,
      memoryReservedStart: data['memory_reserved_start'] as int,
      memoryAllocatedStart: data['memory_allocated_start'] as int,
      memoryFreeStart: data['memory_free_start'] as int,
      memoryReservedEnd: data['memory_reserved_end'] as int,
      memoryAllocatedEnd: data['memory_allocated_end'] as int,
      memoryFreeEnd: data['memory_free_end'] as int,
      memoryReservedMin: data['memory_reserved_min'] as int,
      memoryAllocatedMin: data['memory_allocated_min'] as int,
      memoryFreeMin: data['memory_free_min'] as int,
      memoryReservedMax: data['memory_reserved_max'] as int,
      memoryAllocatedMax: data['memory_allocated_max'] as int,
      memoryFreeMax: data['memory_free_max'] as int
    );
  }
}

class NeodimResponse {
  const NeodimResponse({
    required this.originalInputTokensCount,
    required this.usedInputTokensCount,
    required this.preambleTokensCount,
    required this.usedPrompt,
    required this.originalPromptTokensCount,
    required this.usedPromptTokensCount,
    required this.repetitionPenaltyTextAtStart,
    required this.usedRepetitionPenaltyTokensCountAtStart,
    required this.usedRepetitionPenaltyTokensCountAtEnd,
    required this.usedRepetitionPenaltyRangeAtStart,
    required this.usedRepetitionPenaltyRangeAtEnd,
    required this.generatedTokensCount,
    required this.outputTokensCount,
    required this.sequences,
    required this.gpus
  });

  final int originalInputTokensCount;
  final int usedInputTokensCount;
  final int preambleTokensCount;
  final String usedPrompt;
  final int originalPromptTokensCount;
  final int usedPromptTokensCount;
  final String repetitionPenaltyTextAtStart;
  final int usedRepetitionPenaltyTokensCountAtStart;
  final int usedRepetitionPenaltyTokensCountAtEnd;
  final int usedRepetitionPenaltyRangeAtStart;
  final int usedRepetitionPenaltyRangeAtEnd;
  final int generatedTokensCount;
  final int outputTokensCount;
  final List<NeodimSequence> sequences;
  final List<NeodimGpu> gpus;

  static NeodimResponse fromApiResponseMap(Map<String, dynamic> data) {
    return NeodimResponse(
      originalInputTokensCount: data['original_input_tokens_count'] as int,
      usedInputTokensCount: data['used_input_tokens_count'] as int,
      preambleTokensCount: data['preamble_tokens_count'] as int,
      usedPrompt: data['used_prompt'] as String,
      originalPromptTokensCount: data['original_prompt_tokens_count'] as int,
      usedPromptTokensCount: data['used_prompt_tokens_count'] as int,
      repetitionPenaltyTextAtStart: data['repetition_penalty_text_at_start'] as String,
      usedRepetitionPenaltyTokensCountAtStart: data['used_repetition_penalty_tokens_count_at_start'] as int,
      usedRepetitionPenaltyTokensCountAtEnd: data['used_repetition_penalty_tokens_count_at_end'] as int,
      usedRepetitionPenaltyRangeAtStart: data['used_repetition_penalty_range_at_start'] as int,
      usedRepetitionPenaltyRangeAtEnd: data['used_repetition_penalty_range_at_end'] as int,
      generatedTokensCount: data['generated_tokens_count'] as int,
      outputTokensCount: data['output_tokens_count'] as int,
      sequences: (data['sequences'] as List<dynamic>)
        .map((dynamic s) => NeodimSequence.fromApiResponseMap(s as Map<String, dynamic>))
        .toList(),
      gpus: (data['gpus'] as List<dynamic>)
        .map((dynamic s) => NeodimGpu.fromApiResponseMap(s as Map<String, dynamic>))
        .toList()
    );
  }
}

class NeodimApi {
  NeodimApi({
    required String endpoint
  }) {
    this.endpoint = Uri.parse(endpoint);
  }

  late final Uri endpoint;

  Future<NeodimResponse> run(NeodimRequest req) async {
    var reqData = req.toApiRequestMap();
    var reqJson = jsonEncode(reqData);

    var response = await http.post(endpoint,
      headers: {
        'Content-Type': 'application/json'
      },
      body: reqJson
    );

    var respJson = response.body;
    var respData = jsonDecode(respJson) as Map<String, dynamic>;
    if(respData.containsKey('error')) {
      String error = respData['error'] as String;
      throw Exception(error);
    }

    var resp = NeodimResponse.fromApiResponseMap(respData);
    return resp;
  }
}
