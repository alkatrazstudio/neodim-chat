// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:provider/provider.dart';

import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../util/wakelock.dart';
import '../widgets/chat_button.dart';
import '../widgets/chat_msg.dart';

class Chat extends StatefulWidget {
  const Chat({
    required this.generate
  });

  final Future<List<String>> Function(String, String?, Participant, Set<String>, bool continueLastMsg) generate;

  @override
  State<Chat> createState() => ChatState();
}

class GeneratedResult {
  const GeneratedResult({
    required this.text,
    this.preText = '',
    this.isError = false
  });

  static const GeneratedResult empty = GeneratedResult(text: '');

  bool get isEmpty => text.isEmpty && preText.isEmpty;

  static GeneratedResult fromRawOutput(String output, bool chatFormat) {
    var rx = RegExp(r'[.!?,:;\-)*"]+\s+');
    var match = rx.matchAsPrefix(output);
    if(match == null) {
      rx = RegExp(r'[.!?,:;\-)]*');
      match = rx.matchAsPrefix(output);
    }
    var preText = match?.group(0) ?? '';
    var text = output.substring(preText.length);
    return GeneratedResult(
      text: Message.format(text, chatFormat),
      preText: preText.trimRight()
    );
  }

  final String text;
  final String preText;
  final bool isError;
}

class ChatState extends State<Chat> {
  final inputController = TextEditingController();

  List<GeneratedResult> retryCache = [];
  String aiInputForRetryCache = '';
  Conversation? generatingForConv;
  Set<String> blacklistWordsForRetry = {};

  Future submit(BuildContext context, int authorIndex, bool format) async {
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    if(inputController.text.isEmpty)
      return;
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var curConv = convModel.current;
    if(curConv == null)
      return;
    var text = inputController.text.trim();
    var isYou = authorIndex == Message.youIndex;
    if(!isYou && curConv.type == Conversation.typeGroupChat) {
      var startsWithColon = text.startsWith(MessagesModel.chatPromptSeparator);
      var hasColon = text.contains(MessagesModel.chatPromptSeparator);
      if(
        (cfgModel.colonStartIsPreviousName && startsWithColon)
        ||
        (!cfgModel.colonStartIsPreviousName && !hasColon)
      ) {
        // use the previous participant name
        var messages = msgModel.messages;
        var msgIndex = messages.length - 1;
        while(msgIndex >= 0) {
          var msg = messages[msgIndex];
          if(!msg.isYou && msg.text.contains(MessagesModel.chatPromptSeparator)) {
            var participantName = MessagesModel.extractParticipantName(msg.text);
            if(startsWithColon)
              text = participantName + text;
            else
              text = '$participantName${MessagesModel.chatPromptSeparator} $text';
            break;
          }
          msgIndex--;
        }
      } else if (!cfgModel.colonStartIsPreviousName && startsWithColon) {
        // remove the colon to treat as comment
        // (does not work if the line has more than one comma)
        text = text.substring(1);
      }
    }
    if(format) {
      var chatFormat = curConv.isChat || authorIndex == Message.youIndex;
      if(!isYou && curConv.type == Conversation.typeGroupChat) {
        var match = RegExp(r'^\s*([^:]+):\s*(.*)$').firstMatch(text);
        if(match != null) {
          var participantName = (match.group(1) ?? '').trim();
          if(participantName.isNotEmpty)
            participantName = participantName.substring(0, 1).toUpperCase() +  participantName.substring(1);
          var textPart = match.group(2) ?? '';
          textPart = Message.format(textPart, chatFormat);
          text = '$participantName${MessagesModel.chatPromptSeparator} $textPart';
        } else {
          text = Message.format(text, chatFormat);
        }
      } else {
        text = Message.format(text, chatFormat);
      }
    }
    text = text.trim();
    msgModel.addText(text, false, authorIndex);
    inputController.clear();
    await ConversationsModel.saveCurrentData(context);
  }

