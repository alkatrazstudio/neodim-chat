// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../apis/request.dart';
import '../models/api_model.dart';
import '../models/config.dart';
import '../models/messages.dart';
import '../util/popups.dart';

part 'conversations.g.dart';

enum ConversationType {
  chat,
  adventure,
  story,
  groupChat
}

@JsonSerializable(explicitToJson: true)
class Conversation {
  static const Uuid uuid = Uuid();

  Conversation({
    required this.name,
    String? id,
    DateTime? createdAt,
    this.lastSetAsCurrentAt,
    required this.type
  }): id = id ?? uuid.v4(),
      createdAt = createdAt ?? DateTime.now();

  bool get isChat => type == ConversationType.chat || type == ConversationType.groupChat;

  @JsonKey(defaultValue: 'Conversation')
  String name;
  final String id;
  final DateTime createdAt;
  DateTime? lastSetAsCurrentAt;

  @JsonKey(defaultValue: ConversationType.chat, unknownEnumValue: ConversationType.chat)
  ConversationType type = ConversationType.chat;

  static Conversation create(String name) {
    return Conversation(name: name, type: ConversationType.chat);
  }

  static Future<Directory> dataDir() async {
    var rootDir = await getApplicationDocumentsDirectory();
    var convDir = Directory('${rootDir.path}/conversations');
    await convDir.create(recursive: true);
    return convDir;
  }

  static Future<ConversationData> loadDataById(String id) async {
    var dir = await dataDir();
    var f = File('${dir.path}/$id.json');
    var json = await f.readAsString();
    var jsonMap = jsonDecode(json) as Map<String, dynamic>;
    var data = ConversationData.fromJson(jsonMap);
    return data;
  }

  Future<ConversationData> loadData() async {
    var data = await loadDataById(id);
    return data;
  }

  Future<void> saveData(ConversationData data) async {
    var jsonMap = data.toJson();
    var json = jsonEncode(jsonMap);
    var dir = await dataDir();
    var f = File('${dir.path}/$id.json');
    await f.writeAsString(json);
  }

  Future<ConversationData> loadAsCurrent(BuildContext ctx) async {
    ConversationData data;

    try {
      data = await loadData();
    } catch(e) {
      data = ConversationData.empty();
    }

    await setAsCurrent(ctx, data);
    return data;
  }

  Future<void> setAsCurrent(BuildContext ctx, ConversationData data) async {
    Provider.of<MessagesModel>(ctx, listen: false).load(data.msgModel);
    Provider.of<ConfigModel>(ctx, listen: false).load(data.config);
    await Provider.of<ConversationsModel>(ctx, listen: false).setCurrent(ctx, this);
  }

  ConversationData getCurrentData(BuildContext ctx) {
    var data = ConversationData(
      msgModel: Provider.of<MessagesModel>(ctx, listen: false),
      config: Provider.of<ConfigModel>(ctx, listen: false)
    );
    return data;
  }

  Future<ConversationData> saveCurrentData(BuildContext ctx) async {
    var data = getCurrentData(ctx);
    await saveData(data);
    return data;
  }

  Future<void> delete() async {
    var dir = await dataDir();
    var f = File('${dir.path}/$id.json');
    if(!await f.exists())
      return;

    await f.delete();
  }

  static String getCurrentMessagesText(BuildContext context, {bool allMessages = false}) {
    var curConv = Provider.of<ConversationsModel>(context, listen: false).current;
    if(curConv == null)
      return '';

    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var msgs = allMessages ? msgModel.messages : msgModel.contextMessages;

    switch(curConv.type)
    {
      case ConversationType.chat:
        return msgModel.getTextForChat(msgs, CombineChatLinesType.no, false, false);

      case ConversationType.groupChat:
        return msgModel.getTextForChat(msgs, CombineChatLinesType.no, true, false);

      case ConversationType.adventure:
        return msgModel.getTextForAdventure(msgs);

      case ConversationType.story:
        return msgModel.getTextForStory(msgs);
    }
  }

  Future<void> convertChatToGroupChat(BuildContext ctx) async {
    var data = await loadData();
    var newMessages = data.msgModel.messages.map((msg) {
      String newText;
      if(msg.authorIndex == Message.youIndex) {
        newText = msg.text;
      } else {
        var authorName = data.msgModel.participants[msg.authorIndex].name;
        newText = '$authorName${MessagesModel.chatPromptSeparator} ${msg.text}';
      }
      var newMsg = msg.withText(newText);
      return newMsg;
    }).toList();
    data.msgModel.setAllMessages(newMessages);
    await saveData(data);
    var convModel = Provider.of<ConversationsModel>(ctx, listen: false);
    convModel.setType(this, ConversationType.groupChat);
    await ConversationsModel.saveList(ctx);
  }

