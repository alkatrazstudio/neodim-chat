// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:change_case/change_case.dart';
import 'package:json_annotation/json_annotation.dart';

import '../apis/request.dart';
import '../util/enums.dart';

part 'config.g.dart';

enum CombineChatLinesType {
  no,
  onlyForServer,
  previousLines
}

enum MirostatVersion {
  none,
  v1,
  v2
}

enum ParticipantOnRetry {
  any,
  same,
  different
}

enum TemperatureMode {
  static,
  dynamic
}

enum Warper {
  repetitionPenalty,
  topK,
  tfs,
  typical,
  topP,
  minP,
  topA,
  temperature
}

List<Warper> warpersListFromJson(dynamic json) {
  var warpers = <Warper>[];
  if(json is List) {
    for(var item in json) {
      if(item is String) {
        item = item.toCamelCase();
        var warper = Warper.values.byNameOrNull(item);
        if(warper != null)
          warpers.add(warper);
      }
    }
  }
  ConfigModel.normalizeWarpers(warpers);
  return warpers;
}

@JsonSerializable(explicitToJson: true)
class ConfigModel extends ChangeNotifier {
  @JsonKey(defaultValue: ApiType.neodim, unknownEnumValue: ApiType.neodim)
  ApiType apiType = ApiType.neodim;

  @JsonKey(defaultValue: '0.0.0.0')
  String apiEndpoint = '0.0.0.0';

  @JsonKey(defaultValue: 64)
  int generatedTokensCount = 64;

  @JsonKey(defaultValue: 2048)
  int maxTotalTokens = 2048;

  @JsonKey(defaultValue: TemperatureMode.static, unknownEnumValue: TemperatureMode.static)
  TemperatureMode temperatureMode = TemperatureMode.static;

  @JsonKey(defaultValue: 0.7)
  double temperature = 0.7; // also acts as dynaTempLow

  @JsonKey(defaultValue: 0.7)
  double dynaTempHigh = 0.7;

  @JsonKey(defaultValue: 1.0)
  double dynaTempExponent = 1.0;

  @JsonKey(defaultValue: 0)
  double topP = 0;

  @JsonKey(defaultValue: 0)
  int topK = 0;

  @JsonKey(defaultValue: 0)
  double minP = 0;

  @JsonKey(defaultValue: 0.9)
  double tfs = 0.9;

  @JsonKey(defaultValue: 0)
  double typical = 0;

  @JsonKey(defaultValue: 0)
  double topA = 0;

  @JsonKey(defaultValue: 0)
  double penaltyAlpha = 0;

  @JsonKey(defaultValue: MirostatVersion.none, unknownEnumValue: MirostatVersion.none)
  MirostatVersion mirostat = MirostatVersion.none;

  @JsonKey(defaultValue: 5.0)
  double mirostatTau = 5.0;

  @JsonKey(defaultValue: 0.1)
  double mirostatEta = 0.1;

  @JsonKey(fromJson: warpersListFromJson)
  List<Warper> warpersOrder = Warper.values;

  @JsonKey(defaultValue: 1.15)
  double repetitionPenalty = 1.15;

  @JsonKey(defaultValue: 0)
  double frequencyPenalty = 0;

  @JsonKey(defaultValue: 0)
  double presencePenalty = 0;

  @JsonKey(defaultValue: 0)
  int repetitionPenaltyRange = 2048;

  @JsonKey(defaultValue: 0.75)
  double repetitionPenaltySlope = 0.75;

  @JsonKey(defaultValue: false)
  bool repetitionPenaltyIncludePreamble = false;

  @JsonKey(defaultValue: RepPenGenerated.slide, unknownEnumValue: RepPenGenerated.slide)
  RepPenGenerated repetitionPenaltyIncludeGenerated = RepPenGenerated.slide;

  @JsonKey(defaultValue: false)
  bool repetitionPenaltyTruncateToInput = false;

  @JsonKey(defaultValue: '')
  String preamble = '';

  @JsonKey(defaultValue: 0)
  int extraRetries = 0;

  @JsonKey(defaultValue: 5)
  int repetitionPenaltyLinesWithNoExtraSymbols = 5;

  @JsonKey(defaultValue: true)
  bool repetitionPenaltyKeepOriginalPrompt = true;

  @JsonKey(defaultValue: true)
  bool repetitionPenaltyRemoveParticipantNames = true;

  @JsonKey(defaultValue: false)
  bool stopOnPunctuation = false;

  @JsonKey(defaultValue: true)
  bool undoBySentence = true;

  @JsonKey(defaultValue: CombineChatLinesType.no, unknownEnumValue: CombineChatLinesType.no)
  CombineChatLinesType combineChatLines = CombineChatLinesType.no;

  @JsonKey(defaultValue: true)
  bool continuousChatForceAlternateParticipants = true;

  @JsonKey(defaultValue: 10)
  int noRepeatNGramSize = 10;

  @JsonKey(defaultValue: 2)
  int addWordsToBlacklistOnRetry = 2;

  @JsonKey(defaultValue: true)
  bool addSpecialSymbolsToBlacklist = true;