  String getAiInput(
      Conversation c,
      MessagesModel msgModel,
      ConfigModel cfgModel,
      Participant nextParticipant,
      int nextParticipantIndex,
      bool continueLastMsg
  ) {
    var combineLines = c.type != Conversation.typeChat ? CombineChatLinesType.no : cfgModel.combineChatLines;
    switch(c.type) {
      case Conversation.typeChat:
        return msgModel.getAiInputForChat(msgModel.messages, nextParticipant, combineLines, false, continueLastMsg);

      case Conversation.typeGroupChat:
        var inputText = msgModel.getAiInputForChat(msgModel.messages, nextParticipant, combineLines, true, continueLastMsg);
        return inputText;

      case Conversation.typeAdventure:
        return msgModel.getAiInputForAdventure(msgModel.messages, nextParticipantIndex);

      case Conversation.typeStory:
        return msgModel.aiInputForStory;

      default:
        return '';
    }
  }

  String? getRepPenInput(Conversation c, MessagesModel msgModel, ConfigModel cfgModel) {
    switch(c.type) {
      case Conversation.typeChat:
        if(cfgModel.repetitionPenaltyKeepOriginalPrompt) {
          return msgModel.getOriginalRepetitionPenaltyTextForChat(
              msgModel.messages,
              false,
              cfgModel.repetitionPenaltyRemoveParticipantNames
          );
        } else {
          return msgModel.getRepetitionPenaltyTextForChat(
            msgModel.messages,
            cfgModel.repetitionPenaltyLinesWithNoExtraSymbols,
            false,
            cfgModel.repetitionPenaltyRemoveParticipantNames
          );
        }

      case Conversation.typeGroupChat:
        if(cfgModel.repetitionPenaltyKeepOriginalPrompt) {
          return msgModel.getOriginalRepetitionPenaltyTextForChat(
              msgModel.messages,
              true,
              cfgModel.repetitionPenaltyRemoveParticipantNames
          );
        } else {
          return msgModel.getRepetitionPenaltyTextForChat(
            msgModel.messages,
            cfgModel.repetitionPenaltyLinesWithNoExtraSymbols,
            true,
            cfgModel.repetitionPenaltyRemoveParticipantNames
          );
        }

      case Conversation.typeAdventure:
        if(cfgModel.repetitionPenaltyKeepOriginalPrompt)
          return null;
        return msgModel.repetitionPenaltyTextForAdventure;

      case Conversation.typeStory:
        if(cfgModel.repetitionPenaltyKeepOriginalPrompt)
          return null;
        return msgModel.repetitionPenaltyTextForStory;

      default:
        return null;
    }
  }

  Future<GeneratedResult> getGenerated(
    BuildContext context,
    int participantIndex, {
    Message? undoMessage,
    bool useBlacklist = true,
    bool continueLastMsg = false
  }) async {
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var curConv = convModel.current;
    if(curConv == null)
      return GeneratedResult.empty;
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);

    var promptedParticipant = msgModel.participants[participantIndex];
    var aiInput = getAiInput(curConv, msgModel, cfgModel, promptedParticipant, participantIndex, continueLastMsg);

    if(aiInput == aiInputForRetryCache && retryCache.isNotEmpty) {
      var result = retryCache.removeAt(0);
      return result;
    }
    if(aiInput != aiInputForRetryCache) {
      blacklistWordsForRetry = {};
    } else {
      if(useBlacklist)
        updateRetryBlacklist(context, undoMessage);
      else
        blacklistWordsForRetry = {};
    }

    var repPenInput = getRepPenInput(curConv, msgModel, cfgModel);

    aiInputForRetryCache = aiInput;
    retryCache.clear();

    var isChat = curConv.isChat;
    var chatFormat = (isChat || participantIndex == Message.youIndex) && (!continueLastMsg || participantIndex != msgModel.lastParticipantIndex);

    var nTries = isChat ? 3 : 1;
    List<GeneratedResult> results = [];
    while(true) {
      try {
        var texts = await widget.generate(aiInput, repPenInput, promptedParticipant, blacklistWordsForRetry, continueLastMsg);
        var isSingle = texts.length == 1;
        results = texts
          .map((text) => isSingle
            ? GeneratedResult.fromRawOutput(text, chatFormat)
            : GeneratedResult(text: Message.format(text, chatFormat))
          )
          .where((result) => !result.isEmpty)
          .toSet().toList();
        if(results.isNotEmpty || nTries <= 1)
          break;
        nTries--;
      } catch(e) {
        results = [GeneratedResult(
          text: e.toString().replaceAll('\n', ''),
          isError: true
        )];
        break;
      }
    }