  static Future<String?> getNextGroupParticipantName(
    BuildContext context,
    String inputText,
    List<String> participantNames
  ) async {
    if(participantNames.length == 1)
      return participantNames[0];

    var apiModel = Provider.of<ApiModel>(context, listen: false);
    try {
      apiModel.setApiRunning(true);
      var response = await ApiRequest.run(
        context: context,
        inputText: inputText,
        participantNames: participantNames
      );
      var responseText = response?.sequences.firstOrNull?.outputText ?? '';
      if(responseText.isEmpty)
        return null;
      if(participantNames.contains(responseText))
        return responseText;
    } finally {
      apiModel.setApiRunning(false);
    }
    return null;
  }

  static Future<(int index, String name)> getNextParticipantNameFromServer(BuildContext context, bool includeYou, Message? undoMessage) async {
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var participantNames = msgModel.getGroupParticipantNames(false);
    var groupChatParticipantNames = participantNames.toList();
    if(undoMessage != null && undoMessage.authorIndex != Message.youIndex) {
      switch(cfgModel.participantOnRetry) {
        case ParticipantOnRetry.different:
          if(participantNames.length > 1) {
            var prevParticipantName = MessagesModel.extractParticipantName(undoMessage.text);
            if(prevParticipantName.isNotEmpty)
              participantNames = participantNames.where((name) => name != prevParticipantName).toList();
          }
          break;

        case ParticipantOnRetry.same:
          var prevParticipantName = MessagesModel.extractParticipantName(undoMessage.text);
          if(prevParticipantName.isNotEmpty && participantNames.contains(prevParticipantName))
            participantNames = [prevParticipantName];
          break;

        default:
          break;
      }
    }
    var youName = msgModel.participants[Message.youIndex].name;
    if(includeYou)
      participantNames.add(youName);

    if(cfgModel.continuousChatForceAlternateParticipants) {
      var lastMsg = msgModel.messages.lastOrNull;
      if(lastMsg != null) {
        var lastName = lastMsg.isYou ? youName : MessagesModel.extractParticipantName(lastMsg.text);
        if(lastName.isNotEmpty)
          participantNames = participantNames.where((name) => name != lastName).toList();
      }
    }

    String? nextName;
    if(participantNames.length == 1) {
      nextName = participantNames.first;
    } else {
      var inputText = Conversation.getCurrentMessagesText(context);
      nextName = await getNextGroupParticipantName(context, inputText, participantNames);
      if(nextName == null) {
        var nextNameIndex = Random().nextInt(participantNames.length);
        nextName = participantNames[nextNameIndex];
      }
    }
    var nextParticipantIndex = (groupChatParticipantNames.contains(nextName) || nextName != youName) ? Message.groupChatIndex : Message.youIndex;
    return (nextParticipantIndex, nextName);
  }

  static Conversation fromJson(Map<String, dynamic> json) {
    json['type'] ??= ConversationType.chat;
    json['createdAt'] ??= DateTime.fromMicrosecondsSinceEpoch(0).toIso8601String();
    return _$ConversationFromJson(json);
  }
  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  @override
  bool operator == (other) => other is Conversation && id == other.id;
  @override
  int get hashCode => id.hashCode;
}


@JsonSerializable()
class ImportData {
  const ImportData({
    required this.createdAt,
    required this.conversations,
    required this.conversationData
  });

  final DateTime createdAt;
  final List<Conversation> conversations;
  final Map<String, ConversationData> conversationData;

  static ImportData fromJson(Map<String, dynamic> json) => _$ImportDataFromJson(json);
  Map<String, dynamic> toJson() => _$ImportDataToJson(this);
}


@JsonSerializable(explicitToJson: true)
class ConversationData {
  const ConversationData({
    required this.msgModel,
    required this.config
  });

  final MessagesModel msgModel;
  final ConfigModel config;

  static ConversationData empty() {
    return ConversationData(
      msgModel: MessagesModel(),
      config: ConfigModel()
    );
  }

  static ConversationData fromJson(Map<String, dynamic> json) {
    json['msgModel'] ??= MessagesModel().toJson();
    json['config'] ??= ConfigModel().toJson();

    return _$ConversationDataFromJson(json);
  }

  Map<String, dynamic> toJson() => _$ConversationDataToJson(this);
}


@JsonSerializable(explicitToJson: true)
class ConversationsModel extends ChangeNotifier {
  @JsonKey(defaultValue: <Conversation>[])
  List<Conversation> conversations = [];

  @JsonKey(includeFromJson: false, includeToJson: false)
  Conversation? current;

