// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

import '../models/config.dart';
import '../models/conversations.dart';
import '../util/json_converters.dart';

part 'messages.g.dart';

@JsonSerializable(explicitToJson: true)
class Message {
  Message({
    required this.text,
    required this.authorIndex,
    required this.isGenerated
  });

  static const int noneIndex = -1;
  static const int youIndex = 0;
  static const int dmIndex = 1;
  static const int storyIndex = dmIndex;
  static const int groupChatIndex = dmIndex;

  bool get isYou => authorIndex == youIndex;

  @JsonKey(defaultValue: '')
  final String text;

  @JsonKey(defaultValue: 0)
  final int authorIndex;

  @JsonKey(defaultValue: false)
  final bool isGenerated;

  static String format(String text, {bool forChat = true, bool continueLastMsg = false, bool addPeriodAtEnd = true}) {
    text = text.replaceAll('<s>', '');
    text = text.replaceAll('</s>', '');
    text = text.replaceAll('<pad>', '');
    text = text.replaceAll('<mask>', '');
    text = text.replaceAll('<unk>', '');
    text = text.replaceAll('<|endoftext|>', '');

    text = text.replaceAll(RegExp(r'\.{4,}'), '...');
    text = text.replaceAll(RegExp(r'!+'), '!');
    text = text.replaceAll(RegExp(r'\?+'), '?');
    if(!continueLastMsg)
      text = text.replaceAll(RegExp(r'''^([^\p{Letter}\p{Number}\("\*])+''', unicode: true), '');
    else
      forChat = false;
    if(forChat && addPeriodAtEnd)
      text = text.replaceAll(RegExp(r'''([^\p{Letter}\p{Number}\.!\?\)"\*]|[\s|_])+$''', unicode: true), '');
    text = text.replaceAllMapped(RegExp(r'\b(dr|gen|hon|mr|mrs|ms|messrs|mmes|msgr|prof|rev|rt|sr|st|v)\b(\.)?', caseSensitive: false), (m) => '${m[1]?.substring(0, 1).toUpperCase()}${m[1]?.substring(1)}${m[2] ?? '.'}');
    text = text.replaceAllMapped(RegExp(r'([!?])\s*(\p{Letter})', unicode: true), (m) => '${m[1]} ${m[2]?.toUpperCase()}');
    text = text.replaceAllMapped(RegExp(r'(?<!\.)(\.)\s*(\p{Letter})', unicode: true), (m) => '${m[1]} ${m[2]?.toUpperCase()}');
    text = text.replaceAllMapped(RegExp(r'([.,:;])\s*(\p{Letter})', unicode: true), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAllMapped(RegExp(r'([^\p{Number}][.!?,:;])\s*(\p{Number})', unicode: true), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = continueLastMsg ? text.trimRight() : text.trim();
    if(text.isEmpty)
      return text;

    if(forChat)
      text = text[0].toUpperCase() + text.substring(1);
    if(
      forChat
      && addPeriodAtEnd
      && !text.endsWith('.')
      && !text.endsWith('!')
      && !text.endsWith('?')
      && !text.endsWith(')')
      && !text.endsWith('*')
      && !(text.startsWith('"') && text.endsWith('"') && '"'.allMatches(text).toList().length == 2)
    ) {
      text += '.';
    }

    text = text.replaceAllMapped(RegExp(r'\b(can|won|don|doesn|haven|hasn|couldn|shouldn|wouldn|mustn|didn|aren|isn|wasn|weren)(t)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|they|that|this)(ll)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|he|they|i|that|who)(d)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(he|she|that|what|where|who|there)(s)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|they)(re)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(would|should|you|could|must|we|i)(ve)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(esq|jr)(\.)?\b', caseSensitive: false), (m) => '${m[1]?.substring(0, 1).toUpperCase()}${m[1]?.substring(1)}${m[2] ?? '.'}');
    text = text.replaceAll(RegExp(r'\bim\b', caseSensitive: false), "I'm");
    text = text = text.replaceAll(RegExp(r'\bi\b'), 'I');
    return text;
  }

  Message withText(String newText, [bool unsetGenerated = false]) {
    var newMsg = Message(text: newText, authorIndex: authorIndex, isGenerated: !unsetGenerated && isGenerated);
    return newMsg;
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
  static const String actionSeparator = '\n\n';
  static const String actionPrompt = '>';
  static const String chatPromptSeparator = ':';
  static const List<String> sentenceStops = ['.', '!', '?'];
  static const String sentenceStopsRx = r'(?i)(?<!\W(dr|esq|gen|hon|jr|mr|mrs|ms|messrs|mmes|msgr|prof|rev|rt|sr|st|v))[\.\!\?\"](?=\s)';

  @JsonKey(defaultValue: <Message>[])
  List<Message> messages = [];

  @JsonKey(defaultValue: 0)
  int contextStartIndex = 0;

  List<Participant> participants = [
    const Participant(name: 'You', color: Colors.blueGrey),
    const Participant(name: 'Bot', color: Colors.indigoAccent)
  ];

  int get lastParticipantIndex => messages.lastOrNull?.authorIndex ?? Message.noneIndex;
  bool get lastIsYou => lastParticipantIndex == Message.youIndex;

  bool get isLastGenerated => messages.lastOrNull?.isGenerated ?? false;
  Message? get generatedAtEnd => isLastGenerated ? messages.lastOrNull : null;

  String get chatText => getTextForChat(contextMessages, CombineChatLinesType.no, false, false);
  String get groupChatText => getTextForChat(contextMessages, CombineChatLinesType.no, true, false);
  String get adventureText => getTextForAdventure(contextMessages);
  String get storyText => getTextForStory(contextMessages);
  String get aiInputForStory => storyText;
  String get repetitionPenaltyTextForAdventure => getRepetitionPenaltyTextForAdventure();
  String get repetitionPenaltyTextForStory => getRepetitionPenaltyTextForStory();

  int get nextParticipantIndex {
    var nextIndex = lastParticipantIndex + 1;
    if (nextIndex < participants.length)
      return nextIndex;
    return Message.youIndex;
  }

  List<Message> get contextMessages => messages.sublist(min(contextStartIndex, messages.length));

  String getPromptForChat(Participant p) => '${p.name}$chatPromptSeparator';

  String getTextForChat(List<Message> msgs, CombineChatLinesType combineLines, bool groupChat, bool continueLastMsg) {
    var s = '';
    bool isPrevComment = false; // the previous line was a "comment" (a group chat line without a participant)
    var curParticipantIndex = Message.noneIndex;
    for(var m in msgs) {
      var isComment = !m.isYou && groupChat && !m.text.contains(chatPromptSeparator);
      if(isComment) {
        if(s != '') {
           if(isPrevComment) {
             s += ' '; // the previous line was also a comment, concatenate it with space
           } else {
             s += messageSeparator; // the previous line was not a comment, separate it with the extra newline
             if(combineLines != CombineChatLinesType.no)
               s += messageSeparator; // the previous line was not a comment, separate it with the extra newline
           }
        }
        s += m.text; // add comment text
      } else {
        if(isPrevComment)
          s += messageSeparator + messageSeparator; // separate comments from chat lines
        if(combineLines != CombineChatLinesType.no) {
          if(m.authorIndex != curParticipantIndex) {
            if(s != '')
              s += messageSeparator; // this is a different participant, put it on new line
            if(!groupChat || m.isYou) {
              // add participant name
              s += '${participants[m.authorIndex].name}$chatPromptSeparator ${m.text}';
            } else {
              // do not add participant name because it is already contained in the message text
              s += m.text;
            }
            curParticipantIndex = m.authorIndex;
          } else {
            // this line is from the same participant and we need concatenate lines
            s += ' ${m.text}';
          }
        } else {
          if(!groupChat || m.isYou) {
            // add a participant name
            s += '${participants[m.authorIndex].name}$chatPromptSeparator ${m.text}$messageSeparator';
          } else {
            // do not add participant name because it is already contained in the message text
            s += '${m.text}$messageSeparator';
          }
        }
      }
      isPrevComment = isComment;
    }
    if(!continueLastMsg && combineLines != CombineChatLinesType.onlyForServer && s.isNotEmpty) {
      if(!s.endsWith(messageSeparator))
        s += messageSeparator;
      if(isPrevComment)
        s += messageSeparator;
    } else if(continueLastMsg && s.endsWith(messageSeparator)) {
      s = s.substring(0, s.length - messageSeparator.length);
    }
    return s;
  }

  String getRepetitionPenaltyTextForChat(
    List<Message> msgs,
    int nLinesWithNoExtraPenaltySymbols,
    bool hasGroupParticipantNamePrefixes,
    bool removeParticipantNames
  ) {
    var participantNames = <String>[];
    var sepIndex = max(0, msgs.length - nLinesWithNoExtraPenaltySymbols);
    var partOne = msgs.slice(0, sepIndex);
    var partTwo = msgs.slice(sepIndex);

    var partOneStr = '';
    String participantName;
    for(var m in partOne) {
      if(hasGroupParticipantNamePrefixes) {
        if(!m.isYou) {
          partOneStr += '${removeParticipantName(m.text)} ';
          participantName = extractParticipantName(m.text);
        } else {
          partOneStr += '${m.text} ';
          participantName = participants[m.authorIndex].name;
        }
      } else {
        partOneStr += '${m.text} ';
        participantName = participants[m.authorIndex].name;
      }
      if(removeParticipantNames && participantName.isNotEmpty && !participantNames.contains(participantName))
        participantNames.add(participantName);
    }
    partOneStr = partOneStr
      .replaceAll(RegExp(r'[^\p{Letter}\p{Number}*()\n]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

    var partTwoStr = '';
    for(var m in partTwo){
      if(hasGroupParticipantNamePrefixes) {
        if(!m.isYou) {
          partTwoStr += '${removeParticipantName(m.text)} ';
          participantName = extractParticipantName(m.text);
        } else {
          partTwoStr += '${m.text} ';
          participantName = participants[m.authorIndex].name;
        }
      } else {
        partTwoStr += '${m.text} ';
        participantName = participants[m.authorIndex].name;
      }
      if(removeParticipantNames && participantName.isNotEmpty && !participantNames.contains(participantName))
        participantNames.add(participantName);
    }
    partTwoStr = partTwoStr
      .replaceAll(RegExp(r'[^\p{Letter}\p{Number}\n]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

    var result = '$partOneStr $partTwoStr'.trim();
    for(var participantName in participantNames) {
      var rx = RegExp.escape(participantName);
      result = result.replaceAll(rx, '');
    }
    return result;
  }

  static String removeParticipantName(String s) {
    var text = s.replaceFirst(RegExp(r'^\s*[^:]+:\s*'), '');
    return text;
  }

  static String extractParticipantName(String s) {
    var sepPos = s.indexOf(MessagesModel.chatPromptSeparator);
    if(sepPos == -1)
      return '';
    var name = s.substring(0, sepPos).trim();
    return name;
  }

  String getOriginalRepetitionPenaltyTextForChat(
    List<Message> msgs,
    bool hasGroupParticipantNamePrefixes,
    bool removeParticipantNames
  ) {
    var participantNames = <String>[];
    var text = '';
    for(var m in msgs) {
      String participantName;
      if(hasGroupParticipantNamePrefixes) {
        if(!m.isYou) {
          participantName = extractParticipantName(m.text);
          text += '${removeParticipantName(m.text)}\n';
        } else {
          text += '${m.text}\n';
          participantName = participants[m.authorIndex].name;
        }
      } else {
        text += '${m.text}\n';
        participantName = participants[m.authorIndex].name;
      }
      if(removeParticipantNames && participantName.isNotEmpty && !participantNames.contains(participantName))
        participantNames.add(participantName);
    }
    for(var participantName in participantNames) {
      var rx = RegExp.escape(participantName);
      text = text.replaceAll(rx, '');
    }
    return text;
  }

  String getAiInputForChat(
    Participant promptedParticipant,
    CombineChatLinesType combineLines,
    bool groupChat,
    bool continueLastMsg
  ) {
    var text = getTextForChat(contextMessages, combineLines, groupChat, continueLastMsg);
    var aiInput = text;
    var participantIndex = participants.indexOf(promptedParticipant);
    if(combineLines != CombineChatLinesType.onlyForServer && !continueLastMsg) {
      if(participantIndex == Message.youIndex || !groupChat)
        aiInput += getPromptForChat(promptedParticipant);
    }
    return aiInput;
  }

  String getAiInputForAdventure(int participantIndex) {
     var text = getTextForAdventure(contextMessages);
     if(participantIndex == Message.youIndex)
       text = text + actionSeparator + actionPrompt;
     return text;
  }

  String getTextForAdventure(List<Message> msgs) {
    var s = '';
    var isPrevStory = false;
    var isPrevEmpty = false;
    for(var m in msgs) {
      if(m.isYou) {
        s += '$actionSeparator$actionPrompt ${m.text}';
        isPrevStory = false;
      } else {
        if(isPrevStory && m.text.isNotEmpty) {
          if(!isPrevEmpty)
            s += ' ';
          s += m.text;
        } else {
          s += '$messageSeparator${m.text}';
        }
        isPrevEmpty = m.text.isEmpty;
        isPrevStory = true;
      }
    }
    if(!isPrevStory && s.isNotEmpty)
      s += messageSeparator;
    s = s.trimLeft();
    s = s.replaceAll(RegExp(r' +$'), ''); // trailing spaces make some models go crazy
    return s;
  }

  String getTextForStory(List<Message> msgs) {
    var s = '';
    var isPrevEmpty = false;
    for(var m in msgs) {
      if(m.text.isNotEmpty) {
        if(!isPrevEmpty)
          s += ' ';
        s += m.text;
      } else {
        s += '$messageSeparator${m.text}';
      }
      isPrevEmpty = m.text.isEmpty;
    }
    s = s.trimLeft();
    s = s.replaceAll(RegExp(r' +$'), ''); // trailing spaces make some models go crazy
    return s;
  }

  String getRepetitionPenaltyTextForAdventure() {
    var text = getTextForAdventure(messages);
    text = text
      .replaceAll(RegExp(r'[^\p{Letter}\p{Number}]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  String getRepetitionPenaltyTextForStory() {
    return getRepetitionPenaltyTextForAdventure();
  }

  void add(Message msg) {
    messages.add(msg);
    notifyListeners();
  }

  Message setText(Message m, String newText, bool unsetGenerated) {
    var i = messages.indexOf(m);
    if(i < 0)
      return m;

    m = m.withText(newText, unsetGenerated);
    messages[i] = m;
    notifyListeners();
    return m;
  }

  void setTextAndAuthorIndex(Message m, String newText, int newAuthorIndex, bool unsetGenerated) {
    var i = messages.indexOf(m);
    if(i < 0)
      return;

    m = Message(text: newText, authorIndex: newAuthorIndex, isGenerated: !unsetGenerated && m.isGenerated);
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

  List<Message> removeToLast(Message msg) {
    var msgIndex = messages.indexOf(msg);
    if(msgIndex < 0)
      return [];
    var removedMessages = messages.sublist(msgIndex);
    messages.removeRange(msgIndex, messages.length);
    notifyListeners();
    return removedMessages;
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

  void setContextStart(Message msg) {
    var msgIndex = messages.indexOf(msg);
    if(msgIndex < 0)
      return;
    contextStartIndex = msgIndex;
    notifyListeners();
  }

  bool isContextStart(Message msg) {
    var msgIndex = messages.indexOf(msg);
    if(msgIndex < 0)
      return false;
    return msgIndex == contextStartIndex;
  }

  void load(MessagesModel other) {
    messages.clear();
    messages.addAll(other.messages);

    participants.clear();
    participants.addAll(other.participants);

    contextStartIndex = other.contextStartIndex;

    notifyListeners();
  }

  void setAllMessages(List<Message> newMessages) {
    messages.clear();
    messages.addAll(newMessages);
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }

  List<String> getGroupParticipantNames(bool gatherAll) {
    var names = participants[Message.groupChatIndex].name.split(',');
    names = names.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if(!gatherAll)
      return names;

    for(var msg in messages) {
      if(msg.isYou)
        continue;
      var newName = extractParticipantName(msg.text);
      if(newName.isEmpty)
        continue;
      if(names.firstWhereOrNull((name) => name == newName) != null)
        continue;
      names.add(newName);
    }

    return names;
  }

  String getAiInput(
    Conversation c,
    ConfigModel cfgModel,
    Participant nextParticipant,
    int nextParticipantIndex,
    bool continueLastMsg
  ) {
    var combineLines = c.type != ConversationType.chat ? CombineChatLinesType.no : cfgModel.combineChatLines;
    switch(c.type) {
      case ConversationType.chat:
        return getAiInputForChat(nextParticipant, combineLines, false, continueLastMsg);

      case ConversationType.groupChat:
        var inputText = getAiInputForChat(nextParticipant, combineLines, true, continueLastMsg);
        return inputText;

      case ConversationType.adventure:
        return getAiInputForAdventure(nextParticipantIndex);

      case ConversationType.story:
        return aiInputForStory;
    }
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

class StreamMessageModel extends ChangeNotifier {
  StreamMessageModel(): super();

  int authorIndex = Message.youIndex;
  String text = '';

  Message get message => Message(
    text: text.replaceAll('\n', ' ').trim(),
    authorIndex: authorIndex,
    isGenerated: true
  );

  void reset(int authorIndex) {
    this.authorIndex = authorIndex;
    text = '';
    notifyListeners();
  }

  void addText(String newText) {
    text += newText;
    notifyListeners();
  }

  void hide() {
    text = '';
    notifyListeners();
  }
}
