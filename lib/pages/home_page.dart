// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../apis/request.dart';
import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../util/popups.dart';
import '../widgets/chat.dart';
import '../widgets/drawer_column.dart';
import '../widgets/main_menu.dart';

class HomePage extends StatelessWidget {
  Future<List<String>> generate({
    required BuildContext context,
    required String inputText,
    required String? repPenText,
    required Participant promptedParticipant,
    required String? promptedParticipantName,
    required Set<String> blacklistWordsForRetry,
    required bool continueLastMsg,
    required Message? undoMessage,
    bool onlySaveCache = false
  }) async {
    var apiModel = Provider.of<ApiModel>(context, listen: false);
    if(apiModel.isApiRunning)
      return [];

    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var conv = convModel.current;
    if(conv == null)
      return [];

    var streamMsgModel = Provider.of<StreamMessageModel>(context, listen: false);
    var promptedParticipantIndex = msgModel.participants.indexOf(promptedParticipant);
    streamMsgModel.reset(promptedParticipantIndex);
    try {
      var addedPromptSuffix = '';
      if(!onlySaveCache && conv.type == ConversationType.groupChat && promptedParticipantIndex != Message.youIndex && !continueLastMsg) {
        if(promptedParticipantName == null)
          (_, promptedParticipantName) = await Conversation.getNextParticipantNameFromServer(context, false, undoMessage);
        addedPromptSuffix = '$promptedParticipantName${MessagesModel.chatPromptSeparator}';
        streamMsgModel.addText(addedPromptSuffix);
        inputText += addedPromptSuffix;
        addedPromptSuffix += ' ';
      }
      apiModel.setApiRunning(true);
      var response = await ApiRequest.run(
        context: context,
        inputText: inputText,
        repPenText: repPenText,
        blacklistWordsForRetry: blacklistWordsForRetry,
        onlySaveCache: onlySaveCache,
        onNewStreamText: (newText) {
          if(!onlySaveCache)
            streamMsgModel.addText(newText);
        },
      );
      streamMsgModel.hide();
      if(response == null)
        return [];
      apiModel.setResponse(response);
      var lines = response.sequences.map((seq) => seq.outputText).toList();
      lines = lines.map((line) => addedPromptSuffix + line).toList();
      return lines;
    } finally {
      apiModel.setApiRunning(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<ConversationsModel>(builder: (context, value, child) {
            return Text(value.current?.name ?? 'Neodim Chat');
          }),
          actions: [
            Consumer<ApiModel>(builder: (context, apiModel, child) {
              return MainMenu(
                onSaveCache: apiModel.isApiRunning ? null : () async {
                  if(apiModel.isApiRunning)
                    return;
                  var convModel = Provider.of<ConversationsModel>(context, listen: false);
                  var curConv = convModel.current;
                  if(curConv == null)
                    return;
                  var msgModel = Provider.of<MessagesModel>(context, listen: false);
                  var cfgModel = Provider.of<ConfigModel>(context, listen: false);
                  var participantIndex = msgModel.nextParticipantIndex;
                  var promptedParticipant = msgModel.participants[participantIndex];
                  var inputText = msgModel.getAiInput(curConv, cfgModel, promptedParticipant, participantIndex, false);
                  var repPenText = Conversation.getRepPenInput(context);
                  try {
                    await generate(
                      context: context,
                      inputText: inputText,
                      repPenText: repPenText,
                      promptedParticipant: promptedParticipant,
                      promptedParticipantName: promptedParticipant.name,
                      blacklistWordsForRetry: {},
                      continueLastMsg: false,
                      undoMessage: null,
                      onlySaveCache: true
                    );
                  } catch(e) {
                    showPopupMsg(context, e.toString());
                  }
                }
              );
            })
          ]
        ),

        drawer: Drawer(
          child: DrawerColumn()
        ),

        body: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Chat(
                  generate: (
                    text,
                    repPenText,
                    promptedParticipant,
                    promptedParticipantName,
                    blacklistWordsForRetry,
                    continueLastMsg,
                    undoMessage
                  ) async => await generate(
                    context: context,
                    inputText: text,
                    repPenText: repPenText,
                    promptedParticipant: promptedParticipant,
                    promptedParticipantName: promptedParticipantName,
                    blacklistWordsForRetry: blacklistWordsForRetry,
                    continueLastMsg: continueLastMsg,
                    undoMessage: undoMessage
                  )
                )
              )
            ]
          )
        )
      )
    );
  }
}
