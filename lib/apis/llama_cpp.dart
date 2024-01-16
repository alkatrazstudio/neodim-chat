// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:neodim_chat/models/config.dart';

import '../apis/request.dart';
import '../apis/response.dart';
import '../models/messages.dart';

class LlamaCppRequest {
  const LlamaCppRequest({
    required this.temperature,
    required this.topK,
    required this.topP,
    required this.nPredict,
    required this.nKeep,
    required this.prompt,
    required this.stop,
    required this.tfsZ,
    required this.typicalP,
    required this.mirostat,
    required this.mirostatTau,
    required this.mirostatEta,
    required this.repeatPenalty,
    required this.repeatLastN,
    required this.penaltyPrompt,
    required this.grammar,
    required this.ignoreEos,
    required this.logitBias
  });

  final double temperature;
  final int topK;
  final double topP;
  final int nPredict;
  final int nKeep;
  final String prompt;
  final List<String> stop;
  final double tfsZ;
  final double typicalP;
  final int mirostat;
  final double mirostatTau;
  final double mirostatEta;
  final double repeatPenalty;
  final String? penaltyPrompt;
  final int repeatLastN;
  final String? grammar;
  final bool ignoreEos;
  final List<(int, dynamic)> logitBias;

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
      'mirostat': mirostat,
      'mirostat_tau': mirostatTau,
      'mirostat_eta': mirostatEta,
      'repeat_penalty': repeatPenalty,
      'repeat_last_n': repeatLastN,
      'penalty_prompt': penaltyPrompt,
      'grammar': grammar,
      'ignore_eos': ignoreEos,
      'logit_bias': logitBias.map((b) => [b.$1, b.$2]).toList(),
      'cache_prompt': true
    };
  }
}

class LlamaCppResponse {
  const LlamaCppResponse({
    required this.content,
    required this.stoppingWord,
    required this.tokensEvaluated
  });

  final String content;
  final String stoppingWord;
  final int tokensEvaluated;

  static LlamaCppResponse fromApiResponseMap(Map<String, dynamic> data) {
    return LlamaCppResponse(
      content: data['content'] as String,
      stoppingWord: data['stopping_word'] as String,
      tokensEvaluated: data['tokens_evaluated'] as int
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

    var infoRequest = {'n_predict': 0};
    var infoResponse = await runRaw('$endpoint/completion', infoRequest);
    var contextSize = infoResponse['generation_settings']['n_ctx'] as int;

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

    List<int> allInputTokens;
    int maxRepeatLastN;
    if(params.inputText.isEmpty) {
      allInputTokens = [];
      maxRepeatLastN = 0;
    } else {
      allInputTokens = await tokenize(endpoint, params.inputText);
      var allowedPromptTokensCount = contextSize - preambleTokensCount - params.cfgModel.generatedTokensCount - 1;
      if(allowedPromptTokensCount <= 0)
        throw Exception('No tokens left for prompt.');
      allowedPromptTokensCount = min(allowedPromptTokensCount, allInputTokens.length);
      maxRepeatLastN = allowedPromptTokensCount;
    }

    if(params.cfgModel.repetitionPenaltyIncludePreamble)
      maxRepeatLastN += preambleTokensCount;

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

    var mirostat = switch(params.cfgModel.mirostat) {
      Mirostat.v1 => 1,
      Mirostat.v2 => 2,
      _ => 0
    };

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
      mirostat: mirostat,
      mirostatTau: params.cfgModel.mirostatTau,
      mirostatEta: params.cfgModel.mirostatEta,
      repeatPenalty: params.cfgModel.repetitionPenalty != 0 ? params.cfgModel.repetitionPenalty : 1,
      repeatLastN: min(params.cfgModel.repetitionPenaltyRange, maxRepeatLastN),
      penaltyPrompt: params.repPenText,
      grammar: grammar,
      ignoreEos: grammar == null,
      logitBias: logitBias
    );

    var requestMap = request.toApiRequestMap();
    params.apiModel.setRawRequest(requestMap);
    params.apiModel.setRawResponse(null);
    var responseMap = await runRaw('$endpoint/completion', requestMap);
    params.apiModel.setRawResponse(responseMap);
    var response = LlamaCppResponse.fromApiResponseMap(responseMap);

    var usedPromptTokensCount = response.tokensEvaluated - preambleTokensCount;
    var usedTokens = allInputTokens.sublist(max(0, allInputTokens.length - usedPromptTokensCount));
    var usedPrompt = await detokenize(endpoint, usedTokens);
    if(usedPrompt.startsWith(' '))
      usedPrompt = usedPrompt.substring(1);

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
