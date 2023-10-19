// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:neodim_chat/apis/request.dart';

import '../apis/response.dart';
import '../models/conversations.dart';
import '../models/messages.dart';

class LlamaCppRequest {
  const LlamaCppRequest({
    this.temperature,
    this.topK,
    this.topP,
    required this.nPredict,
    required this.nKeep,
    required this.prompt,
    this.stop,
    this.tfsZ,
    this.typicalP,
    this.repeatPenalty,
    this.repeatLastN,
    this.grammar,
    this.ignoreEos,
    this.logitBias
  });

  final double? temperature;
  final int? topK;
  final double? topP;
  final int nPredict;
  final int nKeep;
  final String prompt;
  final List<String>? stop;
  final double? tfsZ;
  final double? typicalP;
  final double? repeatPenalty;
  final int? repeatLastN;
  final String? grammar;
  final bool? ignoreEos;
  final List<(int, dynamic)>? logitBias;

  Map<String, dynamic> toApiRequestMap() {
    return <String, dynamic> {
      'temperature': temperature,
      'top_k': topK,
      'top_p': topP,
      'n_predict': nPredict,
      'n_keep': nKeep,
      'prompt': prompt,
      'stop': stop,
      'tfs_z': tfsZ,
      'typical_p': typicalP,
      'repeat_penalty': repeatPenalty,
      'repeat_last_n': repeatLastN,
      'grammar': grammar,
      'ignore_eos': ignoreEos,
      'logit_bias': logitBias?.map((b) => [b.$1, b.$2]).toList()
    };
  }
}

class LlamaCppResponse {
  const LlamaCppResponse({
    required this.content,
    required this.stoppingWord
  });

  final String content;
  final String stoppingWord;

  static LlamaCppResponse fromApiResponseMap(Map<String, dynamic> data) {
    return LlamaCppResponse(
      content: data['content'] as String,
      stoppingWord: data['stopping_word'] as String
    );
  }
}

class ApiRequestLlamaCpp {
  static Future<Map<String, dynamic>> runRaw(String endpoint, Map<String, dynamic> data) async {
    var reqJson = jsonEncode(data);
    var endpointUri = Uri.parse(endpoint);
    var response = await http.post(endpointUri,
      headers: {
        'Content-Type': 'application/json'
      },
      body: reqJson
    );
    var respJson = response.body;
    var resp = jsonDecode(respJson) as Map<String, dynamic>;
    return resp;
  }

  static Future<List<int>> tokenize(String endpoint, String content) async {
    var response = await runRaw('$endpoint/tokenize', {'content': content});
    var tokens = (response['tokens'] as List<dynamic>).map((token) => token as int).toList();
    return tokens;
  }

  static Future<String> detokenize(String endpoint, List<int> tokens) async {
    var response = await runRaw('$endpoint/detokenize', {'tokens': tokens});
    var content = response['content'] as String;
    return content;
  }

  static Future<ApiResponse?> run(ApiRequestParams params) async {
    var endpoint = ApiRequest.normalizeEndpoint(params.cfgModel.apiEndpoint, 8080, '');

    int preambleTokensCount;

    // llama.cpp truncates the input prompt automatically depending on m_predict and n_keep params
    // and then caches all inference results needed to predict the next token.
    // Manually truncating the prompt will result in a cache miss.
    // That's why we need to pass all the preamble and prompt unmodified.
    var allInput = params.inputText;
    var preamble = params.cfgModel.inputPreamble;
    if(preamble.isNotEmpty) {
      preambleTokensCount = (await tokenize(endpoint, preamble)).length;
      allInput = preamble + allInput;
    } else {
      preambleTokensCount = 0;
    }

    List<int> promptTokens;
    List<int> usedPromptTokens;
    if(params.inputText.isEmpty) {
      promptTokens = [];
      usedPromptTokens = [];
    } else {
      promptTokens = await tokenize(endpoint, params.inputText);
      var allowedPromptTokensCount = params.cfgModel.maxTotalTokens - preambleTokensCount - params.cfgModel.generatedTokensCount - 1;
      if(allowedPromptTokensCount <= 0)
        throw Exception('No tokens left for prompt.');
      allowedPromptTokensCount = min(allowedPromptTokensCount, promptTokens.length);
      usedPromptTokens = promptTokens.sublist(promptTokens.length - allowedPromptTokensCount);
    }

    var maxRepeatLastN = params.cfgModel.repetitionPenaltyIncludePreamble
        ? (usedPromptTokens.length + preambleTokensCount)
        : usedPromptTokens.length;

    String? grammar;
    List<String> stopStrings;
    if(params.participantNames != null) {
      stopStrings = [MessagesModel.chatPromptSeparator];
      var jsonNames = params.participantNames!.map((name) => jsonEncode(name));
      var rules = jsonNames.join(' | ');
      var separatorJson = jsonEncode(MessagesModel.chatPromptSeparator);
      grammar = 'root ::= ($rules) $separatorJson';
    } else {
      stopStrings = ApiRequest.getPlainTextStopStrings(params.msgModel, params.conversation);
    }

    List<int> bannedTokens = [];
    if(params.blacklistWordsForRetry != null) {
      for(var word in params.blacklistWordsForRetry!) {
        var tokens = await tokenize(endpoint, word);
        bannedTokens += tokens;
      }
    }
    var logitBias = bannedTokens.toSet().map((token) => (token, false)).toList();

    var request = LlamaCppRequest(
      temperature: params.cfgModel.temperature != 0 ? params.cfgModel.temperature : 1,
      topK: params.cfgModel.topK,
      topP: params.cfgModel.topP != 0 ? params.cfgModel.topP : 1,
      nPredict: params.cfgModel.generatedTokensCount,
      nKeep: preambleTokensCount,
      prompt: allInput,
      stop: stopStrings,
      tfsZ: params.cfgModel.tfs != 0 ? params.cfgModel.tfs : 1,
      typicalP: params.cfgModel.typical != 0 ? params.cfgModel.typical : 1,
      repeatPenalty: params.cfgModel.repetitionPenalty != 0 ? params.cfgModel.repetitionPenalty : 1,
      repeatLastN: min(params.cfgModel.repetitionPenaltyRange, maxRepeatLastN),
      grammar: grammar,
      ignoreEos: grammar == null,
      logitBias: logitBias
    );

    var requestMap = request.toApiRequestMap();
    var responseMap = await runRaw('$endpoint/completion', requestMap);
    var response = LlamaCppResponse.fromApiResponseMap(responseMap);

    String usedPrompt;
    if(usedPromptTokens.length == promptTokens.length) {
      usedPrompt = params.inputText;
    } else {
      usedPrompt = await detokenize(endpoint, usedPromptTokens);
      if(usedPrompt.startsWith(' '))
        usedPrompt = usedPrompt.substring(1);
    }

    var result = ApiResponse(
      sequences: [ApiResponseSequence(
        generatedText: response.content,
        stopStringMatch: response.stoppingWord,
        stopStringMatchIsSentenceEnd: false
      )],
      usedPrompt: usedPrompt,
      gpus: []
    );

    return result;
  }
}
