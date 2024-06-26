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
    required this.dynaTempRange,
    required this.dynaTempExponent,
    required this.topK,
    required this.topP,
    required this.minP,
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
    required this.frequencyPenalty,
    required this.presencePenalty,
    required this.repeatLastN,
    required this.penaltyPrompt,
    required this.grammar,
    required this.ignoreEos,
    required this.samplers,
    required this.logitBias
  });

  final double temperature;
  final double dynaTempRange;
  final double dynaTempExponent;
  final int topK;
  final double topP;
  final double minP;
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
  final double frequencyPenalty;
  final double presencePenalty;
  final String? penaltyPrompt;
  final int repeatLastN;
  final String? grammar;
  final bool ignoreEos;
  final List<(String, dynamic)> logitBias;
  final List<Warper> samplers;

  static Map<Warper, String> get warpersMap => {
    Warper.topK: 'top_k',
    Warper.tfs: 'tfs_z',
    Warper.typical: 'typical_p',
    Warper.topP: 'top_p',
    Warper.minP: 'min_p',
    Warper.temperature: 'temperature'
  };
  static List<Warper> get supportedWarpers => ApiRequest.supportedWarpers(warpersMap);
  static List<String> warpersToJson(List<Warper> warpers) => ApiRequest.warpersToJson(warpersMap, warpers)!;

  Map<String, dynamic> toApiRequestMap() {
    return <String, dynamic> {
      'temperature': temperature,
      'dynatemp_range': dynaTempRange,
      'dynatemp_exponent': dynaTempExponent,
      'top_k': topK,
      'top_p': topP,
      'min_p': minP,
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
      'frequency_penalty': frequencyPenalty,
      'presence_penalty': presencePenalty,
      'repeat_last_n': repeatLastN,
      'penalty_prompt': penaltyPrompt,
      'grammar': grammar,
      'ignore_eos': ignoreEos,
      'logit_bias': logitBias.map((b) => [b.$1, b.$2]).toList(),
      'samplers': warpersToJson(samplers),
      'cache_prompt': true
    };
  }
}

class LlamaCppResponse {
  const LlamaCppResponse({
    required this.content,
    required this.stoppingWord,
    required this.tokensEvaluated,
    required this.tokensPredicted
  });

  final String content;
  final String stoppingWord;
  final int tokensEvaluated;
  final int tokensPredicted;

  static LlamaCppResponse fromApiResponseMap(Map<String, dynamic> data) {
    return LlamaCppResponse(
      content: data['content'] as String,
      stoppingWord: data['stopping_word'] as String,
      tokensEvaluated: data['tokens_evaluated'] as int,
      tokensPredicted: data['tokens_predicted'] as int
    );
  }
}

class ApiRequestLlamaCpp {
  static Future<Map<String, dynamic>> httpPostRaw(String endpoint, Map<String, dynamic> data) async {
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
    if(resp.containsKey('error')) {
      var error = resp['error'] as Map<String, dynamic>;
      var code = (error['code'] as int?) ?? 0;
      var msg = (error['message'] as String?) ?? '';
      var type = (error['type'] as String?) ?? '';
      var fullErr = '[$code - $type]: $msg';
      throw Exception(fullErr);
    }
    return resp;
  }

  static Future<Map<String, dynamic>> httpGetRaw(String endpoint) async {
    var endpointUri = Uri.parse(endpoint);
    var response = await http.get(endpointUri);
    var respJson = response.body;
    var resp = jsonDecode(respJson) as Map<String, dynamic>;
    return resp;
  }

  static Future<List<int>> tokenize(String endpoint, String content) async {
    var response = await httpPostRaw('$endpoint/tokenize', {'content': content});
    var tokens = (response['tokens'] as List<dynamic>).map((token) => token as int).toList();
    return tokens;
  }

  static Future<String> detokenize(String endpoint, List<int> tokens) async {
    var response = await httpPostRaw('$endpoint/detokenize', {'tokens': tokens});
    var content = response['content'] as String;
    return content;
  }

