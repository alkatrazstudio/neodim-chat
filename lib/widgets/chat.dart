// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

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

class ChatState extends State<Chat> {
  final inputController = TextEditingController();

  List<String> retryCache = [];
  String aiInputForRetryCache = '';

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

  String getAiInput(Conversation c, MessagesModel msgModel, Participant nextParticipant) {
    switch(c.type) {
      case Conversation.typeChat:
        return msgModel.getAiInputForChat(msgModel.messages, nextParticipant);

      case Conversation.typeAdventure:
        return msgModel.aiInputForAdventure;

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

  Future<String> getGenerated(BuildContext context, int participantIndex) async {
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var curConv = convModel.current;
    if(curConv == null)
      return '';
    var msgModel = Provider.of<MessagesModel>(context, listen: false);

    var promptedParticipant = msgModel.participants[participantIndex];
    var aiInput = getAiInput(curConv, msgModel, promptedParticipant);

    if(aiInput == aiInputForRetryCache && retryCache.isNotEmpty) {
      var text = retryCache.removeAt(0);
      return text;
    }

    var cfgModel = Provider.of<ConfigModel>(context, listen: false);

    var repPenInput = getRepPenInput(curConv, msgModel, cfgModel);

    aiInputForRetryCache = aiInput;
    retryCache.clear();

    var isChat = curConv.type == Conversation.typeChat;
    var chatFormat = isChat || participantIndex == Message.youIndex;

    var nTries = isChat ? 3 : 1;
    List<String> texts = [];
    while(true) {
      try {
        texts = await widget.generate(aiInput, repPenInput, promptedParticipant);
        texts = texts
          .map((text) => Message.format(text, chatFormat))
          .where((text) => text.isNotEmpty)
          .toSet().toList();
        if(texts.isNotEmpty || nTries <= 1)
          break;
        nTries--;
      } catch(e) {
        texts = [e.toString().replaceAll('\n', '')];
        break;
      }
    }

    if(texts.isEmpty)
      return '';

    var text = texts.removeAt(0);
    retryCache = texts;
    return text;
  }

  Future addGenerated(BuildContext context, int authorIndex) async {
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var text = await getGenerated(context, authorIndex);
    msgModel.addText(text, true, authorIndex);
    await ConversationsModel.saveCurrentData(context);
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
          if(convModel.current == null)
            return const SizedBox.shrink();

          return ChatInput(
            addGenerated: (authorIndex) => addGenerated(context, authorIndex),
            submit: (authorIndex) => submit(context, authorIndex),
            inputController: inputController
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
  final List<Message> undoQueue = [];
  Conversation? undoConversation;
  var msgCountToUndo = -1;

  @override
  Widget build(BuildContext context) {
    var convModel = Provider.of<ConversationsModel>(context);
    var curConv = convModel.current;
    if(curConv == null)
      return const SizedBox.shrink();
    var msgModel = Provider.of<MessagesModel>(context);
    var neodimModel = Provider.of<NeodimModel>(context);

    if(msgModel.messages.length != msgCountToUndo || undoConversation != curConv)
      undoQueue.clear();

    List<List<Widget>> buttonRows;
    switch(curConv.type) {
      case Conversation.typeChat:
        buttonRows = chatButtons(context, msgModel, curConv, neodimModel);
        break;

      case Conversation.typeAdventure:
        buttonRows = adventureButtons(context, msgModel, curConv, neodimModel);
        break;

      case Conversation.typeStory:
        buttonRows = storyButtons(context, msgModel, curConv, neodimModel);
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

  Future<Message?> undo(MessagesModel msgModel, Conversation curConv) async {
    msgCountToUndo = msgModel.messages.length - 1;
    var msg = msgModel.removeLast();
    if(msg == null)
      return null;

    setState(() {
      undoConversation = curConv;
      undoQueue.add(msg);
    });

    await ConversationsModel.saveCurrentData(context);
    return msg;
  }

  Widget btnUndo(BuildContext context, MessagesModel msgModel, Conversation curConv) {
    return IconButton(
      onPressed: msgModel.messages.isEmpty ? null : () async {
        await undo(msgModel, curConv);
      },
      icon: const Icon(Icons.undo)
    );
  }

  Widget btnRedo(BuildContext context, MessagesModel msgModel) {
    return IconButton(
      onPressed: undoQueue.isEmpty ? null : () async {
        setState(() {
          msgCountToUndo = msgModel.messages.length + 1;
          var msg = undoQueue.removeLast();
          msgModel.add(msg);
        });
        await ConversationsModel.saveCurrentData(context);
      },
      icon: const Icon(Icons.redo)
    );
  }

  Widget btnRetry(BuildContext context, MessagesModel msgModel, Conversation curConv, NeodimModel neodimModel) {
    return IconButton(
      onPressed: (neodimModel.isApiRunning || msgModel.generatedAtEnd == null) ? null : () async {
        var msg = await undo(msgModel, curConv);
        if(msg == null)
          return;
        widget.addGenerated(msg.authorIndex);
      },
      icon: const Icon(Icons.refresh)
    );
  }

  List<List<Widget>> chatButtons(BuildContext context, MessagesModel msgModel, Conversation curConv, NeodimModel neodimModel) {
    return [[
      btnUndo(context, msgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(context, msgModel, curConv, neodimModel),
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

  List<List<Widget>> adventureButtons(BuildContext context, MessagesModel msgModel, Conversation curConv, NeodimModel neodimModel) {
    return [[
      btnUndo(context, msgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(context, msgModel, curConv, neodimModel)
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

  List<List<Widget>> storyButtons(BuildContext context, MessagesModel msgModel, Conversation curConv, NeodimModel neodimModel) {
    return [[
      IconButton(
        onPressed: (neodimModel.isApiRunning || msgModel.messages.isEmpty) ? null : () {
          widget.addGenerated(Message.storyIndex);
        },
        icon: const Icon(Icons.speaker_notes_outlined)
      ),
      btnUndo(context, msgModel, curConv),
      btnRedo(context, msgModel),
      btnRetry(context, msgModel, curConv, neodimModel)
    ]];
  }
}

class ChatInput extends StatelessWidget {
  ChatInput({
    required this.addGenerated,
    required this.submit,
    required this.inputController
  });

  final Function(int authorIndex) addGenerated;
  final Function(int authorIndex) submit;
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
      autocorrect: true,
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
        suffixIcon: IconButton(
          icon: const Icon(Icons.send),
          onPressed: () {
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
        ),
        contentPadding: const EdgeInsets.only(left: 5, bottom: 0, right: 0, top: 15)
      ),
      maxLines: 5,
      minLines: 1,
      textInputAction: TextInputAction.send
    );
  }
}