  Future<void> load() async {
    var rootDir = await getApplicationDocumentsDirectory();
    var f = File('${rootDir.path}/conversations.json');
    if(!await f.exists())
      return;
    var json = await f.readAsString();
    var jsonMap = jsonDecode(json) as Map<String, dynamic>;
    var other = fromJson(jsonMap);
    conversations.clear();
    conversations.addAll(other.conversations);
    notifyListeners();
  }

  Future<void> save() async {
    var jsonMap = toJson();
    var json = jsonEncode(jsonMap);
    var rootDir = await getApplicationDocumentsDirectory();
    rootDir.create(recursive: true);
    var f = File('${rootDir.path}/conversations.json');
    await f.writeAsString(json);
  }

  void add(Conversation c) {
    conversations.add(c);
    notifyListeners();
  }

  void setName(Conversation c, String newName) {
    c.name = newName;
    notifyListeners();
  }

  void setType(Conversation c, ConversationType newType) {
    c.type = newType;
    notifyListeners();
  }

  static Future<void> delete(BuildContext ctx, Conversation c) async {
    var self = Provider.of<ConversationsModel>(ctx, listen: false);
    var i = self.conversations.indexOf(c);
    if(i < 0)
      return;

    var wasCurrent = c == self.current;

    await c.delete();

    self.conversations.removeAt(i);
    await saveList(ctx);
    if(wasCurrent)
      self.current = null;

    self.notifyListeners();

    var msgModel = Provider.of<MessagesModel>(ctx, listen: false);
    msgModel.load(MessagesModel());
  }

  Future<void> setCurrent(BuildContext ctx, Conversation? conversation) async {
    current = conversation;
    if(conversation != null)
      conversation.lastSetAsCurrentAt = DateTime.now();
    notifyListeners();
    var apiModel = Provider.of<ApiModel>(ctx, listen: false);
    apiModel.resetStats();
    ApiRequest.updateStats(ctx);
    await saveList(ctx);
  }

  static Future<void> saveCurrentData(BuildContext ctx) async {
    try {
      await Provider.of<ConversationsModel>(ctx, listen: false).current?.saveCurrentData(ctx);
    } catch(e) {
      showPopupMsg(ctx, 'Can\'t save the conversation: $e');
      rethrow;
    }
  }

  static Future<void> saveList(BuildContext ctx) async {
    try {
      await Provider.of<ConversationsModel>(ctx, listen: false).save();
    } catch(e) {
      showPopupMsg(ctx, 'Can\'t save the list of conversations: $e');
      rethrow;
    }
  }

  static Future<ImportData> export(BuildContext ctx, List<String> conversationIds) async {
    var convModel = Provider.of<ConversationsModel>(ctx, listen: false);
    var conversations = convModel.conversations.where((c) => conversationIds.contains(c.id)).toList();
    var conversationData = <String, ConversationData>{};
    for(var conv in conversations) {
      var data = await Conversation.loadDataById(conv.id);
      conversationData[conv.id] = data;
    }
    var importData = ImportData(
      createdAt: DateTime.now(),
      conversations: conversations,
      conversationData: conversationData
    );
    return importData;
  }

  static Future<List<Conversation>> import(BuildContext ctx, ImportData importData, List<String> conversationIds) async {
    var convModel = Provider.of<ConversationsModel>(ctx, listen: false);
    var conversations = importData.conversations.where((c) => conversationIds.contains(c.id)).toList();
    var failedConversations = <Conversation>[];
    for(var conversation in conversations) {
      var conversationData = importData.conversationData[conversation.id];
      if(conversationData == null)
        continue;
      try {
        await conversation.saveData(conversationData);
      } catch(e) {
        failedConversations.add(conversation);
        continue;
      }
      var i = convModel.conversations.indexWhere((c) => c.id == conversation.id);
      if(i == -1)
        convModel.conversations.add(conversation);
      else
        convModel.conversations[i] = conversation;
    }
    await convModel.save();
    convModel.notifyListeners();
    return failedConversations;
  }

  static List<Conversation> filteredAndSorted(List<Conversation> conversations, String search) {
    var searchFilter = search.trim().toUpperCase();
    var convList = searchFilter.isEmpty
      ? conversations
      : conversations.where((c) => c.name.toUpperCase().contains(searchFilter)).toList();
    convList = convList.sorted((a, b) {
      var aDate = a.lastSetAsCurrentAt ?? a.createdAt;
      var bDate = b.lastSetAsCurrentAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    return convList;
  }

  static ConversationsModel fromJson(Map<String, dynamic> json) => _$ConversationsModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationsModelToJson(this);
}
