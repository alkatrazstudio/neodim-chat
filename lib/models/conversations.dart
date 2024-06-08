// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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

  Future<ConversationData> loadData() async {
    var dir = await dataDir();
    var f = File('${dir.path}/$id.json');
    var json = await f.readAsString();
    var jsonMap = jsonDecode(json) as Map<String, dynamic>;
    var data = ConversationData.fromJson(jsonMap);
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
    await Provider.of<ConversationsModel>(ctx, listen: false).setCurrent(ctx, this);
    Provider.of<ConfigModel>(ctx, listen: false).load(data.config);
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

  static String getCurrentPrompt(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    if(curConv == null)
      return '';

    var msgModel = Provider.of<MessagesModel>(context);

    switch(curConv.type)
    {
      case ConversationType.chat:
        return msgModel.chatText;

      case ConversationType.groupChat:
        return msgModel.groupChatText;

      case ConversationType.adventure:
        return msgModel.adventureText;

      case ConversationType.story:
        return msgModel.storyText;

      default:
        return '';
    }
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  int notUsedMessagesCount = 0;

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

  Future<void> setName(Conversation c, String newName) async {
    c.name = newName;
    notifyListeners();
  }

  Future<void> setType(Conversation c, ConversationType newType) async {
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
    self.notUsedMessagesCount = 0;

    self.notifyListeners();

    var msgModel = Provider.of<MessagesModel>(ctx, listen: false);
    msgModel.load(MessagesModel());
  }

  Future<void> setCurrent(BuildContext ctx, Conversation conversation) async {
    current = conversation;
    notUsedMessagesCount = 0;
    conversation.lastSetAsCurrentAt = DateTime.now();
    notifyListeners();
    await saveList(ctx);
  }

  void updateUsedMessagesCount(
    String usedPrompt,
    Participant promptedParticipant,
    MessagesModel msgModel,
    List<Message> inputMessages,
    CombineChatLinesType combineLines,
    String addedPromptSuffix,
    bool continueLastMsg
  ) {
    var c = current;
    if(c == null) {
      notUsedMessagesCount = 0;
      notifyListeners();
      return;
    }

    var usedMessages = msgModel.getUsedMessages(
        usedPrompt, promptedParticipant, inputMessages, c.type, combineLines, addedPromptSuffix, continueLastMsg);
    var usedMessagesCount = usedMessages.length;
    notUsedMessagesCount = inputMessages.length - usedMessagesCount;
    notifyListeners();
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

  static ConversationsModel fromJson(Map<String, dynamic> json) => _$ConversationsModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationsModelToJson(this);
}