  @JsonKey(defaultValue: 1)
  int removeWordsFromBlacklistOnRetry = 1;

  @JsonKey(defaultValue: true)
  bool colonStartIsPreviousName = true;

  @JsonKey(defaultValue: ParticipantOnRetry.any, unknownEnumValue: ParticipantOnRetry.any)
  ParticipantOnRetry participantOnRetry = ParticipantOnRetry.any;

  String get inputPreamble {
    var s = preamble.trim();
    if(s.isEmpty)
      return '';
    return '$preamble\n\n';
  }

  void setApiType(ApiType newApiType) {
    apiType = newApiType;
    notifyListeners();
  }

  void setApiEndpoint(String newApiEndpoint) {
    apiEndpoint = newApiEndpoint;
    notifyListeners();
  }

  void setGeneratedTokensCount(int newGeneratedTokensCount) {
    generatedTokensCount = newGeneratedTokensCount;
    notifyListeners();
  }

  void setMaxTotalTokens(int newMaxTotalTokens) {
    maxTotalTokens = newMaxTotalTokens;
    notifyListeners();
  }

  void setTemperatureMode(TemperatureMode newTemperatureMode) {
    temperatureMode = newTemperatureMode;
    notifyListeners();
  }

  void setTemperature(double newTemperature) {
    temperature = newTemperature;
    notifyListeners();
  }

  void setDynaTempHigh(double newDynaTempHigh) {
    dynaTempHigh = newDynaTempHigh;
    notifyListeners();
  }

  void setDynaTempExponent(double newDynaTempExponent) {
    dynaTempExponent = newDynaTempExponent;
    notifyListeners();
  }

  void setTopP(double newTopP) {
    topP = newTopP;
    notifyListeners();
  }

  void setTopK(int newTopK) {
    topK = newTopK;
    notifyListeners();
  }

  void setMinP(double newMinP) {
    minP = newMinP;
    notifyListeners();
  }

  void setTfs(double newTfs) {
    tfs = newTfs;
    notifyListeners();
  }

  void setTypical(double newTypical) {
    typical = newTypical;
    notifyListeners();
  }

  void setTopA(double newTopA) {
    topA = newTopA;
    notifyListeners();
  }

  void setPenaltyAlpha(double newPenaltyAlpha) {
    penaltyAlpha = newPenaltyAlpha;
    notifyListeners();
  }

  void setMirostat(MirostatVersion newMirostat) {
    mirostat = newMirostat;
    notifyListeners();
  }

  void setMirostatTau(double newMirostatTau) {
    mirostatTau = newMirostatTau;
    notifyListeners();
  }

  void setMirostatEta(double newMirostatEta) {
    mirostatEta = newMirostatEta;
    notifyListeners();
  }

  void setWarpersOrder(List<Warper> newWarpersOrder) {
    warpersOrder = newWarpersOrder;
    notifyListeners();
  }

  void setRepetitionPenalty(double newRepetitionPenalty) {
    repetitionPenalty = newRepetitionPenalty;
    notifyListeners();
  }

  void setFrequencyPenalty(double newFrequencyPenalty) {
    frequencyPenalty = newFrequencyPenalty;
    notifyListeners();
  }

  void setPresencePenalty(double newPresencePenalty) {
    presencePenalty = newPresencePenalty;
    notifyListeners();
  }

  void setRepetitionPenaltyRange(int newRepetitionPenaltyRange) {
    repetitionPenaltyRange = newRepetitionPenaltyRange;
    notifyListeners();
  }

  void setRepetitionPenaltySlope(double newRepetitionPenaltySlope) {
    repetitionPenaltySlope = newRepetitionPenaltySlope;
    notifyListeners();
  }

  void setRepetitionPenaltyIncludePreamble(bool newRepetitionPenaltyIncludePreamble) {
    repetitionPenaltyIncludePreamble = newRepetitionPenaltyIncludePreamble;
    notifyListeners();
  }

  void setRepetitionPenaltyIncludeGenerated(RepPenGenerated newRepetitionPenaltyIncludeGenerated) {
    repetitionPenaltyIncludeGenerated = newRepetitionPenaltyIncludeGenerated;
    notifyListeners();
  }

  void setRepetitionPenaltyTruncateToInput(bool newRepetitionPenaltyTruncateToInput) {
    repetitionPenaltyTruncateToInput = newRepetitionPenaltyTruncateToInput;
    notifyListeners();
  }

  void setRepetitionPenaltyRemoveParticipantNames(bool newRepetitionPenaltyRemoveParticipantNames) {
    repetitionPenaltyRemoveParticipantNames = newRepetitionPenaltyRemoveParticipantNames;
    notifyListeners();
  }

  void setPreamble(String newPreamble) {
    preamble = newPreamble;
    notifyListeners();
  }

  void setExtraRetries(int newExtraRetries) {
    extraRetries = newExtraRetries;
    notifyListeners();
  }

  void setRepetitionPenaltyLinesWithNoExtraSymbols(int newRepetitionPenaltyLinesWithNoExtraSymbols) {
    repetitionPenaltyLinesWithNoExtraSymbols = newRepetitionPenaltyLinesWithNoExtraSymbols;
    notifyListeners();
  }