    if(results.isEmpty)
      return GeneratedResult.empty;

    var result = results.removeAt(0);
    retryCache = results.where((result) => result.text.isNotEmpty).toList();
    return result;
  }

  void updateRetryBlacklist(BuildContext context, Message? undoMessage) {
    if(undoMessage == null) {
      blacklistWordsForRetry = {};
      return;
    }

    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var availableWordsToRemove = blacklistWordsForRetry.toSet();

    if(cfgModel.addWordsToBlacklistOnRetry != 0) {
      var curConv = Provider.of<ConversationsModel>(context, listen: false).current;
      if(curConv == null)
        return;

      var text = undoMessage.text;
      if(curConv.type == Conversation.typeGroupChat) {
        text = text.replaceFirst(RegExp(r'[^:]*:\s*'), '');
      }
      var rx =  RegExp(cfgModel.addSpecialSymbolsToBlacklist ? r'([^\w()*]|\b)+' : r'\W+');
      var words = text.split(rx).where((s) => s.isNotEmpty).toSet();
      var availableWordsToAdd = words.difference(blacklistWordsForRetry);

      for(var a=0; a<cfgModel.addWordsToBlacklistOnRetry; a++) {
        if(availableWordsToAdd.isEmpty)
          break;

        var wordIndex = Random().nextInt(availableWordsToAdd.length);
        var word = availableWordsToAdd.elementAt(wordIndex);
        availableWordsToAdd.remove(word);
        blacklistWordsForRetry.add(word);
      }
    }

    for(var a=0; a<cfgModel.removeWordsFromBlacklistOnRetry; a++) {
      if(availableWordsToRemove.isEmpty)
        break;

      var wordIndex = Random().nextInt(availableWordsToRemove.length);
      var word = availableWordsToRemove.elementAt(wordIndex);
      availableWordsToRemove.remove(word);
      blacklistWordsForRetry.remove(word);
    }
  }

  Future addGenerated(
    BuildContext context,
    int authorIndex, {
    Message? undoMessage,
    bool useBlacklist = true,
    bool continueLastMsg = false
  }) async {
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var curConv = Provider.of<ConversationsModel>(context, listen: false).current;
    if(curConv == null)
      return;

    var result = await getGenerated(
      context,
      authorIndex,
      undoMessage: undoMessage,
      useBlacklist: useBlacklist,
      continueLastMsg: continueLastMsg
    );
    if(result.isEmpty)
      return;

    var lastMsg = msgModel.messages.lastOrNull;
    if(
      !result.isError
      && lastMsg != null
      && result.preText.isNotEmpty
      && lastMsg.authorIndex == authorIndex
      && !curConv.isChat
    ) {
      msgModel.setText(lastMsg, lastMsg.text + result.preText, false);
    }

    if(result.text.isNotEmpty) {
      if(!result.isError && lastMsg != null && continueLastMsg && authorIndex == msgModel.lastParticipantIndex)
        msgModel.setText(lastMsg, '${lastMsg.text} ${result.text}', false);
      else
        msgModel.addText(result.text, true, authorIndex);
    }
    await ConversationsModel.saveCurrentData(context);

    if(generatingForConv != null && !result.isError)
      nextAutoGen();

    if(result.isError && generatingForConv != null && generatingForConv == curConv) {
      setState(() {
        disableAutoGen();
      });
    }
  }

  void enableAutoGen(Conversation conv) {
    generatingForConv = conv;
    Wakelock.set(true);
  }

  void disableAutoGen() {
    generatingForConv = null;
    Wakelock.set(false);
  }

  Future nextAutoGen() async {
    if(Provider.of<ApiModel>(context, listen: false).isApiRunning)
      return;
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var curConv = convModel.current;
    if(curConv != generatingForConv) {
      setState(() {
        disableAutoGen();
      });
      return;
    }
    if(curConv == null)
      return;
    if(curConv != generatingForConv)
      return;
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);

    var nextAuthorIndex = Message.storyIndex;
    switch(curConv.type)
    {
      case Conversation.typeChat:
      case Conversation.typeGroupChat:
        if(cfgModel.continuousChatForceAlternateParticipants) {
          nextAuthorIndex = msgModel.getNextParticipantIndex(null);
        } else {
          nextAuthorIndex = Random().nextInt(msgModel.participants.length);
          if(nextAuthorIndex == msgModel.lastParticipantIndex)
            nextAuthorIndex = Random().nextInt(msgModel.participants.length);
        }
        break;

      case Conversation.typeAdventure:
        nextAuthorIndex = msgModel.getNextParticipantIndex(null);
        if(nextAuthorIndex == Message.youIndex && Random().nextDouble() < 0.6)
          nextAuthorIndex = Message.dmIndex;
        break;

      case Conversation.typeStory:
        nextAuthorIndex = Message.storyIndex;
        break;

      default:
        return;
    }

    addGenerated(context, nextAuthorIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Consumer2<MessagesModel, ConversationsModel>(builder: (context, msgModel, convModel, child) {
            var curConv = convModel.current;
            if(curConv == null)
              return const SizedBox.shrink();
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 10),
              itemCount: msgModel.messages.length,
              reverse: true,
              itemBuilder: (ctx, i) {
                var msgIndex = msgModel.messages.length - i - 1;
                var msg = msgModel.messages[msgIndex];
                var isUsed = msgIndex >= convModel.notUsedMessagesCount;
                return ChatMsg(
                  msg: msg,
                  author: msgModel.participants[msg.authorIndex],
                  isUsed: isUsed,
                  conversation: curConv
                );
              }
            );
          })
        ),

        Consumer<ApiModel>(
          builder: (context, value, child) {
            if (value.isApiRunning)
              return const LinearProgressIndicator(minHeight: 3);
            return const SizedBox.shrink();
          }
        ),

        Consumer2<MessagesModel, ConversationsModel>(builder: (context, msgModel, convModel, child) {
          var curConv = convModel.current;
          if(curConv == null)
            return const SizedBox.shrink();

          return ChatInput(
            addGenerated: (authorIndex) => addGenerated(context, authorIndex),
            submit: (authorIndex) => submit(context, authorIndex, true),
            inputController: inputController,
            isGenerating: generatingForConv == curConv,
            onGeneratingSwitch: (newIsGenerating) {
              setState(() {
                if(newIsGenerating) {
                  enableAutoGen(curConv);
                  nextAutoGen();
                } else {
                  disableAutoGen();
                }
              });
            }
          );
        }),

        ChatButtons(
          addGenerated: (
            authorIndex, {
            Message? undoMessage,
            bool useBlacklist = true,
            bool continueLastMsg = false
          }) => addGenerated(
            context,
            authorIndex,
            undoMessage: undoMessage,
            useBlacklist: useBlacklist,
            continueLastMsg: continueLastMsg
          ),
          submit: (authorIndex, format) => submit(context, authorIndex, format),
          changeGroupParticipantName: (name) {
            var text = inputController.text;
            var sepPos = text.indexOf(MessagesModel.chatPromptSeparator);
            if(sepPos >= 0)
              text = text.substring(sepPos + 1);
            else
              text = ' $text';
            if(text.isEmpty)
              text += ' ';
            text = '$name${MessagesModel.chatPromptSeparator}$text';
            inputController.text = text;
          }
        ),

        Consumer<ApiModel>(builder: (context, neodimModel, child) {
          var gpus = neodimModel.lastResponse?.gpus;
          if(gpus == null)
            return const SizedBox.shrink();

          return Column(
            children: gpus.map((gpu) => LinearProgressIndicator(
              backgroundColor: Colors.grey,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 1,
              value: 1 - gpu.memoryFreeMin / gpu.memoryTotal
            )).toList()
          );
        })
      ]
    );
  }
}

