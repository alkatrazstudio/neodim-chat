// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:neodim_chat/models/messages.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';

part 'conversations.g.dart';

@JsonSerializable(explicitToJson: true)
class Conversation {
  static const Uuid uuid = Uuid();

  static const String typeChat = 'chat';
  static const String typeAdventure = 'adventure';

  Conversation({
    required this.name,
    String? id,
    DateTime? createdAt,
    this.type = typeChat
  }): id = id ?? uuid.v4(),
      createdAt = createdAt ?? DateTime.now();

  @JsonKey(defaultValue: 'Conversation')
  String name;
  final String id;
  final DateTime createdAt;

  @JsonKey(defaultValue: Conversation.typeChat)
  String type = Conversation.typeChat;

  static Conversation create(String name) {
    return Conversation(name: name);
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

  Future saveData(ConversationData data) async {
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

    setAsCurrent(ctx, data);
    return data;
  }

  void setAsCurrent(BuildContext ctx, ConversationData data) {
    Provider.of<MessagesModel>(ctx, listen: false).load(data.msgModel);
    Provider.of<ConversationsModel>(ctx, listen: false).setCurrent(this);
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

  Future delete() async {
    var dir = await dataDir();
    var f = File('${dir.path}/$id.json');
    if(!await f.exists())
      return;

    await f.delete();
  }

  static Conversation fromJson(Map<String, dynamic> json) {
    json['type'] ??= typeChat;
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

  @JsonKey(ignore: true)
  Conversation? current;

  @JsonKey(ignore: true)
  int notUsedMessagesCount = 0;

  Future load() async {
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

  Future save() async {
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

  Future setName(Conversation c, String newName) async {
    c.name = newName;
    notifyListeners();
  }

  Future setType(Conversation c, String newType) async {
    c.type = newType;
    notifyListeners();
  }

  static Future delete(BuildContext ctx, Conversation c) async {
    var self = Provider.of<ConversationsModel>(ctx, listen: false);
    var i = self.conversations.indexOf(c);
    if(i < 0)
      return;

    var wasCurrent = c == self.current;

    await c.delete();

    self.conversations.removeAt(i);
    await self.save();
    if(wasCurrent)
      self.current = null;
    self.notUsedMessagesCount = 0;

    self.notifyListeners();

    var msgModel = Provider.of<MessagesModel>(ctx, listen: false);
    msgModel.load(MessagesModel());
  }

  void setCurrent(Conversation conversation) {
    current = conversation;
    notUsedMessagesCount = 0;
    notifyListeners();
  }

  void updateUsedMessagesCount(
    String usedPrompt,
    Participant promptedParticipant,
    MessagesModel msgModel,
    List<Message> inputMessages
  ) {
    var c = current;
    if(c == null) {
      notUsedMessagesCount = 0;
      notifyListeners();
      return;
    }

    var usedMessages = msgModel.getUsedMessages(
        usedPrompt, promptedParticipant, inputMessages, c.type);
    var usedMessagesCount = usedMessages.length;
    notUsedMessagesCount = inputMessages.length - usedMessagesCount;
    notifyListeners();
  }

  static Future saveCurrentData(BuildContext ctx) async {
    Provider.of<ConversationsModel>(ctx, listen: false).current?.saveCurrentData(ctx);
  }

  static ConversationsModel fromJson(Map<String, dynamic> json) => _$ConversationsModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationsModelToJson(this);
}
