// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import '../apis/request.dart';

part 'config.g.dart';

class CombineChatLinesType {
  static const String no = 'no';
  static const String onlyForServer = 'onlyForServer';
  static const String previousLines = 'previousLines';
}

@JsonSerializable(explicitToJson: true)
class ConfigModel extends ChangeNotifier {
  @JsonKey(defaultValue: ApiType.neodim, unknownEnumValue: ApiType.neodim)
  ApiType apiType = ApiType.neodim;

  @JsonKey(defaultValue: 'http://0.0.0.0:8787/generate')
  String apiEndpoint = 'http://0.0.0.0:8787/generate';

  @JsonKey(defaultValue: 64)
  int generatedTokensCount = 64;

  @JsonKey(defaultValue: 2048)
  int maxTotalTokens = 2048;

  @JsonKey(defaultValue: 0.7)
  double temperature = 0.7;

  @JsonKey(defaultValue: 0)
  double topP = 0;

  @JsonKey(defaultValue: 0)
  int topK = 0;

  @JsonKey(defaultValue: 0)
  double tfs = 0;

  @JsonKey(defaultValue: 0.2)
  double typical = 0.2;

  @JsonKey(defaultValue: 0)
  double topA = 0;

  @JsonKey(defaultValue: 0)
  double penaltyAlpha = 0;

  @JsonKey(defaultValue: Warper.defaultOrder)
  List<String> warpersOrder = Warper.defaultOrder;

  @JsonKey(defaultValue: 1.15)
  double repetitionPenalty = 1.15;

  @JsonKey(defaultValue: 0)
  int repetitionPenaltyRange = 2048;

  @JsonKey(defaultValue: 0.75)
  double repetitionPenaltySlope = 0.75;

  @JsonKey(defaultValue: false)
  bool repetitionPenaltyIncludePreamble = false;

  @JsonKey(defaultValue: RepPenGenerated.slide)
  String repetitionPenaltyIncludeGenerated = RepPenGenerated.slide;

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

  @JsonKey(defaultValue: CombineChatLinesType.no)
  String combineChatLines = CombineChatLinesType.no;

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

  String get inputPreamble {
    var s = preamble.trim();
    if(s.isEmpty)
      return '';
    return '$preamble\n\n';
  }

  void setApiType(String newApiType) {
    apiType = ApiType.byNameOrDefault(newApiType);
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

  void setTemperature(double newTemperature) {
    temperature = newTemperature;
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

  void setWarpersOrder(List<String> newWarpersOrder) {
    warpersOrder = newWarpersOrder.toList();
    notifyListeners();
  }

  void setRepetitionPenalty(double newRepetitionPenalty) {
    repetitionPenalty = newRepetitionPenalty;
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

  void setRepetitionPenaltyIncludeGenerated(String newRepetitionPenaltyIncludeGenerated) {
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

  void setGroupChatLines(String newGroupChatLines) {
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

  void load(ConfigModel other) {
    apiType = other.apiType;
    apiEndpoint = other.apiEndpoint;
    generatedTokensCount = other.generatedTokensCount;
    maxTotalTokens = other.maxTotalTokens;
    temperature = other.temperature;
    topP = other.topP;
    topK = other.topK;
    tfs = other.tfs;
    typical = other.typical;
    topA = other.topA;
    penaltyAlpha = other.penaltyAlpha;
    warpersOrder = other.warpersOrder.toList();
    repetitionPenalty = other.repetitionPenalty;
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

    notifyListeners();
  }

  static ConfigModel fromJson(Map<String, dynamic> json) => _$ConfigModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}
