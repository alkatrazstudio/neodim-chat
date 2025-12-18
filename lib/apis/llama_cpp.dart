// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../apis/request.dart';
import '../apis/response.dart';
import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
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
    required this.topNSigma,
    required this.repeatPenalty,
    required this.frequencyPenalty,
    required this.presencePenalty,
    required this.repeatLastN,
    required this.grammar,
    required this.ignoreEos,
    required this.samplers,
    required this.logitBias,
    required this.seed,
    required this.stream,
    required this.slotId
  });

  final double temperature;
  final double dynaTempRange;
  final double dynaTempExponent;
  final int topK;
  final double topP;
  final double minP;
  final int nPredict;
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
  final double topNSigma;
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
  final int slotId;

  static Map<Warper, String> get warpersMap => {
    Warper.dry: 'dry',
    Warper.topK: 'top_k',
    Warper.typical: 'typ_p',
    Warper.topP: 'top_p',
    Warper.minP: 'min_p',
    Warper.xtc: 'xtc',
    Warper.temperature: 'temperature',
    Warper.topNSigma: 'top_n_sigma',
    Warper.repetitionPenalty: 'penalties'
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
      'top_n_sigma': topNSigma,
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
      'cache_prompt': true,
      'id_slot': slotId
    };
  }
}

class LlamaCppResponse {
  const LlamaCppResponse({
    required this.content,
    required this.stoppingWord,
    required this.tokensEvaluated,
    required this.tokensPredicted,
    required this.slotId,
    required this.promptProcessingMilliSecs,
    required this.predictionMilliSecs
  });

  final String content;
  final String stoppingWord;
  final int tokensEvaluated;
  final int tokensPredicted;
  final int slotId;
  final num promptProcessingMilliSecs;
  final num predictionMilliSecs;

  static LlamaCppResponse fromApiResponseMap(Map<String, dynamic> data) {
    var timings = data['timings'] as Map<String, dynamic>?;
    return LlamaCppResponse(
      content: data['content'] as String,
      stoppingWord: (data['stopping_word'] as String?) ?? '',
      tokensEvaluated: data['tokens_evaluated'] as int,
      tokensPredicted: data['tokens_predicted'] as int,
      slotId: data['id_slot'] as int,
      promptProcessingMilliSecs: timings?['prompt_ms'] as num? ?? 0,
      predictionMilliSecs: timings?['predicted_ms'] as num? ?? 0
    );
  }

  int get usedContextLength => tokensEvaluated + tokensPredicted;
}

class ApiRequestLlamaCpp {
  static Random rnd = Random();

  static var attemptedCacheRestoreForConvIds = <String>{};
  static var processingMilliSecsWithoutCacheSave = <String, int>{};
  static var isSavingCache = <String, bool>{};
  static var lastServerTokenCount = 0;

  static void raiseErrorIfNeeded(dynamic response) {
    if(response is! Map<String, dynamic>)
      return;
    Map<String, dynamic> error;
    if(response.containsKey('error'))
      error = response['error'] as Map<String, dynamic>;
    else if(response.containsKey('message') && !response.containsKey('content'))
      error = response;
    else
      return;
    var code = (error['code'] as int?) ?? 0;
    var msg = (error['message'] as String?) ?? '';
    var type = (error['type'] as String?) ?? '';
    var fullErr = '[$code - $type]: $msg';
    throw Exception(fullErr);
  }

