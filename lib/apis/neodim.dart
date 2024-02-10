// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../apis/request.dart';
import '../apis/response.dart';
import '../models/api_model.dart';
import '../models/conversations.dart';
import '../models/messages.dart';

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
    this.repetitionPenaltyIncludeGenerated = RepPenGenerated.slide,
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
    this.wordsBlacklistAtStart,
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
  final RepPenGenerated repetitionPenaltyIncludeGenerated;
  final bool repetitionPenaltyTruncateToInput;
  final String? repetitionPenaltyPrompt;
  final int sequencesCount;
  final List<String> stopStrings;
  final StopStringsType stopStringsType;
  final int stopStringsRequiredMatchesCount;
  final List<String> truncatePromptUntil;
  final List<String>? wordsWhitelist;
  final List<String>? wordsBlacklist;
  final List<String>? wordsBlacklistAtStart;
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
      'repetition_penalty_include_generated': repetitionPenaltyIncludeGenerated.name,
      'repetition_penalty_truncate_to_input': repetitionPenaltyTruncateToInput,
      'repetition_penalty_prompt': repetitionPenaltyPrompt,
      'sequences_count': sequencesCount,
      'stop_strings': stopStrings,
      'stop_strings_type': stopStringsType.name,
      'stop_strings_required_matches_count': stopStringsRequiredMatchesCount,
      'truncate_prompt_until': truncatePromptUntil,
      'words_whitelist': wordsWhitelist,
      'words_blacklist': wordsBlacklist,
      'required_server_version': requiredServerVersion,
      'no_repeat_ngram_size': noRepeatNGramSize,
      'words_blacklist_at_start': wordsBlacklistAtStart
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

  Future<NeodimResponse> run(NeodimRequest req, ApiModel apiModel) async {
    var reqData = req.toApiRequestMap();
    apiModel.startRawRequest(reqData);
    var reqJson = jsonEncode(reqData);
    var response = await http.post(endpoint,
      headers: {
        'Content-Type': 'application/json'
      },
      body: reqJson
    );
    var respJson = response.body;
    var respData = jsonDecode(respJson) as Map<String, dynamic>;
    apiModel.endRawRequest(respData);
    if(respData.containsKey('error')) {
      String error = respData['error'] as String;
      throw Exception(error);
    }

    var resp = NeodimResponse.fromApiResponseMap(respData);
    return resp;
  }
}

class ApiRequestNeodim {
  static const String requiredServerVersion = '>=0.13';

  static NeodimRequest? getRequest(ApiRequestParams params) {
    List<String> truncatePromptUntil;
    List<String> stopStrings;
    List<String>? wordsWhitelist;

    var stopStringsType = StopStringsType.string;
    int sequencesCount;
    int? noRepeatNGramSize;
    if(params.participantNames != null) {
      truncatePromptUntil = [MessagesModel.messageSeparator];
      stopStrings = [MessagesModel.chatPromptSeparator];
      sequencesCount = 1;
      wordsWhitelist = List.from(params.participantNames!);
      wordsWhitelist.add(MessagesModel.chatPromptSeparator);
      noRepeatNGramSize = null;
    } else {
      switch(params.conversation.type)
      {
        case ConversationType.chat:
        case ConversationType.groupChat:
          truncatePromptUntil = [MessagesModel.messageSeparator];
          break;

        case ConversationType.adventure:
          truncatePromptUntil = [...MessagesModel.sentenceStops, MessagesModel.actionPrompt];
          break;

        case ConversationType.story:
          truncatePromptUntil = MessagesModel.sentenceStops;
          break;

        default:
          return null;
      }
      stopStrings = ApiRequest.getPlainTextStopStrings(params.msgModel, params.conversation);
      if(params.cfgModel.stopOnPunctuation) {
        stopStrings = stopStrings.map(RegExp.escape).toList();
        stopStrings.add(MessagesModel.sentenceStopsRx);
        stopStringsType = StopStringsType.regex;
      }
      sequencesCount = 1 + params.cfgModel.extraRetries;
      noRepeatNGramSize = params.cfgModel.noRepeatNGramSize;
    }

    List<String> wordsBlacklist = params.blacklistWordsForRetry?.toList() ?? [];

    var request = NeodimRequest(
      prompt: params.inputText,
      preamble: params.cfgModel.inputPreamble,
      generatedTokensCount: params.cfgModel.generatedTokensCount,
      maxTotalTokens: params.cfgModel.maxTotalTokens,
      temperature: params.cfgModel.temperature,
      topP: (params.cfgModel.topP == 0 || params.cfgModel.topP == 1)  ? null : params.cfgModel.topP,
      topK: params.cfgModel.topK == 0 ? null : params.cfgModel.topK,
      tfs: (params.cfgModel.tfs == 0 || params.cfgModel.tfs == 1) ? null : params.cfgModel.tfs,
      typical: (params.cfgModel.typical == 0 || params.cfgModel.typical == 1) ? null : params.cfgModel.typical,
      topA: params.cfgModel.topA == 0 ? null : params.cfgModel.topA,
      penaltyAlpha: params.cfgModel.penaltyAlpha == 0 ? null : params.cfgModel.penaltyAlpha,
      warpersOrder: params.cfgModel.warpersOrder,
      repetitionPenalty: params.cfgModel.repetitionPenalty,
      repetitionPenaltyRange: params.cfgModel.repetitionPenaltyRange,
      repetitionPenaltySlope: params.cfgModel.repetitionPenaltySlope,
      repetitionPenaltyIncludePreamble: params.cfgModel.repetitionPenaltyIncludePreamble,
      repetitionPenaltyIncludeGenerated: params.cfgModel.repetitionPenaltyIncludeGenerated,
      repetitionPenaltyTruncateToInput: params.cfgModel.repetitionPenaltyTruncateToInput,
      repetitionPenaltyPrompt: params.repPenText,
      sequencesCount: sequencesCount,
      stopStrings: stopStrings,
      stopStringsType: stopStringsType,
      truncatePromptUntil: truncatePromptUntil,
      wordsWhitelist: wordsWhitelist,
      wordsBlacklist: wordsBlacklist,
      wordsBlacklistAtStart: ['\n', '<'], // typical tokens that may end the inference
      noRepeatNGramSize: noRepeatNGramSize,
      requiredServerVersion: requiredServerVersion
    );
    return request;
  }

  static ApiResponse toResponse(NeodimResponse response) {
    var sequences = response.sequences.map((seq) => ApiResponseSequence(
      generatedText: seq.generatedText,
      stopStringMatch: seq.stopStringMatch,
      stopStringMatchIsSentenceEnd: seq.stopString == MessagesModel.sentenceStopsRx
    )).toList();
    var gpus = response.gpus.map((gpu) => ApiResponseGpu(
      memoryFreeMin: gpu.memoryFreeMin,
      memoryTotal: gpu.memoryTotal
    )).toList();
    var result = ApiResponse(
      sequences: sequences,
      usedPrompt: response.usedPrompt,
      gpus: gpus
    );
    return result;
  }

  static Future<ApiResponse?> run(ApiRequestParams params) async {
    var request = getRequest(params);
    if(request == null)
      return null;
    var endpoint = ApiRequest.normalizeEndpoint(params.cfgModel.apiEndpoint, 8787, '/generate');
    final api = NeodimApi(endpoint: endpoint);
    var response = await api.run(request, params.apiModel);
    var result = toResponse(response);
    return result;
  }
}