class UndoItem {
  UndoItem({
    required this.message,
    this.text
  });

  final Message message;
  final String? text;
}

class ChatButtons extends StatefulWidget {
  const ChatButtons({
    required this.addGenerated,
    required this.submit,
    required this.changeGroupParticipantName
  });

  final Function(int authorIndex, {Message? undoMessage, bool useBlacklist, bool continueLastMsg}) addGenerated;
  final Function(int authorIndex, bool format) submit;
  final Function(String newName) changeGroupParticipantName;

  @override
  State<ChatButtons> createState() => _ChatButtonsState();
}

class _ChatButtonsState extends State<ChatButtons> {
  final List<UndoItem> undoQueue = [];
  Conversation? undoConversation;
  static const List<String> undoUntilChars = ['.', '!', '?', '*', ':', ')'];
  static const List<String> undoUntilOnChars = ['('];
  static const List<String> undoUntilOnCharsBeforeSpace = ['*', '"', "'"];

  @override
  Widget build(BuildContext context) {
    var convModel = Provider.of<ConversationsModel>(context);
    var curConv = convModel.current;
    if(curConv == null)
      return const SizedBox.shrink();
    var msgModel = Provider.of<MessagesModel>(context);
    var neodimModel = Provider.of<ApiModel>(context);
    var cfgModel = Provider.of<ConfigModel>(context);

    if(undoConversation != curConv)
      undoQueue.clear();

    List<List<Widget>> buttonRows;
    switch(curConv.type) {
      case Conversation.typeChat:
        buttonRows = chatButtons(context, msgModel, curConv, neodimModel, cfgModel, false);
        break;

      case Conversation.typeGroupChat:
        buttonRows = chatButtons(context, msgModel, curConv, neodimModel, cfgModel, true);
        break;

      case Conversation.typeAdventure:
        buttonRows = adventureButtons(context, msgModel, curConv, neodimModel, cfgModel);
        break;

      case Conversation.typeStory:
        buttonRows = storyButtons(context, msgModel, curConv, neodimModel, cfgModel);
        break;

      default:
        buttonRows = [];
    }

    return Column(
      children: buttonRows.map((row) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: row
      )).toList()
    );
  }

  Future<UndoItem?> undo(MessagesModel msgModel, ConfigModel cfgModel, Conversation curConv, bool undoBySentence) async {
    var lastMsg = msgModel.messages.lastOrNull;
    if(lastMsg == null)
      return null;

    late UndoItem undoItem;
    if(undoBySentence) {
      var pos = lastMsg.text.length - 1;
      var undoText = '';
      var canStop = false;
      while(pos >= 0) {
        var char = lastMsg.text[pos];
        var stopSymbolBeforeQuote =
          (char == '"' || char == "'")
            &&
          pos > 0
            &&
          (undoUntilChars.contains(lastMsg.text[pos - 1]));
        if(
          stopSymbolBeforeQuote
            ||
          (
            undoUntilChars.contains(char)
              &&
            (
              pos == 0
                ||
              lastMsg.text[pos - 1] != ' '
            )
          )
            ||
          (
            (pos < lastMsg.text.length - 1)
              &&
            undoUntilOnChars.contains(lastMsg.text[pos + 1])
          )
            ||
          (
            (pos < lastMsg.text.length - 1)
              &&
            undoUntilOnCharsBeforeSpace.contains(lastMsg.text[pos + 1])
              &&
            char == ' '
          )
        ) {
          // do not stop if the first symbol (from the end) is a stop symbol
          if(canStop) {
            while(pos >= 0) {
              if(lastMsg.text[pos] == ' ') {
                // remove all spaces from the right
                undoText = lastMsg.text[pos] + undoText;
                pos--;
              } else {
                break;
              }
            }
            break;
          }
        } else {
          canStop = true;
        }
        undoText = char + undoText;
        pos--;
      }

      if(pos <= 0) {
        undoBySentence = false;
      } else {
        undoItem = UndoItem(message: lastMsg, text: undoText);
        var newText = lastMsg.text.substring(0, lastMsg.text.length - undoText.length);
        msgModel.setText(lastMsg, newText, false);
      }
    }

    if(!undoBySentence) {
      var msg = msgModel.removeLast();
      if(msg == null)
        return null;
      undoItem = UndoItem(message: msg);
    }

    setState(() {
      undoConversation = curConv;
      undoQueue.add(undoItem);
    });

    await ConversationsModel.saveCurrentData(context);
    return undoItem;
  }

  Widget btnUndo(MessagesModel msgModel, ConfigModel cfgModel, Conversation curConv) {
    return ChatButton(
      onPressed: (isLong) async {
        var lastMsg = msgModel.messages.lastOrNull;
        if(lastMsg == null)
          return;
        var undoBySentence = !isLong && cfgModel.undoBySentence && lastMsg.text.isNotEmpty;
        await undo(msgModel, cfgModel, curConv, undoBySentence);
      },
      isEnabled: msgModel.messages.isNotEmpty,
      icon: Icons.undo
    );
  }

  Widget btnRedo(BuildContext context, MessagesModel msgModel) {
    return ChatButton(
      onPressed: (isLong) async {
        setState(() {
          var undoItem = undoQueue.removeLast();
          if(undoItem.text != null) {
            var lastMsg = msgModel.messages.lastOrNull;
            if(lastMsg != null) {
              if(lastMsg.authorIndex == undoItem.message.authorIndex)
                msgModel.setText(lastMsg, lastMsg.text + undoItem.text!, false);
              else
                msgModel.addText(undoItem.text!.trim(), undoItem.message.isGenerated, undoItem.message.authorIndex);
            }
          } else {
            msgModel.add(undoItem.message);
          }
        });
        await ConversationsModel.saveCurrentData(context);
      },
      isEnabled: undoQueue.isNotEmpty,
      icon: Icons.redo
    );
  }

  Widget btnRetry(MessagesModel msgModel, ConfigModel cfgModel, Conversation curConv, ApiModel neodimModel) {
    return ChatButton(
      onPressed: (isLong) async {
        var undoItem = await undo(msgModel, cfgModel, curConv, false);
        var msg = undoItem?.message;
        if(msg == null)
          return;
        widget.addGenerated(msg.authorIndex, undoMessage: msg, useBlacklist: !isLong);
      },
      isEnabled: !neodimModel.isApiRunning && msgModel.generatedAtEnd != null,
      icon: Icons.refresh
    );
  }

  Widget btnGenerate(bool isYou, ApiModel neodimModel) {
    return ChatButton(
      onPressed: (isLong) {
        widget.addGenerated(isYou ? Message.youIndex : Message.storyIndex, continueLastMsg: isLong);
      },
      isEnabled: !neodimModel.isApiRunning,
      icon: Icons.speaker_notes_outlined,
      flipIcon: isYou
    );
  }

  Widget btnAdd(bool isYou, ApiModel neodimModel) {
    return ChatButton(
      onPressed: (isLong) {
        widget.submit(isYou ? Message.youIndex : Message.storyIndex, !isLong);
      },
      isEnabled: !neodimModel.isApiRunning,
      icon: Icons.add_comment_outlined,
      flipIcon: !isYou
    );
  }

  Widget btnParticipants(MessagesModel msgModel) {
    return PopupMenuButton<String>(
      onSelected: (name) {
        widget.changeGroupParticipantName(name);
      },
      icon: const Icon(Icons.person),
      itemBuilder: (context) {
        // hide the keyboard, because otherwise the popup may be overlapped by it
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        var names = msgModel.getGroupParticipantNames(true);
        return names.map((name) => PopupMenuItem(
          value: name,
          child: ListTile(
            title: Text(name)
          )
        )).toList();
      }
    );
  }

  List<List<Widget>> chatButtons(
      BuildContext context,
      MessagesModel msgModel,
      Conversation curConv,
      ApiModel neodimModel,
      ConfigModel cfgModel,
      bool groupChat
    ) {
    return [[
      if(groupChat) btnParticipants(msgModel),
      btnUndo(msgModel, cfgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(msgModel, cfgModel, curConv, neodimModel)
    ], [
      btnGenerate(false, neodimModel),
      btnGenerate(true, neodimModel),
      btnAdd(false, neodimModel),
      btnAdd(true, neodimModel)
    ]];
  }

  List<List<Widget>> adventureButtons(
    BuildContext context,
    MessagesModel msgModel,
    Conversation curConv,
    ApiModel neodimModel,
    ConfigModel cfgModel
  ) {
    return [[
      btnUndo(msgModel, cfgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(msgModel, cfgModel, curConv, neodimModel)
    ], [
      btnGenerate(false, neodimModel),
      btnAdd(false, neodimModel),
      btnAdd(true, neodimModel)
    ]];
  }

  List<List<Widget>> storyButtons(
    BuildContext context,
    MessagesModel msgModel,
    Conversation curConv,
    ApiModel neodimModel,
    ConfigModel cfgModel
  ) {
    return [[
      btnGenerate(false, neodimModel),
      btnUndo(msgModel, cfgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(msgModel, cfgModel, curConv, neodimModel)
    ]];
  }
}

class ChatInput extends StatelessWidget {
  ChatInput({
    required this.addGenerated,
    required this.submit,
    required this.inputController,
    required this.isGenerating,
    required this.onGeneratingSwitch
  });

  final Function(int authorIndex) addGenerated;
  final Function(int authorIndex) submit;
  final bool isGenerating;
  final Function(bool isGenerating) onGeneratingSwitch;
  final TextEditingController inputController;

  @override
  Widget build(BuildContext context) {
    var neodimModel = Provider.of<ApiModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var msgModel = Provider.of<MessagesModel>(context, listen: false);

    var nextParticipantIndex = Message.noneIndex;

    switch(convModel.current?.type) {
      case Conversation.typeChat:
      case Conversation.typeGroupChat:
        nextParticipantIndex = msgModel.getNextParticipantIndex(null);
        break;

      case Conversation.typeAdventure:
        nextParticipantIndex = Message.youIndex;
        break;

      case Conversation.typeStory:
        nextParticipantIndex = Message.storyIndex;
        break;

      default:
        return const SizedBox.shrink();
    }

    var nextParticipant = msgModel.participants[nextParticipantIndex];

    return TextField(
      controller: inputController,
      onSubmitted: (text) {
        if(neodimModel.isApiRunning)
          return;

        inputController.text = inputController.text.trim();
        var wasEmpty = inputController.text.isEmpty;
        submit(nextParticipantIndex);

        switch(convModel.current?.type) {
          case Conversation.typeChat:
          case Conversation.typeGroupChat:
            var genParticipantIndex = msgModel.getNextParticipantIndex(null);
            addGenerated(genParticipantIndex);
            break;

          case Conversation.typeAdventure:
            addGenerated(Message.dmIndex);
            break;

          case Conversation.typeStory:
            if(wasEmpty)
              addGenerated(Message.storyIndex);
            break;
        }
      },
      decoration: InputDecoration(
        hintText: nextParticipant.name,
        suffixIcon: GestureDetector(
          onLongPress: () {
            Feedback.forLongPress(context);
            onGeneratingSwitch(!isGenerating);
          },
          child:IconButton(
            icon: Icon(isGenerating ? Icons.fast_forward : Icons.send),
            onPressed: () {
              if(isGenerating) {
                onGeneratingSwitch(false);
                return;
              }

              if(neodimModel.isApiRunning)
                return;

              inputController.text = inputController.text.trim();
              var wasEmpty = inputController.text.isEmpty;
              submit(nextParticipantIndex);

              switch(convModel.current?.type) {
                case Conversation.typeChat:
                case Conversation.typeGroupChat:
                  var genParticipantIndex = msgModel.getNextParticipantIndex(null);
                  addGenerated(genParticipantIndex);
                  break;

                case Conversation.typeAdventure:
                  addGenerated(Message.dmIndex);
                  break;

                case Conversation.typeStory:
                  if(wasEmpty)
                    addGenerated(Message.storyIndex);
                break;
              }
            }
          )
        ),
        contentPadding: const EdgeInsets.only(left: 5, top: 15)
      ),
      maxLines: 5,
      minLines: 1,
      textInputAction: TextInputAction.send
    );
  }
}