  static Future<Map<String, dynamic>> httpPostRaw(String endpoint, Map<String, dynamic> data, CancelToken? cancelToken, {Map<String, dynamic>? queryParams}) async {
    var dio = Dio();
    var response = await dio.post<Map<String, dynamic>>(endpoint,
      queryParameters: queryParams,
      options: Options(
        validateStatus: (_) => true,
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
    CancelToken? cancelToken,
    int maxContextLength,
    ApiModel apiModel
  ) async {
    var dio = Dio();
    var response = await dio.post<ResponseBody>(endpoint,
      options: Options(
        validateStatus: (_) => true,
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
    var gotResponse = false;
    await for (var bytes in stream) {
      msgBuf.addAll(bytes);
      while(true) {
        var nlPos = msgBuf.indexOf(nl);
        if(nlPos == -1) {
          if(!gotResponse) {
            // sometimes the error breaks the streaming conventions
            // and it will be output as just a regular JSON
            Map<String, dynamic>? err;
            try {
              var errMsg = utf8.decode(msgBuf);
              err = jsonDecode(errMsg) as Map<String, dynamic>;
            } catch(_) {
            }
            if(err != null)
              raiseErrorIfNeeded(err);
          }
          break;
        }
        gotResponse = true;
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
        if(usedPrefix == null) {
          if(msg.startsWith('{'))
            usedPrefix = '';
          else
            throw Exception('Invalid stream part prefix.');
        }
        var lastMsgJson = msg.substring(usedPrefix.length);
        lastMsgObj = jsonDecode(lastMsgJson) as Map<String, dynamic>;
        raiseErrorIfNeeded(lastMsgObj);
        try {
          var response = LlamaCppResponse.fromApiResponseMap(lastMsgObj);
          var content = response.content;
          if(content.isEmpty)
            continue;
          allContent += content;
          if(onNewStreamText != null)
            onNewStreamText(content);
          apiModel.setContextStats(maxContextLength, response.usedContextLength);
        } catch(_) {
        }
      }
    }
    if(lastMsgObj == null)
      throw Exception('No final response from the stream');
    lastMsgObj['content'] = allContent;
    return lastMsgObj;
  }

  static Future<T> httpGetRaw<T>(String endpoint, CancelToken? cancelToken) async {
    var dio = Dio();
    var response = await dio.get<T>(endpoint,
      options: Options(
        validateStatus: (_) => true,
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

  static Future<List<int>> tokenize(String endpoint, String content, ApiCancelModel? apiCancelModel) async {
    var response = await runWithCancelToken(apiCancelModel, (cancelToken) => httpPostRaw('$endpoint/tokenize', {'content': content}, cancelToken));
    var tokens = (response['tokens'] as List<dynamic>).map((token) => token as int).toList();
    return tokens;
  }

  static Future<String> detokenize(String endpoint, List<int> tokens, ApiCancelModel apiCancelModel) async {
    var response = await runWithCancelToken(apiCancelModel, (cancelToken) => httpPostRaw('$endpoint/detokenize', {'tokens': tokens}, cancelToken));
    var content = response['content'] as String;
    return content;
  }

  static String getCacheFilename(Conversation conv) {
    var filename = '${conv.id}.neodim.cache';
    return filename;
  }

  static Future<void> updateTotalServerTokens(String endpoint, ApiCancelModel apiCancelModel) async {
    var serverTokensCount = await getTotalServerTokens(endpoint, apiCancelModel);
    if(serverTokensCount >= 0) {
      if(serverTokensCount < lastServerTokenCount)
        attemptedCacheRestoreForConvIds.clear(); // this is the only way for now to test that the server was restarted
      lastServerTokenCount = serverTokensCount;
    }
  }

  static Future<int> restoreCacheIntoAvailableSlotIfNeeded(String endpoint, Conversation conv, ApiCancelModel apiCancelModel) async {
    if(attemptedCacheRestoreForConvIds.contains(conv.id))
      return -1;
    attemptedCacheRestoreForConvIds.add(conv.id);
    try {
      var slots = await runWithCancelToken<List<dynamic>>(apiCancelModel, (cancelToken) => httpGetRaw('$endpoint/slots', cancelToken));
      var candidateIds = <int>[];
      int? finalCandidateId;
      for(var slotItem in slots) {
        var slot = slotItem as Map<String, dynamic>;
        if(slot['is_processing'] == false) {
          var slotId = slot['id'] as int;
          if(!slotItem.containsKey('params')) {
            finalCandidateId = slotId;
            break;
          }
          candidateIds.add(slotId);
        }
      }
      finalCandidateId ??= candidateIds.firstOrNull;
      if(finalCandidateId == null)
        return -1;
      var filename = getCacheFilename(conv);
      await runWithCancelToken(apiCancelModel, (cancelToken) => httpPostRaw(
        '$endpoint/slots/$finalCandidateId',
        {'filename': filename},
        cancelToken,
        queryParams: {'action': 'restore'}
      ));
      return finalCandidateId;
    } catch(e) {
      if(e is DioException && e.type == DioExceptionType.cancel)
        rethrow;
      return -1;
    }
  }

  static Future<void> saveCacheIfNeeded(String endpoint, ApiRequestParams params, LlamaCppResponse response, bool forceSave) async {
    if(!forceSave) {
      if(params.cfgModel.saveCacheAfterProcessingSecs <= 0)
        return;
      var processingMilliSecs = processingMilliSecsWithoutCacheSave[params.conversation.id] ?? 0;
      processingMilliSecs += response.promptProcessingMilliSecs.round() + response.predictionMilliSecs.round();
      var maxProcessingMilliSecs = params.cfgModel.saveCacheAfterProcessingSecs * 1000;
      processingMilliSecsWithoutCacheSave[params.conversation.id] = processingMilliSecs;
      if(processingMilliSecs <= maxProcessingMilliSecs)
        return;
      if(isSavingCache[params.conversation.id] ?? false)
        return;
    }

    var filename = getCacheFilename(params.conversation);
    Future<Map<String, dynamic>> f(cancelToken) => httpPostRaw(
      '$endpoint/slots/${response.slotId}',
      {'filename': filename},
      cancelToken,
      queryParams: {'action': 'save'}
    );

    isSavingCache[params.conversation.id] = true;
    try {
      await runWithCancelToken(forceSave ? params.apiCancelModel : null, f);
      processingMilliSecsWithoutCacheSave[params.conversation.id] = 0;
    } catch(e) {
      if(forceSave || (e is DioException && e.type == DioExceptionType.cancel))
        rethrow;
    } finally {
      isSavingCache[params.conversation.id] = false;
    }
  }

  static Future<int> getTotalServerTokens(String endpoint, ApiCancelModel apiCancelModel) async {
    try {
      var lines = await runWithCancelToken(apiCancelModel, (cancelToken) async {
        var response = await Dio().get('$endpoint/metrics', cancelToken: cancelToken);
        var text = response.toString();
        return text;
      });
      var rx = RegExp(r'^llamacpp:prompt_tokens_total (\d+)', multiLine: true);
      var m = rx.firstMatch(lines);
      if(m == null)
        return -1;
      var tokensCounts = int.parse(m.group(1)!);
      return tokensCounts;
    } catch(e) {
      return -1;
    }
  }

  static Future<T> runWithCancelToken<T>(ApiCancelModel? apiCancelModel, Future<T> Function(CancelToken?) f) async {
    if(apiCancelModel == null)
      return await f(null);
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

  static String getEndpoint(ConfigModel cfgModel) {
    var endpoint = ApiRequest.normalizeEndpoint(cfgModel.apiEndpoint, 8080, '');
    return endpoint;
  }

  static Future<int> getMaxContextLength(String endpoint, ApiCancelModel? apiCancelModel) async {
    var infoResponse = await runWithCancelToken(apiCancelModel, (cancelToken) => httpGetRaw('$endpoint/props', cancelToken));
    var contextLength = infoResponse['default_generation_settings']['n_ctx'] as int;
    return contextLength;
  }

  static Future<ApiResponse?> run(ApiRequestParams params) async {
    var endpoint = getEndpoint(params.cfgModel);
    var contextLength = await getMaxContextLength(endpoint, params.apiCancelModel);

    int preambleTokensCount;

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
      var allowedPromptTokensCount = contextLength - preambleTokensCount - params.cfgModel.generatedTokensCount - 1;
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
      (String s) => ' $s'
    ]) {
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
        // https://github.com/ggml-org/llama.cpp/blob/cd9aea63b577a83def84dbd6dcd90a6fa02af745/common/sampling.cpp#L151-L152
        dynaTempRange = max(0, params.cfgModel.dynaTempHigh - params.cfgModel.temperature) / 2;
        temperature = params.cfgModel.temperature + dynaTempRange; // the middle temperature
        break;

      default:
        temperature = params.cfgModel.temperature;
        dynaTempRange = 0;
    }

    var seed = 0x100000000 * rnd.nextInt(0x7FFFFFFF) + rnd.nextInt(0x100000000);

    await updateTotalServerTokens(endpoint, params.apiCancelModel);
    var slotId = await restoreCacheIntoAvailableSlotIfNeeded(endpoint, params.conversation, params.apiCancelModel);

    var request = LlamaCppRequest(
      temperature: temperature,
      dynaTempRange: dynaTempRange,
      dynaTempExponent: params.cfgModel.dynaTempExponent,
      topK: params.cfgModel.topK,
      topP: params.cfgModel.topP != 0 ? params.cfgModel.topP : 1,
      minP: params.cfgModel.minP,
      nPredict: params.onlySaveCache ? 0 : params.cfgModel.generatedTokensCount,
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
      topNSigma: params.cfgModel.topNSigma,
      repeatPenalty: params.cfgModel.repetitionPenalty != 0 ? params.cfgModel.repetitionPenalty : 1,
      frequencyPenalty: params.cfgModel.frequencyPenalty,
      presencePenalty: params.cfgModel.presencePenalty,
      repeatLastN: repeatLastN,
      grammar: grammar,
      ignoreEos: grammar == null,
      logitBias: logitBias,
      samplers: params.cfgModel.warpersOrder,
      seed: seed,
      stream: params.cfgModel.streamResponse,
      slotId: slotId
    );

    var requestMap = request.toApiRequestMap();
    params.apiModel.startRawRequest(requestMap);
    var responseMap = await runWithCancelToken(
      params.apiCancelModel,
      (cancelToken) => request.stream
        ? httpPostRawStream('$endpoint/completion', requestMap, params.onNewStreamText, cancelToken, contextLength, params.apiModel)
        : httpPostRaw('$endpoint/completion', requestMap, cancelToken)
    );
    var response = LlamaCppResponse.fromApiResponseMap(responseMap);
    params.apiModel.endRawRequest(responseMap, response.tokensPredicted);
    params.apiModel.setContextStats(contextLength, response.usedContextLength);

    var saveCacheFuture = saveCacheIfNeeded(endpoint, params, response, params.onlySaveCache);
    if(params.onlySaveCache)
      await saveCacheFuture;

    var result = ApiResponse(
      sequences: [ApiResponseSequence(
        generatedText: params.onlySaveCache ? '' : response.content,
        stopStringMatch: params.onlySaveCache ? '' : response.stoppingWord,
        stopStringMatchIsSentenceEnd: false
      )]
    );
    return result;
  }

  static Future<void> updateStats(String inputText, ConfigModel cfgModel, ApiModel apiModel) async {
    var endpoint = getEndpoint(cfgModel);
    var maxLength = await getMaxContextLength(endpoint, null);
    var currentLength = (await tokenize(endpoint, inputText, null)).length;
    apiModel.setContextStats(maxLength, currentLength);
  }
}
