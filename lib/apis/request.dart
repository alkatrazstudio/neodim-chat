// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2023, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../apis/neodim.dart';
import '../apis/llama_cpp.dart';
import '../apis/response.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';

class RepPenGenerated {
  static const String ignore = 'ignore';
  static const String expand = 'expand';
  static const String slide = 'slide';
}

class StopStringsType {
  static const String string = 'string';
  static const String regex = 'regex';
}

class Warper {
  static const String repetitionPenalty = 'repetition_penalty';
  static const String temperature = 'temperature';
  static const String topK = 'top_k';
  static const String topP = 'top_p';
  static const String typical = 'typical';
  static const String tfs = 'tfs';
  static const String topA = 'top_a';

  static const List<String> defaultOrder = [
    repetitionPenalty,
    temperature,
    topK,
    topP,
    tfs,
    typical,
    topA
  ];
}

enum ApiType {
  neodim,
  llamaCpp;

  static ApiType byNameOrDefault(String name) {
    try {
      return ApiType.values.byName(name);
    } on Exception catch (_) {
      return ApiType.values.first;
    }
  }
}

class ApiRequestParams {
  const ApiRequestParams({
    required this.inputText,
    this.repPenText,
    this.participantNames,
    this.blacklistWordsForRetry,
    required this.conversation,
    required this.cfgModel,
    required this.msgModel
  });

  final String inputText;
  final String? repPenText;
  final List<String>? participantNames;
  final Set<String>? blacklistWordsForRetry;
  final Conversation conversation;
  final ConfigModel cfgModel;
  final MessagesModel msgModel;
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

    var params = ApiRequestParams(
      inputText: inputText,
      repPenText: repPenText,
      participantNames: participantNames,
      blacklistWordsForRetry: blacklistWordsForRetry,
      conversation: conversation,
      cfgModel: cfgModel,
      msgModel: msgModel
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
      case Conversation.typeChat:
        participantNames = msgModel.participants.map((p) => p.name).toList();
        break;

      case Conversation.typeGroupChat:
        participantNames = [msgModel.participants[Message.youIndex].name] + msgModel.getGroupParticipantNames(true);
        break;

      default:
        return [];
    }
    var stopStrings = participantNames.map((name) => '$name${MessagesModel.chatPromptSeparator}').toList();
    return stopStrings;
  }

  static List<String> getStopStringsForConversationType(String type) {
    switch(type) {
        case Conversation.typeChat:
        case Conversation.typeGroupChat:
          return [MessagesModel.messageSeparator];

        case Conversation.typeAdventure:
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
}
