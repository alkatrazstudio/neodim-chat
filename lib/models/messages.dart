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

  static const int noneIndex = -1;
  static const int youIndex = 0;
  static const int dmIndex = 1;
  static const int storyIndex = dmIndex;
  static const int chatGroupIndex = dmIndex;

  bool get isYou => authorIndex == youIndex;

  @JsonKey(defaultValue: '')
  final String text;

  @JsonKey(defaultValue: 0)
  final int authorIndex;

  @JsonKey(defaultValue: false)
  final bool isGenerated;

  static String format(String text, bool forChat) {
    text = text.replaceAll('<s>', '');
    text = text.replaceAll('</s>', '');
    text = text.replaceAll('<pad>', '');
    text = text.replaceAll('<mask>', '');
    text = text.replaceAll('<unk>', '');
    text = text.replaceAll('<|endoftext|>', '');

    text = text.replaceAll(RegExp(r'\.{4,}'), '...');
    text = text.replaceAll(RegExp(r'!+'), '!');
    text = text.replaceAll(RegExp(r'\?+'), '?');
    text = text.replaceAll(RegExp(r'''^([^\p{Letter}\p{Number}\("\*]|[\s|_])+''', unicode: true), '');
    if(forChat)
      text = text.replaceAll(RegExp(r'''([^\p{Letter}\p{Number}\.!\?\)"\*]|[\s|_])+$''', unicode: true), '');
    text = text.replaceAllMapped(RegExp(r'\b(dr|gen|hon|mr|mrs|ms|messrs|mmes|msgr|prof|rev|rt|sr|st|v)\b(\.)?', caseSensitive: false), (m) => '${m[1]?.substring(0, 1).toUpperCase()}${m[1]?.substring(1)}${m[2] ?? '.'}');
    text = text.replaceAllMapped(RegExp(r'([!?])\s*(\p{Letter})', unicode: true), (m) => '${m[1]} ${m[2]?.toUpperCase()}');
    text = text.replaceAllMapped(RegExp(r'(?<!\.)(\.)\s*(\p{Letter})', unicode: true), (m) => '${m[1]} ${m[2]?.toUpperCase()}');
    text = text.replaceAllMapped(RegExp(r'([.,:;])\s*(\p{Letter})', unicode: true), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAllMapped(RegExp(r'([^\p{Number}][.!?,:;])\s*(\p{Number})', unicode: true), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.trim();
    if(text.isEmpty)
      return text;

    if(forChat)
      text = text[0].toUpperCase() + text.substring(1);
    if(forChat && !text.endsWith('.') && !text.endsWith('!') && !text.endsWith('?') && !text.endsWith(')') && !text.endsWith('*'))
      text += '.';

    text = text.replaceAllMapped(RegExp(r'\b(can|won|don|doesn|haven|couldn|shouldn|wouldn|mustn|didn|aren|isn|wasn)(t)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|she|they|that|this)(ll)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|he|they|i|that)(d)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(he|she|that|what|where|who|there)(s)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(you|they)(re)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(would|should|you|could|must|we|i)(ve)\b', caseSensitive: false), (m) => "${m[1]}'${m[2]}");
    text = text.replaceAllMapped(RegExp(r'\b(esq|jr)(\.)?\b', caseSensitive: false), (m) => '${m[1]?.substring(0, 1).toUpperCase()}${m[1]?.substring(1)}${m[2] ?? '.'}');
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
  static const String actionSeparator = '\n\n';
  static const String actionPrompt = '>';
  static const String chatPromptSeparator = ':';
  static const List<String> sentenceStops = ['.', '!', '?'];
  static const String sentenceStopsRx = r'(?i)(?<!\W(dr|esq|gen|hon|jr|mr|mrs|ms|messrs|mmes|msgr|prof|rev|rt|sr|st|v))[\.\!\?\"](?=\s)';

  @JsonKey(defaultValue: <Message>[])
  List<Message> messages = [];

  List<Participant> participants = [
    const Participant(name: 'You', color: Colors.blueGrey),
    const Participant(name: 'Bot', color: Colors.indigoAccent)
  ];

  int get lastParticipantIndex => messages.lastOrNull?.authorIndex ?? Message.noneIndex;
  bool get lastIsYou => lastParticipantIndex == Message.youIndex;

  bool get isLastGenerated => messages.lastOrNull?.isGenerated ?? false;
  Message? get generatedAtEnd => isLastGenerated ? messages.lastOrNull : null;

  String get chatText => getTextForChat(messages, false, false);
  String get groupChatText => getTextForChat(messages, false, true);
  String get adventureText => getTextForAdventure(messages);
  String get storyText => getTextForStory(messages);
  String get aiInputForStory => storyText;
  String get repetitionPenaltyTextForAdventure => getRepetitionPenaltyTextForAdventure(messages);
  String get repetitionPenaltyTextForStory => getRepetitionPenaltyTextForStory(messages);

  int getNextParticipantIndex(int? index) {
    index ??= lastParticipantIndex;
    var nextIndex = index + 1;
    if (nextIndex < participants.length)
      return nextIndex;
    return Message.youIndex;
  }

  String getPromptForChat(Participant p) => '${p.name}$chatPromptSeparator';

  String getTextForChat(List<Message> msgs, bool combineLines, bool groupChat) {
    var s = '';
    if(combineLines) {
      var curParticipantIndex = Message.noneIndex;
      for(var m in msgs) {
        if(m.authorIndex != curParticipantIndex) {
          if(s != '')
            s += messageSeparator;
          if(!groupChat || m.isYou)
            s += '${participants[m.authorIndex].name}$chatPromptSeparator ${m.text}';
          else
            s += m.text;
          curParticipantIndex = m.authorIndex;
        } else {
          s += ' ${m.text}';
        }
      }
    } else {
      for(var m in msgs) {
        if(!groupChat || m.isYou)
          s += '${participants[m.authorIndex].name}$chatPromptSeparator ${m.text}$messageSeparator';
        else
          s += '${m.text}$messageSeparator';
      }
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
    var name = RegExp(r'^\s*[^:]+').stringMatch(s) ?? '';
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
    List<Message> msgs,
    Participant promptedParticipant,
    bool combineLines,
    bool groupChat
  ) {
    var text = getTextForChat(msgs, combineLines, groupChat);
    var aiInput = text;
    var participantIndex = participants.indexOf(promptedParticipant);
    if(combineLines) {
      if(participantIndex == lastParticipantIndex) {
        aiInput += ' ';
      } else {
        aiInput += '\n';
        if(participantIndex == Message.youIndex || !groupChat)
          aiInput += getPromptForChat(promptedParticipant);
      }
    } else {
      if(participantIndex == Message.youIndex || !groupChat)
        aiInput += getPromptForChat(promptedParticipant);
    }
    return aiInput;
  }

  String getAiInputForAdventure(List<Message> msgs, int participantIndex) {
     var text = getTextForAdventure(msgs);
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

  String getRepetitionPenaltyTextForAdventure(List<Message> msgs) {
    var text = getTextForAdventure(msgs);
    text = text
      .replaceAll(RegExp(r'[^\p{Letter}\p{Number}]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }

  String getRepetitionPenaltyTextForStory(List<Message> msgs) {
    return getRepetitionPenaltyTextForAdventure(msgs);
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
    String chatType,
    bool combineLines,
    String addedPromptSuffix
  ) {
    var startIndex = inputMessages.length - 1;
    var usedMessages = <Message>[];
    var testPromptLength = usedPrompt.trimLeft().length;

    while(startIndex >= 0) {
      var testMessages = inputMessages.sublist(startIndex);
      String testText;
      switch(chatType) {
        case Conversation.typeChat:
          testText = getAiInputForChat(testMessages, promptedParticipant, combineLines, false);
          break;

        case Conversation.typeAdventure:
          testText = getTextForAdventure(testMessages);
          break;

        case Conversation.typeStory:
          testText = getTextForStory(testMessages);
          break;

        case Conversation.typeGroupChat:
          testText = getAiInputForChat(testMessages, promptedParticipant, combineLines, true);
          break;

        default:
          throw Exception('Invalid chat type: $chatType');
      }
      testText += addedPromptSuffix;
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

  void setText(Message m, String newText, bool unsetGenerated) {
    var i = messages.indexOf(m);
    if(i < 0)
      return;

    m = Message(text: newText, authorIndex: m.authorIndex, isGenerated: !unsetGenerated && m.isGenerated);
    messages[i] = m;
    notifyListeners();
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
