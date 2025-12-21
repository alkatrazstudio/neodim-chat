// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../apis/llama_cpp.dart';
import '../apis/response.dart';
import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';

enum StopStringsType {
  string,
  regex
}

class ApiRequestParams {
  const ApiRequestParams({
    required this.inputText,
    this.participantNames,
    this.blacklistWordsForRetry,
    required this.conversation,
    required this.cfgModel,
    required this.msgModel,
    required this.apiModel,
    required this.apiCancelModel,
    required this.onlySaveCache,
    required this.onNewStreamText
  });

  final String inputText;
  final List<String>? participantNames;
  final Set<String>? blacklistWordsForRetry;
  final Conversation conversation;
  final ConfigModel cfgModel;
  final MessagesModel msgModel;
  final ApiModel apiModel;
  final ApiCancelModel apiCancelModel;
  final bool onlySaveCache;
  final void Function(String newText)? onNewStreamText;
}

class ApiRequest {
  static Future<ApiResponse?> run({
    required BuildContext context,
    required String inputText,
    List<String>? participantNames,
    Set<String>? blacklistWordsForRetry,
    bool onlySaveCache = false,
    void Function(String newText)? onNewStreamText
  }) async {
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var conversation = convModel.current;
    if(conversation == null)
      return null;

    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var apiModel = Provider.of<ApiModel>(context, listen: false);
    var apiCancelModel = Provider.of<ApiCancelModel>(context, listen: false);

    var params = ApiRequestParams(
      inputText: inputText,
      participantNames: participantNames,
      blacklistWordsForRetry: blacklistWordsForRetry,
      conversation: conversation,
      cfgModel: cfgModel,
      msgModel: msgModel,
      apiModel: apiModel,
      apiCancelModel: apiCancelModel,
      onlySaveCache: onlySaveCache,
      onNewStreamText: onNewStreamText
    );

    var result = await ApiRequestLlamaCpp.run(params);
    return result;
  }

  static Future<void> updateStats(BuildContext context) async {
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var apiModel = Provider.of<ApiModel>(context, listen: false);
    var prompt = Conversation.getCurrentMessagesText(context);
    var preamble = cfgModel.inputPreamble;
    var inputText = preamble + prompt;
    try {
      await ApiRequestLlamaCpp.updateStats(inputText, cfgModel, apiModel);
      apiModel.setAvailability(ApiAvailabilityMode.available);
    } catch(_) {
    }
  }

  static Future<void> ping(BuildContext context) async {
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var apiModel = Provider.of<ApiModel>(context, listen: false);
    try {
      var isAvailable = await ApiRequestLlamaCpp.ping(cfgModel);
      var oldAvailability = apiModel.availability;
      var newAvailability = isAvailable ? ApiAvailabilityMode.available : ApiAvailabilityMode.loading;
      apiModel.setAvailability(newAvailability);
      if(newAvailability == ApiAvailabilityMode.available && oldAvailability != ApiAvailabilityMode.available)
        updateStats(context);
    } catch(_) {
      apiModel.setAvailability(ApiAvailabilityMode.notAvailable);
    }
  }

  static List<String> getParticipantNameStopStrings(MessagesModel msgModel, Conversation conv) {
    List<String> participantNames;
    switch(conv.type) {
      case ConversationType.chat:
        participantNames = msgModel.participants.map((p) => p.name).toList();
        break;

      case ConversationType.groupChat:
        participantNames = [msgModel.participants[Message.youIndex].name] + msgModel.getGroupParticipantNames(true);
        break;

      default:
        return [];
    }
    var stopStrings = participantNames.map((name) => '$name${MessagesModel.chatPromptSeparator}').toList();
    return stopStrings;
  }

  static List<String> getStopStringsForConversationType(ConversationType type) {
    switch(type) {
        case ConversationType.chat:
        case ConversationType.groupChat:
          return [MessagesModel.messageSeparator];

        case ConversationType.adventure:
          return [MessagesModel.actionPrompt];

        default:
          return [];
      }
  }

  static List<String> getPlainTextStopStrings(MessagesModel msgModel, Conversation conv) {
    var forType = getStopStringsForConversationType(conv.type);
    var forNames = getParticipantNameStopStrings(msgModel, conv);
    var stopStrings = forType + forNames;
    return stopStrings;
  }

  static String normalizeEndpoint(String endpoint, int port, String path) {
    Uri url;
    try {
      var m = RegExp(r'^(.*):(\d+)$').firstMatch(endpoint);
      if(m == null)
        url = Uri.parse(endpoint);
      else
        url = Uri(host: m.group(1)!, port: int.parse(m.group(2)!));
    } catch(e) {
      return endpoint;
    }
    if(url.host.isEmpty)
      url = Uri(host: endpoint);
    var isIP = false;
    if(!url.hasScheme) {
      try {
        Uri.parseIPv4Address(url.host);
        url = url.replace(scheme: 'http');
        isIP = true;
      } catch(e) {
        try {
          Uri.parseIPv6Address(url.host);
          url = url.replace(scheme: 'http');
          isIP = true;
        } catch(e) {
          url = url.replace(scheme: 'https');
        }
      }
    }
    if(!url.hasPort && isIP)
      url = url.replace(port: port);
    if(url.hasEmptyPath || !url.hasAbsolutePath || url.path.isEmpty || url.path == '/') {
      url = url.replace(path: path);
    }
    endpoint = url.toString();
    return endpoint;
  }

  static List<Warper> supportedWarpers(Map<Warper, String> warpersMap) {
    return warpersMap.keys.toList();
  }

  static List<String>? warpersToJson(Map<Warper, String> warpersMap, List<Warper>? warpers) {
    if(warpers == null)
      return null;
    var names = <String>[];
    for(var warper in warpers) {
      var name = warpersMap[warper];
      if(name != null)
        names.add(name);
    }
    return names;
  }
}