  static Future<ApiResponse?> run(ApiRequestParams params) async {
    var endpoint = ApiRequest.normalizeEndpoint(params.cfgModel.apiEndpoint, 8080, '');

    var infoResponse = await httpGetRaw('$endpoint/props');
    var contextSize = infoResponse['default_generation_settings']['n_ctx'] as int;

    int preambleTokensCount;

    // llama.cpp truncates the input prompt automatically depending on n_predict and n_keep params
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

    var allInputTokens = params.inputText.isEmpty ? <int>[] : await tokenize(endpoint, params.inputText);
    int maxRepeatLastN;
    var repPenText = params.repPenText;
    int repeatLastN;
    if(repPenText == null) {
      if(params.inputText.isEmpty) {
        maxRepeatLastN = 0;
      } else {
        var allowedPromptTokensCount = contextSize - preambleTokensCount - params.cfgModel.generatedTokensCount - 1;
        if(allowedPromptTokensCount <= 0)
          throw Exception('No tokens left for prompt.');
        allowedPromptTokensCount = min(allowedPromptTokensCount, allInputTokens.length);
        maxRepeatLastN = allowedPromptTokensCount;
      }
      if(params.cfgModel.repetitionPenaltyIncludePreamble)
        maxRepeatLastN += preambleTokensCount;
      repeatLastN = params.cfgModel.repetitionPenaltyRange == 0 ? maxRepeatLastN : params.cfgModel.repetitionPenaltyRange;
      repeatLastN = min(repeatLastN, maxRepeatLastN);
      if(repeatLastN == 0)
        repPenText = '';
    } else {
      if(params.cfgModel.repetitionPenaltyIncludePreamble)
        repPenText = params.cfgModel.inputPreamble + repPenText;
      var repPenTokens = await tokenize(endpoint, repPenText);
      maxRepeatLastN = repPenTokens.length;
      repeatLastN = params.cfgModel.repetitionPenaltyRange == 0 ? maxRepeatLastN : params.cfgModel.repetitionPenaltyRange;
      repeatLastN = min(repeatLastN, maxRepeatLastN);
      if(repeatLastN == 0) {
        repPenText = '';
      } else {
        if(repeatLastN < repPenTokens.length) {
          repPenTokens = repPenTokens.sublist(repPenTokens.length - repeatLastN);
          repPenText = await detokenize(endpoint, repPenTokens);
        }
      }
    }

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

    var logitBias = <(String, dynamic)>[];
    if(params.blacklistWordsForRetry != null) {
      for(var word in params.blacklistWordsForRetry!) {
        logitBias.add((word, false));
      }
    }

    var mirostat = switch(params.cfgModel.mirostat) {
      MirostatVersion.v1 => 1,
      MirostatVersion.v2 => 2,
      _ => 0
    };

    double temperature;
    double dynaTempRange;
    switch(params.cfgModel.temperatureMode) {
      case TemperatureMode.dynamic:
        // llama.cpp DynaTemp range is actually only half the range
        // https://github.com/ggerganov/llama.cpp/blob/cd9aea63b577a83def84dbd6dcd90a6fa02af745/common/sampling.cpp#L151-L152
        dynaTempRange = max(0, params.cfgModel.dynaTempHigh - params.cfgModel.temperature) / 2;
        temperature = params.cfgModel.temperature + dynaTempRange; // the middle temperature
        break;

      default:
        temperature = params.cfgModel.temperature;
        dynaTempRange = 0;
    }

    var request = LlamaCppRequest(
      temperature: temperature != 0 ? temperature : 1,
      dynaTempRange: dynaTempRange,
      dynaTempExponent: params.cfgModel.dynaTempExponent,
      topK: params.cfgModel.topK,
      topP: params.cfgModel.topP != 0 ? params.cfgModel.topP : 1,
      minP: params.cfgModel.minP,
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
      frequencyPenalty: params.cfgModel.frequencyPenalty,
      presencePenalty: params.cfgModel.presencePenalty,
      repeatLastN: repeatLastN,
      penaltyPrompt: repPenText,
      grammar: grammar,
      ignoreEos: grammar == null,
      logitBias: logitBias,
      samplers: params.cfgModel.warpersOrder
    );

    var requestMap = request.toApiRequestMap();
    params.apiModel.startRawRequest(requestMap);
    var responseMap = await httpPostRaw('$endpoint/completion', requestMap);
    var response = LlamaCppResponse.fromApiResponseMap(responseMap);
    params.apiModel.endRawRequest(responseMap, response.tokensPredicted);

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
