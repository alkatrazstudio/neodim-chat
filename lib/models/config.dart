// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:change_case/change_case.dart';
import 'package:json_annotation/json_annotation.dart';

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
  dry,
  topK,
  typical,
  topP,
  minP,
  xtc,
  temperature,
  topNSigma
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
  @JsonKey(defaultValue: '0.0.0.0')
  String apiEndpoint = '0.0.0.0';

  @JsonKey(defaultValue: 64)
  int generatedTokensCount = 64;

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

  @JsonKey(defaultValue: 0)
  double typical = 0;

  @JsonKey(defaultValue: MirostatVersion.none, unknownEnumValue: MirostatVersion.none)
  MirostatVersion mirostat = MirostatVersion.none;

  @JsonKey(defaultValue: 5.0)
  double mirostatTau = 5.0;

  @JsonKey(defaultValue: 0.1)
  double mirostatEta = 0.1;

  @JsonKey(defaultValue: 0.0)
  double xtcProbability = 0.0;

  @JsonKey(defaultValue: 0.1)
  double xtcThreshold = 0.1;

  @JsonKey(defaultValue: 0)
  double dryMultiplier = 0;

  @JsonKey(defaultValue: 1.75)
  double dryBase = 1.75;

  @JsonKey(defaultValue: 2)
  int dryAllowedLength = 2;

  @JsonKey(defaultValue: 0)
  int dryRange = 0;

  @JsonKey(defaultValue: -1.0)
  double topNSigma = -1.0;

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

  @JsonKey(defaultValue: false)
  bool repetitionPenaltyIncludePreamble = false;

  @JsonKey(defaultValue: '')
  String preamble = '';

  @JsonKey(defaultValue: false)
  bool stopOnPunctuation = false;

  @JsonKey(defaultValue: true)
  bool undoBySentence = true;

  @JsonKey(defaultValue: CombineChatLinesType.no, unknownEnumValue: CombineChatLinesType.no)
  CombineChatLinesType combineChatLines = CombineChatLinesType.no;

  @JsonKey(defaultValue: true)
  bool continuousChatForceAlternateParticipants = true;

  @JsonKey(defaultValue: [])
  List<String> initialBlacklist = const [];

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

  @JsonKey(defaultValue: true)
  bool streamResponse = true;

  @JsonKey(defaultValue: 0)
  int saveCacheAfterProcessingSecs = 0;

  @JsonKey(defaultValue: 0)
  int extraRetries = 0;

  String get inputPreamble {
    var s = preamble.trim();
    if(s.isEmpty)
      return '';
    return '$preamble\n\n';
  }

  void load(ConfigModel other) {
    apiEndpoint = other.apiEndpoint;
    generatedTokensCount = other.generatedTokensCount;
    temperatureMode = other.temperatureMode;
    temperature = other.temperature;
    dynaTempHigh = other.dynaTempHigh;
    dynaTempExponent = other.dynaTempExponent;
    topP = other.topP;
    topK = other.topK;
    minP = other.minP;
    typical = other.typical;
    mirostat = other.mirostat;
    mirostatEta = other.mirostatEta;
    mirostatTau = other.mirostatTau;
    xtcProbability = other.xtcProbability;
    xtcThreshold = other.xtcThreshold;
    dryMultiplier = other.dryMultiplier;
    dryBase = other.dryBase;
    dryAllowedLength = other.dryAllowedLength;
    dryRange = other.dryRange;
    topNSigma = other.topNSigma;
    warpersOrder = other.warpersOrder.toList();
    repetitionPenalty = other.repetitionPenalty;
    frequencyPenalty = other.frequencyPenalty;
    presencePenalty = other.presencePenalty;
    repetitionPenaltyRange = other.repetitionPenaltyRange;
    preamble = other.preamble;
    stopOnPunctuation = other.stopOnPunctuation;
    undoBySentence = other.undoBySentence;
    combineChatLines = other.combineChatLines;
    continuousChatForceAlternateParticipants = other.continuousChatForceAlternateParticipants;
    initialBlacklist = other.initialBlacklist.toList();
    addWordsToBlacklistOnRetry = other.addWordsToBlacklistOnRetry;
    addSpecialSymbolsToBlacklist = other.addSpecialSymbolsToBlacklist;
    removeWordsFromBlacklistOnRetry = other.removeWordsFromBlacklistOnRetry;
    colonStartIsPreviousName = other.colonStartIsPreviousName;
    participantOnRetry = other.participantOnRetry;
    streamResponse = other.streamResponse;
    saveCacheAfterProcessingSecs = other.saveCacheAfterProcessingSecs;
    extraRetries = other.extraRetries;

    notifyListeners();
  }

  static void normalizeWarpers(List<Warper> warpers) {
    Warper? prevWarper;
    for(var warper in Warper.values) {
      if(!warpers.contains(warper)) {
        if(prevWarper == null) {
          warpers.insert(0, warper);
        } else {
          var prevWarperPos = warpers.indexOf(prevWarper);
          warpers.insert(prevWarperPos + 1, warper);
        }
      }
      prevWarper = warper;
    }
  }

  static ConfigModel fromJson(Map<String, dynamic> json) => _$ConfigModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}
