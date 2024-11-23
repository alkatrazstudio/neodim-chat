// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../apis/request.dart';
import '../apis/response.dart';
import '../models/api_model.dart';
import '../models/config.dart';
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
    required this.typicalP,
    required this.mirostat,
    required this.mirostatTau,
    required this.mirostatEta,
    required this.xtcProbability,
    required this.xtcThreshold,
    required this.dryMultiplier,
    required this.dryBase,
    required this.dryAllowedLength,
    required this.dryRange,
    required this.drySequenceBreakers,
    required this.repeatPenalty,
    required this.frequencyPenalty,
    required this.presencePenalty,
    required this.repeatLastN,
    required this.grammar,
    required this.ignoreEos,
    required this.samplers,
    required this.logitBias,
    required this.seed,
    required this.stream
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
  final double typicalP;
  final int mirostat;
  final double mirostatTau;
  final double mirostatEta;
  final double xtcProbability;
  final double xtcThreshold;
  final double dryMultiplier;
  final double dryBase;
  final int dryAllowedLength;
  final int dryRange;
  final List<String> drySequenceBreakers;
  final double repeatPenalty;
  final double frequencyPenalty;
  final double presencePenalty;
  final int repeatLastN;
  final String? grammar;
  final bool ignoreEos;
  final List<(String, dynamic)> logitBias;
  final List<Warper> samplers;
  final int seed;
  final bool stream;

  static Map<Warper, String> get warpersMap => {
    Warper.dry: 'dry',
    Warper.topK: 'top_k',
    Warper.typical: 'typ_p',
    Warper.topP: 'top_p',
    Warper.minP: 'min_p',
    Warper.xtc: 'xtc',
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
      'typical_p': typicalP,
      'mirostat': mirostat,
      'mirostat_tau': mirostatTau,
      'mirostat_eta': mirostatEta,
      'xtc_probability': xtcProbability,
      'xtc_threshold': xtcThreshold,
      'dry_multiplier': dryMultiplier,
      'dry_base': dryBase,
      'dry_allowed_length': dryAllowedLength,
      'dry_penalty_last_n': dryRange,
      'dry_sequence_breakers': drySequenceBreakers,
      'repeat_penalty': repeatPenalty,
      'frequency_penalty': frequencyPenalty,
      'presence_penalty': presencePenalty,
      'repeat_last_n': repeatLastN,
      'grammar': grammar,
      'ignore_eos': ignoreEos,
      'logit_bias': logitBias.map((b) => [b.$1, b.$2]).toList(),
      'samplers': warpersToJson(samplers),
      'seed': seed,
      'stream': stream,
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
  static Random rnd = Random();

  static raiseErrorIfNeeded(Map<String, dynamic> response) {
    if(!response.containsKey('error'))
      return;
    var error = response['error'] as Map<String, dynamic>;
    var code = (error['code'] as int?) ?? 0;
    var msg = (error['message'] as String?) ?? '';
    var type = (error['type'] as String?) ?? '';
    var fullErr = '[$code - $type]: $msg';
    throw Exception(fullErr);
  }

  static Future<Map<String, dynamic>> httpPostRaw(String endpoint, Map<String, dynamic> data, CancelToken cancelToken) async {
    var dio = Dio();
    var response = await dio.post<Map<String, dynamic>>(endpoint,
      options: Options(
        headers: {
          'Content-Type': 'application/json'
        },
        responseType: ResponseType.json
      ),
      data: data,
      cancelToken: cancelToken
    );
    var resp = response.data;
    if(resp == null)
      throw Exception('Null response.');
    raiseErrorIfNeeded(resp);
    return resp;
  }

  static Future<Map<String, dynamic>> httpPostRawStream(
    String endpoint,
    Map<String, dynamic> data,
    void Function(String newText)? onNewStreamText,
    CancelToken cancelToken
  ) async {
    var dio = Dio();
    var response = await dio.post<ResponseBody>(endpoint,
      options: Options(
        headers: {
          'Content-Type': 'application/json'
        },
        responseType: ResponseType.stream
      ),
      data: data,
      cancelToken: cancelToken
    );
    var stream = response.data?.stream;
    if(stream == null)
      throw Exception('No response stream.');
    var msgBuf = <int>[];
    Map<String, dynamic>? lastMsgObj;
    var allContent = '';
    var nl = '\n'.codeUnits.first;
    var prefixes = ['data: ', 'error: '];
    await for (var bytes in stream) {
      msgBuf.addAll(bytes);
      while(true) {
        var nlPos = msgBuf.indexOf(nl);
        if(nlPos == -1)
          break;
        var msgBytes = msgBuf.sublist(0, nlPos);
        msgBuf = msgBuf.sublist(nlPos + 1);
        var msg = utf8.decode(msgBytes);
        if(msg.isEmpty)
          continue;
        String? usedPrefix;
        for(var prefix in prefixes) {
          if(msg.startsWith(prefix)) {
            usedPrefix = prefix;
            break;
          }
        }
        if(usedPrefix == null)
          throw Exception('Invalid stream part prefix.');
        var lastMsgJson = msg.substring(usedPrefix.length);
        lastMsgObj = jsonDecode(lastMsgJson) as Map<String, dynamic>;
        raiseErrorIfNeeded(lastMsgObj);
        var content = lastMsgObj['content'] as String;
        if(content.isEmpty)
          continue;
        allContent += content;
        if(onNewStreamText != null)
          onNewStreamText(content);
      }
    }
    if(lastMsgObj == null)
      throw Exception('No final response from the stream');
    lastMsgObj['content'] = allContent;
    return lastMsgObj;
  }

  static Future<Map<String, dynamic>> httpGetRaw(String endpoint, CancelToken cancelToken) async {
    var dio = Dio();
    var response = await dio.get<Map<String, dynamic>>(endpoint,
      options: Options(
        responseType: ResponseType.json
      ),
      cancelToken: cancelToken
    );
    var resp = response.data;
    if(resp == null)
      throw Exception('Null response.');
    raiseErrorIfNeeded(resp);
    return resp;
  }

  static Future<List<int>> tokenize(String endpoint, String content, ApiCancelModel apiCancelModel) async {
    var response = await runWithCancelToken(apiCancelModel, (cancelToken) => httpPostRaw('$endpoint/tokenize', {'content': content}, cancelToken));
    var tokens = (response['tokens'] as List<dynamic>).map((token) => token as int).toList();
    return tokens;
  }

  static Future<String> detokenize(String endpoint, List<int> tokens, ApiCancelModel apiCancelModel) async {
    var response = await runWithCancelToken(apiCancelModel, (cancelToken) => httpPostRaw('$endpoint/detokenize', {'tokens': tokens}, cancelToken));
    var content = response['content'] as String;
    return content;
  }

  static Future<T> runWithCancelToken<T>(ApiCancelModel apiCancelModel, Future<T> Function(CancelToken) f) async {
    try {
      var cancelToken = CancelToken();
      apiCancelModel.setCancelFunc(() => cancelToken.cancel());
      var result = await f(cancelToken);
      return result;
    } on DioException catch(e) {
      if(e.type == DioExceptionType.cancel)
        throw ApiCancelException();
      rethrow;
    } finally {
      apiCancelModel.setCancelFunc(null);
    }
  }

  static Future<ApiResponse?> run(ApiRequestParams params) async {
    var endpoint = ApiRequest.normalizeEndpoint(params.cfgModel.apiEndpoint, 8080, '');

    var infoResponse = await runWithCancelToken(params.apiCancelModel, (cancelToken) => httpGetRaw('$endpoint/props', cancelToken));
    raiseErrorIfNeeded(infoResponse);
    var contextSize = infoResponse['default_generation_settings']['n_ctx'] as int;

    int preambleTokensCount;

    // llama.cpp truncates the input prompt automatically depending on n_predict and n_keep params
    // and then caches all inference results needed to predict the next token.
    // Manually truncating the prompt will result in a cache miss.
    // That's why we need to pass all the preamble and prompt unmodified.
    var allInput = params.inputText;
    var preamble = params.cfgModel.inputPreamble;
    if(preamble.isNotEmpty) {
      preambleTokensCount = (await tokenize(endpoint, preamble, params.apiCancelModel)).length;
      allInput = preamble + allInput;
    } else {
      preambleTokensCount = 0;
    }

    var allInputTokens = params.inputText.isEmpty ? <int>[] : await tokenize(endpoint, params.inputText, params.apiCancelModel);
    int maxRepeatLastN;
    int repeatLastN;
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

    var blacklistLines = params.cfgModel.initialBlacklist.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    for(var word in params.blacklistWordsForRetry ?? <String>[])
    blacklistLines.add(word);
    var linesForBias = <String>[];
    for(var f1 in [
      (String s) => s,
      (String s) => s.replaceFirstMapped(RegExp(r'^\p{Letter}', unicode: true), (m) => ' ${m[0]}')]
    ) {
      for(var f2 in [
        (String s) => s,
        (String s) => s.toLowerCase(),
        (String s) => s.toUpperCase(),
        (String s) => s.toLowerCase().replaceAllMapped(RegExp(r'(^|[^\p{Letter}])(\p{Letter})', unicode: true), (m) => '${m[1]}${m[2]!.toUpperCase()}')
      ]) {
        for(var blacklistLine in blacklistLines) {
          var f1res = f1(blacklistLine);
          var f2res = f2(f1res);
          linesForBias.add(f2res);
        }
      }
    }
    var logitBias = linesForBias.toSet().map((line) => (line, false)).toList();

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

    var seed = 0x100000000 * rnd.nextInt(0x7FFFFFFF) + rnd.nextInt(0x100000000);

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
      typicalP: params.cfgModel.typical != 0 ? params.cfgModel.typical : 1,
      mirostat: mirostat,
      mirostatTau: params.cfgModel.mirostatTau,
      mirostatEta: params.cfgModel.mirostatEta,
      xtcProbability: params.cfgModel.xtcProbability,
      xtcThreshold: params.cfgModel.xtcThreshold,
      dryMultiplier: params.cfgModel.dryMultiplier,
      dryBase: params.cfgModel.dryBase,
      dryAllowedLength: params.cfgModel.dryAllowedLength,
      dryRange: params.cfgModel.dryRange == 0 ? -1 : params.cfgModel.dryRange,
      drySequenceBreakers: ['\n', ':', '"', '*', '>'],
      repeatPenalty: params.cfgModel.repetitionPenalty != 0 ? params.cfgModel.repetitionPenalty : 1,
      frequencyPenalty: params.cfgModel.frequencyPenalty,
      presencePenalty: params.cfgModel.presencePenalty,
      repeatLastN: repeatLastN,
      grammar: grammar,
      ignoreEos: grammar == null,
      logitBias: logitBias,
      samplers: params.cfgModel.warpersOrder,
      seed: seed,
      stream: params.cfgModel.streamResponse
    );

    var requestMap = request.toApiRequestMap();
    params.apiModel.startRawRequest(requestMap);
    var responseMap = await runWithCancelToken(
      params.apiCancelModel,
      (cancelToken) => request.stream
        ? httpPostRawStream('$endpoint/completion', requestMap, params.onNewStreamText, cancelToken)
        : httpPostRaw('$endpoint/completion', requestMap, cancelToken)
    );
    var response = LlamaCppResponse.fromApiResponseMap(responseMap);
    params.apiModel.endRawRequest(responseMap, response.tokensPredicted);

    var usedPromptTokensCount = response.tokensEvaluated - preambleTokensCount;
    var usedTokens = allInputTokens.sublist(max(0, allInputTokens.length - usedPromptTokensCount));
    var usedPrompt = await detokenize(endpoint, usedTokens, params.apiCancelModel);
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
