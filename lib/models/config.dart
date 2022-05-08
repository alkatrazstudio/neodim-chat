// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:neodim_chat/util/neodim_api.dart';

part 'config.g.dart';

@JsonSerializable(explicitToJson: true)
class ConfigModel extends ChangeNotifier {
  @JsonKey(defaultValue: 'http://0.0.0.0:8787/generate')
  String apiEndpoint = 'http://0.0.0.0:8787/generate';

  @JsonKey(defaultValue: 32)
  int generatedTokensCount = 32;

  @JsonKey(defaultValue: 1024)
  int maxTotalTokens = 1024;

  @JsonKey(defaultValue: 0.7)
  double temperature = 0.7;

  @JsonKey(defaultValue: 0)
  double topP = 0;

  @JsonKey(defaultValue: 0)
  int topK = 0;

  @JsonKey(defaultValue: 0.95)
  double tfs = 0.95;

  @JsonKey(defaultValue: 1.25)
  double repetitionPenalty = 1.25;

  @JsonKey(defaultValue: 0)
  int repetitionPenaltyRange = 512;

  @JsonKey(defaultValue: 1)
  double repetitionPenaltySlope = 1;

  @JsonKey(defaultValue: false)
  bool repetitionPenaltyIncludePreamble = false;

  @JsonKey(defaultValue: NeodimRepPenGenerated.slide)
  String repetitionPenaltyIncludeGenerated = NeodimRepPenGenerated.slide;

  @JsonKey(defaultValue: false)
  bool repetitionPenaltyTruncateToInput = false;

  @JsonKey(defaultValue: '')
  String preamble = '';

  @JsonKey(defaultValue: 0)
  int extraRetries = 0;

  @JsonKey(defaultValue: 5)
  int repetitionPenaltyLinesWithNoExtraSymbols = 5;

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

  void load(ConfigModel other) {
    apiEndpoint = other.apiEndpoint;
    generatedTokensCount = other.generatedTokensCount;
    maxTotalTokens = other.maxTotalTokens;
    temperature = other.temperature;
    topP = other.topP;
    topK = other.topK;
    tfs = other.tfs;
    repetitionPenalty = other.repetitionPenalty;
    repetitionPenaltyRange = other.repetitionPenaltyRange;
    repetitionPenaltySlope = other.repetitionPenaltySlope;
    repetitionPenaltyIncludeGenerated = other.repetitionPenaltyIncludeGenerated;
    repetitionPenaltyTruncateToInput = other.repetitionPenaltyTruncateToInput;
    preamble = other.preamble;
    extraRetries = other.extraRetries;
    repetitionPenaltyLinesWithNoExtraSymbols = other.repetitionPenaltyLinesWithNoExtraSymbols;

    notifyListeners();
  }

  static ConfigModel fromJson(Map<String, dynamic> json) => _$ConfigModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}
