// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../widgets/chat_button.dart';
import '../widgets/chat_msg.dart';

class Chat extends StatefulWidget {
  const Chat({
    required this.generate
  });

  final Future<List<String>> Function(
    String aiInput,
    String? repPenInput,
    Participant promptedParticipant,
    String? promptedParticipantName,
    Set<String> blacklistWordsForRetry,
    bool continueLastMsg,
    Message? undoMessage
  ) generate;

  @override
  State<Chat> createState() => ChatState();
}

enum GeneratedResultType {
  response,
  error,
  cancel
}

class GeneratedResult {
  const GeneratedResult({
    required this.text,
    this.preText = '',
    this.type = GeneratedResultType.response
  });

  static const GeneratedResult empty = GeneratedResult(text: '');

  bool get isEmpty => text.isEmpty && preText.isEmpty;

  static GeneratedResult fromRawOutput(String output, bool chatFormat, bool extractPreText, bool continueLastMsg) {
    if(!extractPreText)
      return GeneratedResult(text: Message.format(output, chatFormat, continueLastMsg));

    // If the output does not start with a space,
    // then it's probably the continuation of the last word from the prompt.
    // However, it's not applicable for chat modes.
    var rx = RegExp(r'\S+\s*');
    var match = rx.matchAsPrefix(output);
    var preText = match?.group(0) ?? ''; // the possible last part of the last word from the prompt
    var text = output.substring(preText.length);
    return GeneratedResult(
      text: Message.format(text, chatFormat, continueLastMsg),
      preText: preText.trimRight()
    );
  }

  final String text;
  final String preText;
  final GeneratedResultType type;

  String get fullText => [preText, text].where((s) => s.isNotEmpty).join(' ');
}

class ChatState extends State<Chat> {
  final inputController = TextEditingController();

  List<GeneratedResult> retryCache = [];
  String aiInputForRetryCache = '';
  Conversation? generatingForConv;
  Set<String> blacklistWordsForRetry = {};
  Message? continueMsg;
  String continueText = '';

