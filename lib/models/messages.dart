// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:neodim_chat/models/conversations.dart';

import '../util/json_converters.dart';

part 'messages.g.dart';

@JsonSerializable(explicitToJson: true)
class Message {
  Message({
    required this.text,
    required this.authorIndex,
    required this.isGenerated
  });

  static const int youIndex = 0;
  static const int dmIndex = 1;
  static const int commentIndex = -1;

  bool get isComment => authorIndex == commentIndex;
  bool get isYou => authorIndex == youIndex;

  @JsonKey(defaultValue: '')
  final String text;

  @JsonKey(defaultValue: 0)
  final int authorIndex;

  @JsonKey(defaultValue: false)
  final bool isGenerated;

  static String format(String text, {bool upperFirst = true, bool endWithDot = true}) {
    text = text.replaceAll(RegExp(r'<s>'), '');
    text = text.replaceAll(RegExp(r'\.{4,}'), '...');
    text = text.replaceAll(RegExp(r'\!+'), '!');
    text = text.replaceAll(RegExp(r'\?+'), '?');
    text = text.replaceAll(RegExp(r'''^([^\p{Letter}\p{Number}\("\*]|[\s|_])+''', unicode: true), '');
    text = text.replaceAll(RegExp(r'''([^\p{Letter}\p{Number}\.!\?\)"\*]|[\s|_])+$''', unicode: true), '');
    text = text.replaceAllMapped(RegExp(r'([!\?])\s*(\p{Letter})', caseSensitive: false, unicode: true), (m) => '${m[1]} ${m[2]?.toUpperCase()}');
    text = text.replaceAllMapped(RegExp(r'(?<!\.)(\.)\s*(\p{Letter})', caseSensitive: false, unicode: true), (m) => '${m[1]} ${m[2]?.toUpperCase()}');
    text = text.replaceAllMapped(RegExp(r'([\,\:\;])\s*(\p{Letter})', caseSensitive: false), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAllMapped(RegExp(r'([^\p{Number}][\.\!\?\,\:\;])\s*(\p{Number})'), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.trim();
    if(text.isEmpty)
      return text;

    if(upperFirst)
      text = text[0].toUpperCase() + text.substring(1);
    if(endWithDot && !text.endsWith('.') && !text.endsWith('!') && !text.endsWith('?') && !text.endsWith(')') && !text.endsWith('*'))
      text += '.';

    text = text.replaceAllMapped(RegExp(r'\b(can|won|don|haven|couldn|shouldn|wouldn|mustn|didn|aren|isn)(t)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|she|they|i|that|this)(ll)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|he|they|i|that)(d)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(he|she|that|what|where|who|she|he|let|there)(s)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|they)(re)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(would|should|you|could|must|we|i)(ve)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(m)(r|s|rs)\.?\b', caseSensitive: false), (m) => '${m[1]?.toUpperCase()}${m[2]}.');
    text = text.replaceAll(RegExp(r'\bim\b', caseSensitive: false), "I'm");
    text = text = text.replaceAll(RegExp(r'\bi\b'), 'I');
    return text;
  }

  static Message fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}

@JsonSerializable(explicitToJson: true)
@ColorJsonConverter()
class Participant {
  const Participant({
    required this.name,
    required this.color
  });

  @JsonKey(defaultValue: 'Participant')
  final String name;
  final Color color;

  static Participant fromJson(Map<String, dynamic> json) {
    if(!json.containsKey('color'))
      json['color'] = const ColorJsonConverter().toJson(Colors.grey);
    return _$ParticipantFromJson(json);
  }
  Map<String, dynamic> toJson() => _$ParticipantToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MessagesModel extends ChangeNotifier {
  static const String messageSeparator = '\n';
  static const String commentSeparator = '\n\n';
  static const String actionSeparator = '\n\n';
  static const String actionPrompt = '>';
  static const String sequenceEnd = '<|endoftext|>';
  static const List<String> sentenceStops = ['.', '!', '?'];

  @JsonKey(defaultValue: <Message>[])
  List<Message> messages = [];

  List<Participant> participants = [
    const Participant(name: 'You', color: Colors.blueGrey),
    const Participant(name: 'Bot', color: Colors.indigoAccent)
  ];

  Message? get lastNonComment => messages.lastWhereOrNull((m) => m.authorIndex != Message.commentIndex);
  int get lastParticipantIndex => lastNonComment?.authorIndex ?? Message.commentIndex;
  int get lastNonCommentParticipantIndex => lastNonComment?.authorIndex ?? getNextParticipantIndex(Message.youIndex);
  bool get lastIsYou => lastParticipantIndex == Message.youIndex;

  int get nextParticipantIndex {
    if(lastParticipantIndex == Message.commentIndex)
      return Message.youIndex;
    var nextIndex = lastParticipantIndex + 1;
    if(nextIndex < participants.length)
      return nextIndex;
    return Message.youIndex;
  }

  Participant get nextParticipant => participants[nextParticipantIndex];

  bool get nextIsYou => nextParticipantIndex == Message.youIndex;
  String get nextName => participants[nextParticipantIndex].name;
  bool get isLastGenerated => messages.lastOrNull?.isGenerated ?? false;
  Message? get generatedAtEnd => isLastGenerated ? messages.lastOrNull : null;

  String get chatText => getTextForChat(messages);

  String get adventureText => getTextForAdventure(messages);
  String get aiInputForAdventure => adventureText;
  String get repetitionPenaltyTextForAdventure => getRepetitionPenaltyTextForAdventure(messages);

  int getNextParticipantIndex(int index) {
    var nextIndex = index + 1;
    if (nextIndex < participants.length)
      return nextIndex;
    return Message.youIndex;
  }

  String getPromptForChat(Participant p) => '${p.name}:';

  String getTextForChat(List<Message> msgs) {
    var s = '';
    for(var m in msgs) {
      if(m.isComment) {
        if(s.isNotEmpty)
          s += commentSeparator;
        s += m.text;
        s += commentSeparator;
      } else {
        s += '${participants[m.authorIndex].name}: ${m.text}$messageSeparator';
      }
    }
    return s;
  }

  String getRepetitionPenaltyTextForChat(List<Message> msgs, int nLinesWithNoExtraPenaltySymbols) {
    var sepIndex = max(0, msgs.length - nLinesWithNoExtraPenaltySymbols);
    var partOne = msgs.slice(0, sepIndex);
    var partTwo = msgs.slice(sepIndex);

    var partOneStr = '';
    for(var m in partOne)
      partOneStr += '${m.text} ';
    partOneStr = partOneStr
      .replaceAll(RegExp(r'[^\p{Letter}\p{Number}\*\(\)\n]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

    var partTwoStr = '';
    for(var m in partTwo)
      partTwoStr += '${m.text} ';
    partTwoStr = partTwoStr
      .replaceAll(RegExp(r'[^\p{Letter}\p{Number}\n]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

    var result = '$partOneStr $partTwoStr'.trim();
    return result;
  }

  String getOriginalRepetitionPenaltyTextForChat(List<Message> msgs) {
    var text = '';
    for(var m in msgs)
      text += '${m.text}\n';
    return text;
  }

  String getAiInputForChat(List<Message> msgs, Participant? promptedParticipant) {
    var text = getTextForChat(msgs);
    var aiInput = text + getPromptForChat(promptedParticipant ?? nextParticipant);
    return aiInput;
  }

  String getTextForAdventure(List<Message> msgs) {
    var s = '';
    bool isPrevStory = false;
    for(var m in msgs) {
      if(m.isComment) {
        s += '$commentSeparator${m.text}$messageSeparator';
        isPrevStory = false;
      } else {
        if (m.isYou) {
          s += '$actionSeparator$actionPrompt ${m.text}';
          isPrevStory = false;
        } else {
          if(isPrevStory && m.text.isNotEmpty)
            s += ' ${m.text}';
          else
            s += '$messageSeparator${m.text}';
          isPrevStory = true;
        }
      }
    }
    if(!isPrevStory && s.isNotEmpty)
      s += messageSeparator;
    s = s.trimLeft();
    s = s.replaceAll(RegExp(r'[ ]+$'), ''); // trailing spaces make some models go crazy
    return s;
  }

  String getRepetitionPenaltyTextForAdventure(List<Message> msgs) {
    var text = getTextForAdventure(msgs);
    text = text
      .replaceAll(RegExp(r'[^\p{Letter}\p{Number}\*\(\)]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }

  List<Message> getMessagesSnapshot() {
    var copyList = <Message>[];
    copyList.addAll(messages);
    return copyList;
  }

  List<Message> getUsedMessages(
    String usedPrompt,
    Participant promptedParticipant,
    List<Message> inputMessages,
    String chatType
  ) {
    var startIndex = inputMessages.length - 1;
    var usedMessages = <Message>[];
    var testPromptLength = usedPrompt.trimLeft().length;

    while(startIndex >= 0) {
      var testMessages = inputMessages.sublist(startIndex);
      String testText;
      switch(chatType) {
        case Conversation.typeChat:
          testText = getAiInputForChat(testMessages, promptedParticipant);
          break;

        case Conversation.typeAdventure:
          testText = getTextForAdventure(testMessages);
          break;

        default:
          throw Exception('Invalid chat type: $chatType');
      }
      if(testText.length >= testPromptLength) {
        usedMessages.addAll(testMessages);
        return usedMessages;
      }
      startIndex--;
    }

    usedMessages.clear();
    usedMessages.addAll(inputMessages);
    return usedMessages;
  }

  void add(Message msg) {
    messages.add(msg);
    notifyListeners();
  }

  void setText(Message m, String newText) {
    var i = messages.indexOf(m);
    if(i < 0)
      return;

    m = Message(text: newText, authorIndex: m.authorIndex, isGenerated: false);
    messages[i] = m;
    notifyListeners();
  }

  Message addText(String text, bool isGenerated, int authorIndex) {
    var msg = Message(
      text: text,
      authorIndex: authorIndex,
      isGenerated: isGenerated
    );
    add(msg);
    return msg;
  }

  Message? remove(Message msg) {
    var isRemoved = messages.remove(msg);
    notifyListeners();
    return isRemoved ? msg : null;
  }

  Message? removeLast() {
    if(messages.isEmpty)
      return null;

    var msg = messages.removeLast();
    notifyListeners();
    return msg;
  }

  void clear() {
    messages.clear();
    notifyListeners();
  }

  void replace(int i, Message msg) {
    messages[i] = msg;
    notifyListeners();
  }

  void setAuthors(List<Participant> newAuthors) {
    participants = newAuthors;
    notifyListeners();
  }

  void setAuthorName(int authorIndex, String newName) {
    var a = participants[authorIndex];
    a = Participant(name: newName, color: a.color);
    participants[authorIndex] = a;
    notifyListeners();
  }

  void setAuthorColor(int authorIndex, Color newColor) {
    var a = participants[authorIndex];
    a = Participant(name: a.name, color: newColor);
    participants[authorIndex] = a;
    notifyListeners();
  }

  void load(MessagesModel other) {
    messages.clear();
    messages.addAll(other.messages);

    participants.clear();
    participants.addAll(other.participants);

    notifyListeners();
  }

  static MessagesModel fromJson(Map<String, dynamic> json) {
    var participants = (json['participants'] as List<dynamic>?) ?? <dynamic>[];
    while(participants.length < 2)
      participants.add(const Participant(name: 'Participant', color: Colors.grey).toJson());
    json['participants'] = participants;

    return _$MessagesModelFromJson(json);
  }
  Map<String, dynamic> toJson() => _$MessagesModelToJson(this);
}
