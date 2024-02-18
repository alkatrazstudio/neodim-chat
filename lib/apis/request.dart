// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../apis/neodim.dart';
import '../apis/llama_cpp.dart';
import '../apis/response.dart';
import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';

enum RepPenGenerated {
  ignore,
  expand,
  slide
}

enum StopStringsType {
  string,
  regex
}

enum ApiType {
  neodim,
  llamaCpp
}

class ApiRequestParams {
  const ApiRequestParams({
    required this.inputText,
    this.repPenText,
    this.participantNames,
    this.blacklistWordsForRetry,
    required this.conversation,
    required this.cfgModel,
    required this.msgModel,
    required this.apiModel
  });

  final String inputText;
  final String? repPenText;
  final List<String>? participantNames;
  final Set<String>? blacklistWordsForRetry;
  final Conversation conversation;
  final ConfigModel cfgModel;
  final MessagesModel msgModel;
  final ApiModel apiModel;
}

class ApiRequest {
  static Future<ApiResponse?> run(
    BuildContext context,
    String inputText,
    String? repPenText,
    List<String>? participantNames,
    Set<String>? blacklistWordsForRetry
  ) async {
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var conversation = convModel.current;
    if(conversation == null)
      return null;

    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var apiModel = Provider.of<ApiModel>(context, listen: false);

    var params = ApiRequestParams(
      inputText: inputText,
      repPenText: repPenText,
      participantNames: participantNames,
      blacklistWordsForRetry: blacklistWordsForRetry,
      conversation: conversation,
      cfgModel: cfgModel,
      msgModel: msgModel,
      apiModel: apiModel
    );

    ApiResponse? result;
    switch(cfgModel.apiType)
    {
      case ApiType.neodim:
        result = await ApiRequestNeodim.run(params);
        break;

      case ApiType.llamaCpp:
        result = await ApiRequestLlamaCpp.run(params);
        break;
    }
    return result;
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

  static normalizeEndpoint(String endpoint, int port, String path) {
    Uri url;
    try {
      url = Uri.parse(endpoint);
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