  Future<void> submit(BuildContext context, int authorIndex, bool format) async {
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
    if(!isYou && curConv.type == ConversationType.groupChat) {
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
      if(!isYou && curConv.type == ConversationType.groupChat) {
        var match = RegExp(r'^\s*([^:]+):\s*(.*)$').firstMatch(text);
        if(match != null) {
          var participantName = (match.group(1) ?? '').trim();
          if(participantName.isNotEmpty)
            participantName = participantName.substring(0, 1).toUpperCase() +  participantName.substring(1);
          var textPart = match.group(2) ?? '';
          textPart = Message.format(textPart, chatFormat, false);
          text = '$participantName${MessagesModel.chatPromptSeparator} $textPart';
        } else {
          text = Message.format(text, chatFormat, false);
        }
      } else {
        text = Message.format(text, chatFormat, false);
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
    var combineLines = c.type != ConversationType.chat ? CombineChatLinesType.no : cfgModel.combineChatLines;
    switch(c.type) {
      case ConversationType.chat:
        return msgModel.getAiInputForChat(msgModel.messages, nextParticipant, combineLines, false, continueLastMsg);

      case ConversationType.groupChat:
        var inputText = msgModel.getAiInputForChat(msgModel.messages, nextParticipant, combineLines, true, continueLastMsg);
        return inputText;

      case ConversationType.adventure:
        return msgModel.getAiInputForAdventure(msgModel.messages, nextParticipantIndex);

      case ConversationType.story:
        return msgModel.aiInputForStory;
    }
  }

  Future<GeneratedResult> getGenerated(
    BuildContext context,
    int participantIndex, {
      String? participantName,
      Message? undoMessage,
      bool useBlacklist = true,
      bool continueLastMsg = false
    }
  ) async {
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

    var repPenInput = Conversation.getRepPenInput(context);

    aiInputForRetryCache = aiInput;
    retryCache.clear();

    var isChat = curConv.isChat;
    var chatFormat = isChat || participantIndex == Message.youIndex;
    var extractPreText = !isChat && participantIndex != Message.youIndex;

    var nTries = isChat ? 3 : 1;
    List<GeneratedResult> results = [];
    continueMsg = null;
    continueText = '';
    while(true) {
      try {
        var texts = await widget.generate(aiInput, repPenInput, promptedParticipant, participantName, blacklistWordsForRetry, continueLastMsg, undoMessage);
        var isSingle = texts.length == 1;
        results = texts
          .map((text) => isSingle
            ? GeneratedResult.fromRawOutput(text, chatFormat, extractPreText, continueLastMsg)
            : GeneratedResult(text: Message.format(text, chatFormat, continueLastMsg))
          )
          .where((result) => !result.isEmpty)
          .toSet().toList();
        if(results.isNotEmpty || nTries <= 1)
          break;
        nTries--;
      } catch(e) {
        results = [GeneratedResult(
          text: e.toString().replaceAll('\n', ''),
          type: e is ApiCancelException ? GeneratedResultType.cancel : GeneratedResultType.response
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
      if(curConv.type == ConversationType.groupChat) {
        text = text.replaceFirst(RegExp(r'[^:]*:\s*'), '');
      }
      var rx = RegExp(cfgModel.addSpecialSymbolsToBlacklist ? r'[*()\p{Number}]|\p{Letter}+' : r'\p{Number}|\p{Letter}+', unicode: true);
      var words = rx.allMatches(text).map((m) => m.group(0) ?? '').where((s) => s.isNotEmpty).toSet();
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

  Future<void> generateAndAdd(
    BuildContext context,
    int authorIndex, {
      String? authorName,
      Message? undoMessage,
      bool useBlacklist = true,
      bool continueLastMsg = false
    }
  ) async {
    var curConv = Provider.of<ConversationsModel>(context, listen: false).current;
    if(curConv == null)
      return;

    var result = await getGenerated(
      context,
      authorIndex,
      participantName: authorName,
      undoMessage: undoMessage,
      useBlacklist: useBlacklist,
      continueLastMsg: continueLastMsg
    );
    if(result.type == GeneratedResultType.cancel && generatingForConv != null && generatingForConv == curConv) {
      setState(() {
        disableAutoGen();
      });
    }
    if(result.isEmpty)
      return;

    var streamMsgModel = Provider.of<StreamMessageModel>(context, listen: false);
    if(result.type != GeneratedResultType.response) {
      var chatFormat = (curConv.isChat || authorIndex == Message.youIndex) && result.type != GeneratedResultType.cancel;
      var text = Message.format(streamMsgModel.text, chatFormat, continueLastMsg);
      if(text.isNotEmpty) {
        streamMsgModel.hide(); // first hide the streaming message to avoid showing it as a duplicate
        await addGenerated(
          context,
          authorIndex,
          undoMessage,
          useBlacklist,
          continueLastMsg,
          GeneratedResult(text: text),
          curConv
        );
      }
    }
    if(result.type != GeneratedResultType.cancel) {
      await addGenerated(
        context,
        authorIndex,
        undoMessage,
        useBlacklist,
        continueLastMsg,
        result,
        curConv
      );
    }
    streamMsgModel.hide();
  }

  Future<void> addGenerated(
    BuildContext context,
    int authorIndex,
    Message? undoMessage,
    bool useBlacklist,
    bool continueLastMsg,
    GeneratedResult result,
    Conversation curConv
  ) async {
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var lastMsg = msgModel.messages.lastOrNull;

    String msgText;
    var isError = result.type != GeneratedResultType.response;
    if(
      !isError
      && lastMsg != null
      && result.preText.isNotEmpty
      && lastMsg.authorIndex == authorIndex
      && !curConv.isChat
      && !continueLastMsg
    ) {
      lastMsg = msgModel.setText(lastMsg, lastMsg.text + result.preText, false);
      msgText = result.text;
    } else {
      msgText = result.fullText;
    }

    if(msgText.isNotEmpty) {
      if(!isError && lastMsg != null && continueLastMsg)
        lastMsg = msgModel.setText(lastMsg, lastMsg.text + msgText, false);
      else
        msgModel.addText(msgText, true, authorIndex);
    }
    await ConversationsModel.saveCurrentData(context);

    setState(() {
      var lastMsg = msgModel.messages.lastOrNull;
      if(continueLastMsg && lastMsg != null) {
        continueMsg = lastMsg;
        continueText = result.fullText;
      } else {
        continueMsg = null;
        continueText = '';
      }
    });

    if(generatingForConv != null && result.type == GeneratedResultType.response)
      nextAutoGenWithErrorHandling();
  }

  void enableAutoGen(Conversation conv) {
    generatingForConv = conv;
    WakelockPlus.enable();
  }

  void disableAutoGen() {
    generatingForConv = null;
    WakelockPlus.disable();
  }

  void nextAutoGenWithErrorHandling() {
    nextAutoGen().catchError((_) => setState(() => disableAutoGen()));
  }

  Future<void> nextAutoGen() async {
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

    int nextAuthorIndex;
    String? nextAuthorName;
    switch(curConv.type)
    {
      case ConversationType.chat:
      case ConversationType.groupChat:
        (nextAuthorIndex, nextAuthorName) = await Conversation.getNextParticipantNameFromServer(context, true, null);
        break;

      case ConversationType.adventure:
        nextAuthorIndex = msgModel.nextParticipantIndex;
        if(nextAuthorIndex == Message.youIndex && Random().nextDouble() < 0.6)
          nextAuthorIndex = Message.dmIndex;
        break;

      case ConversationType.story:
        nextAuthorIndex = Message.storyIndex;
        break;
    }

    await generateAndAdd(context, nextAuthorIndex, authorName: nextAuthorName);
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
              itemCount: msgModel.messages.length + 1,
              reverse: true,
              itemBuilder: (ctx, i) {
                if(i == 0) {
                  return Consumer<StreamMessageModel>(
                    builder: (context, streamMsg, child) {
                      var message = streamMsg.message;
                      if(message.text.isEmpty)
                        return const SizedBox.shrink();
                      var curConv = convModel.current;
                      if(curConv == null)
                        return const SizedBox.shrink();
                      var cfgModel = Provider.of<ConfigModel>(context, listen: false);
                      if(!cfgModel.streamResponse)
                        return const SizedBox.shrink();

                      return ChatMsg(
                        msg: streamMsg.message,
                        author: msgModel.participants[streamMsg.authorIndex],
                        isUsed: true,
                        conversation: curConv,
                        allowTap: false
                      );
                    },
                  );
                }

                var msgIndex = msgModel.messages.length - i;
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
            addGenerated: (authorIndex) => generateAndAdd(context, authorIndex),
            submit: (authorIndex) => submit(context, authorIndex, true),
            inputController: inputController,
            isGenerating: generatingForConv == curConv,
            onGeneratingSwitch: (newIsGenerating) {
              setState(() {
                if(newIsGenerating) {
                  enableAutoGen(curConv);
                  nextAutoGenWithErrorHandling();
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
          }) => generateAndAdd(
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
          },
          continueMsg: continueMsg,
          continueText: continueText
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
    required this.changeGroupParticipantName,
    required this.continueMsg,
    required this.continueText
  });

  final Function(int authorIndex, {Message? undoMessage, bool useBlacklist, bool continueLastMsg}) addGenerated;
  final Function(int authorIndex, bool format) submit;
  final Function(String newName) changeGroupParticipantName;
  final Message? continueMsg;
  final String continueText;

  @override
  State<ChatButtons> createState() => _ChatButtonsState();
}

class _ChatButtonsState extends State<ChatButtons> {
  final List<UndoItem> undoQueue = [];
  Conversation? undoConversation;
  static const List<String> undoUntilChars = ['.', '!', '?', '*', ':', ')'];
  static const List<String> undoUntilOnChars = ['('];
  static const List<String> undoUntilOnCharsBeforeSpace = ['*', '"', "'"];

  Message? get effectiveContinueMsg {
    if(widget.continueText.isEmpty)
      return null;
    var continueMsg = widget.continueMsg;
    if(continueMsg == null)
      return null;
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var lastMsg = msgModel.messages.lastOrNull;
    if(lastMsg == null)
      return null;
    if(lastMsg != continueMsg)
      return null;
    if(!lastMsg.text.endsWith(widget.continueText))
      return null;
    return continueMsg;
  }

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
      case ConversationType.chat:
        buttonRows = chatButtons(context, msgModel, curConv, neodimModel, cfgModel, false);
        break;

      case ConversationType.groupChat:
        buttonRows = chatButtons(context, msgModel, curConv, neodimModel, cfgModel, true);
        break;

      case ConversationType.adventure:
        buttonRows = adventureButtons(context, msgModel, curConv, neodimModel, cfgModel);
        break;

      case ConversationType.story:
        buttonRows = storyButtons(context, msgModel, curConv, neodimModel, cfgModel);
        break;
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
        var continueMsg = effectiveContinueMsg;
        if(continueMsg != null) {
          var undoItem = UndoItem(message: continueMsg, text: widget.continueText);
          var newText = continueMsg.text.substring(0, continueMsg.text.length - widget.continueText.length);
          msgModel.setText(continueMsg, newText, false);
          setState(() {
            undoConversation = curConv;
            undoQueue.add(undoItem);
          });
          await ConversationsModel.saveCurrentData(context);
          // create a fake undo message for blacklist
          var undoMessage = Message(
            text: widget.continueText,
            authorIndex: continueMsg.authorIndex,
            isGenerated: continueMsg.isGenerated
          );
          widget.addGenerated(
            continueMsg.authorIndex,
            undoMessage: undoMessage,
            useBlacklist: !isLong,
            continueLastMsg: true
          );
        } else {
          var undoItem = await undo(msgModel, cfgModel, curConv, false);
          var msg = undoItem?.message;
          if(msg == null)
            return;
          widget.addGenerated(msg.authorIndex, undoMessage: msg, useBlacklist: !isLong);
        }
      },
      isEnabled:
        !neodimModel.isApiRunning
        && (
          msgModel.generatedAtEnd != null
          ||
          effectiveContinueMsg != null
        ),
      icon: Icons.refresh
    );
  }

  Widget btnGenerate(bool isYou, ApiModel neodimModel, MessagesModel msgModel) {
    return ChatButton(
      onPressed: (isLong) {
        var authorIndex = isYou ? Message.youIndex : Message.storyIndex;
        var continueLastMsg = isLong && authorIndex == msgModel.lastParticipantIndex;
        widget.addGenerated(authorIndex, continueLastMsg: continueLastMsg);
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
      btnGenerate(false, neodimModel, msgModel),
      btnGenerate(true, neodimModel, msgModel),
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
      btnGenerate(false, neodimModel, msgModel),
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
      btnGenerate(false, neodimModel, msgModel),
      btnUndo(msgModel, cfgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(msgModel, cfgModel, curConv, neodimModel)
    ]];
  }
}

class ChatInput extends StatelessWidget {
  const ChatInput({
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
      case ConversationType.chat:
      case ConversationType.groupChat:
        nextParticipantIndex = msgModel.nextParticipantIndex;
        break;

      case ConversationType.adventure:
        nextParticipantIndex = Message.youIndex;
        break;

      case ConversationType.story:
        nextParticipantIndex = Message.storyIndex;
        break;

      default:
        return const SizedBox.shrink();
    }

    var nextParticipant = msgModel.participants[nextParticipantIndex];

    return TextField(
      controller: inputController,
      autofocus: true,
      onSubmitted: (text) {
        if(neodimModel.isApiRunning)
          return;

        inputController.text = inputController.text.trim();
        var wasEmpty = inputController.text.isEmpty;
        submit(nextParticipantIndex);

        switch(convModel.current?.type) {
          case ConversationType.chat:
          case ConversationType.groupChat:
            addGenerated(msgModel.nextParticipantIndex);
            break;

          case ConversationType.adventure:
            addGenerated(Message.dmIndex);
            break;

          case ConversationType.story:
            if(wasEmpty)
              addGenerated(Message.storyIndex);
            break;

          default:
            break;
        }
      },
      decoration: InputDecoration(
        hintText: nextParticipant.name,
        suffixIcon: Consumer<ApiCancelModel>(
          builder: (context, apiCancelModel, child) {
            var cancelFunc = apiCancelModel.cancelFunc;
            if(cancelFunc != null) {
              return IconButton(
                icon: const Icon(Icons.stop),
                onPressed: () => cancelFunc()
              );
            }
            return GestureDetector(
              onLongPress: () {
                Feedback.forLongPress(context);
                onGeneratingSwitch(!isGenerating);
              },
              child: IconButton(
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
                    case ConversationType.chat:
                    case ConversationType.groupChat:
                      addGenerated(msgModel.nextParticipantIndex);
                      break;

                    case ConversationType.adventure:
                      addGenerated(Message.dmIndex);
                      break;

                    case ConversationType.story:
                      if(wasEmpty)
                        addGenerated(Message.storyIndex);
                      break;

                    default:
                      break;
                  }
                }
              )
            );
          }
        ),
        contentPadding: const EdgeInsets.only(left: 5, top: 15)
      ),
      maxLines: 5,
      minLines: 1,
      textInputAction: TextInputAction.send
    );
  }
}