  void setStopOnPunctuation(bool newStopOnPunctuation) {
    stopOnPunctuation = newStopOnPunctuation;
    notifyListeners();
  }

  void setRepetitionPenaltyKeepOriginalPrompt(bool newRepetitionPenaltyKeepOriginalPrompt) {
    repetitionPenaltyKeepOriginalPrompt = newRepetitionPenaltyKeepOriginalPrompt;
    notifyListeners();
  }

  void setUndoBySentence(bool newUndoBySentence) {
    undoBySentence = newUndoBySentence;
    notifyListeners();
  }

  void setGroupChatLines(CombineChatLinesType newGroupChatLines) {
    combineChatLines = newGroupChatLines;
    notifyListeners();
  }

  void setContinuousChatForceAlternateParticipants(bool newContinuousChatForceAlternateParticipants) {
    continuousChatForceAlternateParticipants = newContinuousChatForceAlternateParticipants;
    notifyListeners();
  }

  void setNoRepeatNGramSize(int newNoRepeatNGramSize) {
    noRepeatNGramSize = newNoRepeatNGramSize;
    notifyListeners();
  }

  void setAddWordsToBlacklistOnRetry(int newAddWordsToBlacklistOnRetry) {
    addWordsToBlacklistOnRetry = newAddWordsToBlacklistOnRetry;
    notifyListeners();
  }

  void setAddSpecialSymbolsToBlacklist(bool newAddSpecialSymbolsToBlacklist) {
    addSpecialSymbolsToBlacklist = newAddSpecialSymbolsToBlacklist;
    notifyListeners();
  }

  void setRemoveWordsFromBlacklistOnRetry(int newRemoveWordsFromBlacklistOnRetry) {
    removeWordsFromBlacklistOnRetry = newRemoveWordsFromBlacklistOnRetry;
    notifyListeners();
  }

  void setColonStartIsPreviousName(bool newColonStartIsPreviousName) {
    colonStartIsPreviousName = newColonStartIsPreviousName;
    notifyListeners();
  }

  void setSameParticipantOnRetry(ParticipantOnRetry newParticipantOnRetry) {
    participantOnRetry = newParticipantOnRetry;
    notifyListeners();
  }

  void load(ConfigModel other) {
    apiType = other.apiType;
    apiEndpoint = other.apiEndpoint;
    generatedTokensCount = other.generatedTokensCount;
    maxTotalTokens = other.maxTotalTokens;
    temperatureMode = other.temperatureMode;
    temperature = other.temperature;
    dynaTempHigh = other.dynaTempHigh;
    dynaTempExponent = other.dynaTempExponent;
    topP = other.topP;
    topK = other.topK;
    minP = other.minP;
    tfs = other.tfs;
    typical = other.typical;
    topA = other.topA;
    penaltyAlpha = other.penaltyAlpha;
    mirostat = other.mirostat;
    mirostatEta = other.mirostatEta;
    mirostatTau = other.mirostatTau;
    warpersOrder = other.warpersOrder.toList();
    repetitionPenalty = other.repetitionPenalty;
    frequencyPenalty = other.frequencyPenalty;
    presencePenalty = other.presencePenalty;
    repetitionPenaltyRange = other.repetitionPenaltyRange;
    repetitionPenaltySlope = other.repetitionPenaltySlope;
    repetitionPenaltyIncludeGenerated = other.repetitionPenaltyIncludeGenerated;
    repetitionPenaltyTruncateToInput = other.repetitionPenaltyTruncateToInput;
    preamble = other.preamble;
    extraRetries = other.extraRetries;
    repetitionPenaltyLinesWithNoExtraSymbols = other.repetitionPenaltyLinesWithNoExtraSymbols;
    repetitionPenaltyKeepOriginalPrompt = other.repetitionPenaltyKeepOriginalPrompt;
    repetitionPenaltyRemoveParticipantNames = other.repetitionPenaltyRemoveParticipantNames;
    stopOnPunctuation = other.stopOnPunctuation;
    undoBySentence = other.undoBySentence;
    combineChatLines = other.combineChatLines;
    continuousChatForceAlternateParticipants = other.continuousChatForceAlternateParticipants;
    noRepeatNGramSize = other.noRepeatNGramSize;
    addWordsToBlacklistOnRetry = other.addWordsToBlacklistOnRetry;
    addSpecialSymbolsToBlacklist = other.addSpecialSymbolsToBlacklist;
    removeWordsFromBlacklistOnRetry = other.removeWordsFromBlacklistOnRetry;
    colonStartIsPreviousName = other.colonStartIsPreviousName;
    participantOnRetry = other.participantOnRetry;

    notifyListeners();
  }

  static void normalizeWarpers(List<Warper> warpers) {
    for(var warper in Warper.values) {
      if(!warpers.contains(warper))
        warpers.add(warper);
    }
  }

  static ConfigModel fromJson(Map<String, dynamic> json) => _$ConfigModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}
