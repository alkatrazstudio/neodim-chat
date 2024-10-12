// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../apis/request.dart';
import '../apis/response.dart';
import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../widgets/chat.dart';
import '../widgets/drawer_column.dart';
import '../widgets/main_menu.dart';

class HomePage extends StatelessWidget {

  String outputTextFromSequence(ApiResponseSequence s) {
    var text = s.generatedText;
    if(s.stopStringMatchIsSentenceEnd)
      text = text + s.stopStringMatch;
    return text.trimRight();
  }

  Future<String?> getNextGroupParticipantName(
    BuildContext context,
    String inputText,
    String? repPenText,
    List<String> participantNames
  ) async {
    if(participantNames.length == 1)
      return participantNames[0];

    var streamMsgModel = Provider.of<StreamMessageModel>(context, listen: false);
    var response = await ApiRequest.run(
      context,
      inputText,
      repPenText,
      participantNames,
      null,
      (newText) => streamMsgModel.addText(newText),
    );
    if(response == null)
      return null;

    var responseText = response.sequences.map(outputTextFromSequence).first;
    if(participantNames.contains(responseText))
      return responseText;
    return null;
  }

  Future<List<String>> generate({
    required BuildContext context,
    required String inputText,
    required String? repPenText,
    required Participant promptedParticipant,
    required Set<String> blacklistWordsForRetry,
    required bool continueLastMsg,
    required Message? undoMessage
  }) async {
    var apiModel = Provider.of<ApiModel>(context, listen: false);
    if(apiModel.isApiRunning)
      return [];

    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var conv = convModel.current;
    if(conv == null)
      return [];

    var streamMsgModel = Provider.of<StreamMessageModel>(context, listen: false);
    var promptedParticipantIndex = msgModel.participants.indexOf(promptedParticipant);
    streamMsgModel.reset(promptedParticipantIndex);
    var inputMessages = msgModel.getMessagesSnapshot();
    apiModel.setApiRunning(true);
    try {
      var addedPromptSuffix = '';
      if(conv.type == ConversationType.groupChat && promptedParticipantIndex != Message.youIndex && !continueLastMsg) {
        var participantNames = msgModel.getGroupParticipantNames(false);
        String? participantName;
        if(undoMessage != null && undoMessage.authorIndex != Message.youIndex) {
          switch(cfgModel.participantOnRetry) {
            case ParticipantOnRetry.different:
              if(participantNames.length > 1) {
                var prevParticipantName = MessagesModel.extractParticipantName(undoMessage.text);
                if(prevParticipantName.isNotEmpty)
                  participantNames = participantNames.where((name) => name != prevParticipantName).toList();
              }
              break;

            case ParticipantOnRetry.same:
              var prevParticipantName = MessagesModel.extractParticipantName(undoMessage.text);
              if(prevParticipantName.isNotEmpty && participantNames.contains(prevParticipantName))
                participantName = prevParticipantName;
              break;

            default:
              break;
          }
        }
        participantName ??= await getNextGroupParticipantName(context, inputText, repPenText, participantNames);
        if(participantName == null)
          throw Exception('Cannot get the correct participant name');
        addedPromptSuffix = '$participantName${MessagesModel.chatPromptSeparator}';
        inputText += addedPromptSuffix;
        addedPromptSuffix += ' ';
        streamMsgModel.addText('${MessagesModel.chatPromptSeparator} ');
      }

      var response = await ApiRequest.run(
        context,
        inputText,
        repPenText,
        null,
        blacklistWordsForRetry,
        (newText) => streamMsgModel.addText(newText),
      );
      if(response == null)
        return [];
      apiModel.setResponse(response);
      apiModel.setApiRunning(false);
      streamMsgModel.hide();
      var combineLines = conv.type == ConversationType.chat ? CombineChatLinesType.no : cfgModel.combineChatLines;
      convModel.updateUsedMessagesCount(
        response.usedPrompt, promptedParticipant, msgModel, inputMessages, combineLines, addedPromptSuffix, continueLastMsg);
      var lines = response.sequences.map(outputTextFromSequence).toList();
      lines = lines.map((line) => addedPromptSuffix + line).toList();
      return lines;
    } catch (e) {
      streamMsgModel.hide();
      apiModel.setApiRunning(false);
      rethrow;
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
          actions: [MainMenu()]
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
                    blacklistWordsForRetry,
                    continueLastMsg,
                    undoMessage
                  ) async => await generate(
                    context: context,
                    inputText: text,
                    repPenText: repPenText,
                    promptedParticipant: promptedParticipant,
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
