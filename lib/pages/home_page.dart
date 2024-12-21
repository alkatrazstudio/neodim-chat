// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../apis/request.dart';
import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
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
    try {
      var addedPromptSuffix = '';
      if(conv.type == ConversationType.groupChat && promptedParticipantIndex != Message.youIndex && !continueLastMsg) {
        if(promptedParticipantName == null)
          (_, promptedParticipantName) = await Conversation.getNextParticipantNameFromServer(context, false, undoMessage);
        addedPromptSuffix = '$promptedParticipantName${MessagesModel.chatPromptSeparator}';
        streamMsgModel.addText(addedPromptSuffix);
        inputText += addedPromptSuffix;
        addedPromptSuffix += ' ';
      }
      apiModel.setApiRunning(true);
      var response = await ApiRequest.run(
        context,
        inputText,
        repPenText,
        null,
        blacklistWordsForRetry,
        (newText) => streamMsgModel.addText(newText),
      );
      streamMsgModel.hide();
      if(response == null)
        return [];
      apiModel.setResponse(response);
      var combineLines = conv.type == ConversationType.chat ? CombineChatLinesType.no : cfgModel.combineChatLines;
      convModel.updateUsedMessagesCount(
        response.usedPrompt, promptedParticipant, msgModel, inputMessages, combineLines, addedPromptSuffix, continueLastMsg);
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
          actions: [MainMenu()]
        ),

        drawer: Drawer(
          child: DrawerColumn()
        ),

        body: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Consumer<ConversationsModel>(builder: (context, convModel, child) {
                if(convModel.current != null)
                  return const SizedBox.shrink();
                return Column(
                  spacing: 10,
                  children: [
                    const Row(
                      spacing: 5,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning),
                        Text('WARNING', style: TextStyle(fontWeight: FontWeight.bold))
                      ]
                    ),
                    const Text('The app will be removed from Google Play soon!'),
                    RichText(
                      text: TextSpan(
                        text: '[read more]',
                        style: TextStyle(decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => launchUrlString(
                            'https://github.com/alkatrazstudio/neodim-chat#warning-the-app-will-soon-be-removed-from-google-play',
                            mode: LaunchMode.externalApplication
                          )
                      )
                    )
                  ]
                );
              }),
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
