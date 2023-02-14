// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import 'package:wakelock/wakelock.dart';

import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../models/neodim_model.dart';
import '../widgets/chat_msg.dart';

class Chat extends StatefulWidget {
  const Chat({
    required this.generate
  });

  final Future<List<String>> Function(String, String?, Participant) generate;

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

  Future submit(BuildContext context, int authorIndex) async {
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    if(inputController.text.isEmpty)
      return;
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var curConv = convModel.current;
    if(curConv == null)
      return;
    var chatFormat = curConv.type == Conversation.typeChat || authorIndex == Message.youIndex;
    var text = Message.format(inputController.text, chatFormat);
    msgModel.addText(text, false, authorIndex);
    inputController.clear();
    await ConversationsModel.saveCurrentData(context);
  }

  String getAiInput(Conversation c, MessagesModel msgModel, Participant nextParticipant, int nextParticipantIndex) {
    switch(c.type) {
      case Conversation.typeChat:
        return msgModel.getAiInputForChat(msgModel.messages, nextParticipant);

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
          return msgModel.getOriginalRepetitionPenaltyTextForChat(msgModel.messages);
        } else {
          return msgModel.getRepetitionPenaltyTextForChat(
            msgModel.messages,
            cfgModel.repetitionPenaltyLinesWithNoExtraSymbols
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

  Future<GeneratedResult> getGenerated(BuildContext context, int participantIndex) async {
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var curConv = convModel.current;
    if(curConv == null)
      return GeneratedResult.empty;
    var msgModel = Provider.of<MessagesModel>(context, listen: false);

    var promptedParticipant = msgModel.participants[participantIndex];
    var aiInput = getAiInput(curConv, msgModel, promptedParticipant, participantIndex);

    if(aiInput == aiInputForRetryCache && retryCache.isNotEmpty) {
      var result = retryCache.removeAt(0);
      return result;
    }

    var cfgModel = Provider.of<ConfigModel>(context, listen: false);

    var repPenInput = getRepPenInput(curConv, msgModel, cfgModel);

    aiInputForRetryCache = aiInput;
    retryCache.clear();

    var isChat = curConv.type == Conversation.typeChat;
    var chatFormat = isChat || participantIndex == Message.youIndex;

    var nTries = isChat ? 3 : 1;
    List<GeneratedResult> results = [];
    while(true) {
      try {
        var texts = await widget.generate(aiInput, repPenInput, promptedParticipant);
        var isSingle = texts.length == 1;
        results = texts
          .map((text) => isSingle
            ? GeneratedResult.fromRawOutput(text, chatFormat)
            : GeneratedResult(text: Message.format(text, chatFormat))
          )
          .where((result) => result.text.isNotEmpty)
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
    retryCache = results;
    return result;
  }

  Future addGenerated(BuildContext context, int authorIndex) async {
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var curConv = Provider.of<ConversationsModel>(context, listen: false).current;
    if(curConv == null)
      return;

    var result = await getGenerated(context, authorIndex);
    if(result.isEmpty)
      return;

    var lastMsg = msgModel.messages.lastOrNull;
    if(
      lastMsg != null
      && result.preText.isNotEmpty
      && lastMsg.authorIndex == authorIndex
      && curConv.type != Conversation.typeChat
    ) {
      msgModel.setText(lastMsg, lastMsg.text + result.preText, false);
    }

    msgModel.addText(result.text, true, authorIndex);
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
    Wakelock.enable();
  }

  void disableAutoGen() {
    generatingForConv = null;
    Wakelock.disable();
  }

  Future nextAutoGen() async {
    if(Provider.of<NeodimModel>(context, listen: false).isApiRunning)
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

    var nextAuthorIndex = Message.storyIndex;
    switch(curConv.type)
    {
      case Conversation.typeChat:
        nextAuthorIndex = Random().nextInt(msgModel.participants.length);
        if(nextAuthorIndex == msgModel.lastParticipantIndex)
          nextAuthorIndex = Random().nextInt(msgModel.participants.length);
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

        Consumer<NeodimModel>(
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
            submit: (authorIndex) => submit(context, authorIndex),
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
          addGenerated: (authorIndex) => addGenerated(context, authorIndex),
          submit: (authorIndex) => submit(context, authorIndex)
        ),

        Consumer<NeodimModel>(builder: (context, neodimModel, child) {
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
    required this.submit
  });

  final Function(int authorIndex) addGenerated;
  final Function(int authorIndex) submit;

  @override
  State<ChatButtons> createState() => _ChatButtonsState();
}

class _ChatButtonsState extends State<ChatButtons> {
  final List<UndoItem> undoQueue = [];
  Conversation? undoConversation;

  @override
  Widget build(BuildContext context) {
    var convModel = Provider.of<ConversationsModel>(context);
    var curConv = convModel.current;
    if(curConv == null)
      return const SizedBox.shrink();
    var msgModel = Provider.of<MessagesModel>(context);
    var neodimModel = Provider.of<NeodimModel>(context);
    var cfgModel = Provider.of<ConfigModel>(context);

    if(undoConversation != curConv)
      undoQueue.clear();

    List<List<Widget>> buttonRows;
    switch(curConv.type) {
      case Conversation.typeChat:
        buttonRows = chatButtons(context, msgModel, curConv, neodimModel, cfgModel);
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

  Future<UndoItem?> undo(MessagesModel msgModel, ConfigModel cfgModel, Conversation curConv, bool forRetry) async {
    var lastMsg = msgModel.messages.lastOrNull;
    if(lastMsg == null)
      return null;

    var undoBySentence = !forRetry && cfgModel.undoBySentence && lastMsg.text.isNotEmpty;
    late UndoItem undoItem;
    if(undoBySentence) {
      var pos = lastMsg.text.length - 1;
      var hasNonStop = false;
      var undoText = '';
      while(pos >= 0) {
        var char = lastMsg.text[pos];
        var stopBeforeQuote =
          (char == '"' || char == "'")
            &&
          pos > 0
            &&
          (lastMsg.text[pos - 1] == '.' || lastMsg.text[pos - 1] == '?' || lastMsg.text[pos - 1] == '!');
        if(stopBeforeQuote || char == '.' || char == '?' || char == '!') {
          if(hasNonStop)
            break;
        } else {
          hasNonStop = true;
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

  Widget btnUndo(BuildContext context, MessagesModel msgModel, ConfigModel cfgModel, Conversation curConv) {
    return IconButton(
      onPressed: msgModel.messages.isEmpty ? null : () async {
        await undo(msgModel, cfgModel, curConv, false);
      },
      icon: const Icon(Icons.undo)
    );
  }

  Widget btnRedo(BuildContext context, MessagesModel msgModel) {
    return IconButton(
      onPressed: undoQueue.isEmpty ? null : () async {
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
      icon: const Icon(Icons.redo)
    );
  }

  Widget btnRetry(BuildContext context, MessagesModel msgModel, ConfigModel cfgModel, Conversation curConv, NeodimModel neodimModel) {
    return IconButton(
      onPressed: (neodimModel.isApiRunning || msgModel.generatedAtEnd == null) ? null : () async {
        var undoItem = await undo(msgModel, cfgModel, curConv, true);
        var msg = undoItem?.message;
        if(msg == null)
          return;
        widget.addGenerated(msg.authorIndex);
      },
      icon: const Icon(Icons.refresh)
    );
  }

  List<List<Widget>> chatButtons(
      BuildContext context,
      MessagesModel msgModel,
      Conversation curConv,
      NeodimModel neodimModel,
      ConfigModel cfgModel
    ) {
    return [[
      btnUndo(context, msgModel, cfgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(context, msgModel, cfgModel, curConv, neodimModel)
    ], [
      IconButton(
        onPressed: neodimModel.isApiRunning ? null : () {
          widget.addGenerated(Message.youIndex + 1);
        },
        icon: const Icon(Icons.speaker_notes_outlined)
      ),
      IconButton(
        onPressed: neodimModel.isApiRunning ? null : () {
          widget.addGenerated(Message.youIndex);
        },
        icon: Transform.scale(
          scaleX: -1,
          child: const Icon(Icons.speaker_notes_outlined)
        )
      ),
      IconButton(
        onPressed: neodimModel.isApiRunning ? null : () {
          widget.submit(Message.youIndex + 1);
        },
        icon: Transform.scale(
          scaleX: -1,
          child: const Icon(Icons.add_comment_outlined)
        )
      ),
      IconButton(
        onPressed: neodimModel.isApiRunning ? null : () {
          widget.submit(Message.youIndex);
        },
        icon: const Icon(Icons.add_comment_outlined)
      )
    ]];
  }

  List<List<Widget>> adventureButtons(
    BuildContext context,
    MessagesModel msgModel,
    Conversation curConv,
    NeodimModel neodimModel,
    ConfigModel cfgModel
  ) {
    return [[
      btnUndo(context, msgModel, cfgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(context, msgModel, cfgModel, curConv, neodimModel)
    ], [
      IconButton(
        onPressed: (neodimModel.isApiRunning || msgModel.messages.isEmpty) ? null : () {
          widget.addGenerated(Message.dmIndex);
        },
        icon: const Icon(Icons.speaker_notes_outlined)
      ),
      IconButton(
        onPressed: neodimModel.isApiRunning ? null : () {
          widget.submit(Message.dmIndex);
        },
        icon: Transform.scale(
          scaleX: -1,
          child: const Icon(Icons.add_comment_outlined)
        )
      )
    ]];
  }

  List<List<Widget>> storyButtons(
    BuildContext context,
    MessagesModel msgModel,
    Conversation curConv,
    NeodimModel neodimModel,
    ConfigModel cfgModel
  ) {
    return [[
      IconButton(
        onPressed: (neodimModel.isApiRunning || msgModel.messages.isEmpty) ? null : () {
          widget.addGenerated(Message.storyIndex);
        },
        icon: const Icon(Icons.speaker_notes_outlined)
      ),
      btnUndo(context, msgModel, cfgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(context, msgModel, cfgModel, curConv, neodimModel)
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
  final FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    var neodimModel = Provider.of<NeodimModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var msgModel = Provider.of<MessagesModel>(context, listen: false);

    var nextParticipantIndex = Message.noneIndex;

    switch(convModel.current?.type) {
      case Conversation.typeChat:
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
      focusNode: focusNode,
      autofocus: true,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (text) {
        if(neodimModel.isApiRunning)
          return;

        var wasEmpty = inputController.text.isEmpty;
        submit(nextParticipantIndex);
        focusNode.requestFocus();

        switch(convModel.current?.type) {
          case Conversation.typeChat:
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

              var wasEmpty = inputController.text.isEmpty;
              submit(nextParticipantIndex);

              switch(convModel.current?.type) {
                case Conversation.typeChat:
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
