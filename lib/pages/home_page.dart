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
import '../pages/help_page.dart';
import '../pages/settings_page.dart';
import '../widgets/chat.dart';
import '../widgets/main_menu.dart';

class HomePage extends StatelessWidget {
  static const String requiredServerVersion = '>=0.13';

  String outputTextFromSequence(ApiResponseSequence s) {
    var text = s.generatedText;
    if(s.stopStringMatchIsSentenceEnd)
      text = text + s.stopStringMatch;
    return text.trim();
  }

  Future<String?> getNextGroupParticipantName(
    BuildContext context,
    String inputText,
    String? repPenText,
    List<String> participantNames
  ) async {
    if(participantNames.length == 1)
      return participantNames[0];

    var response = await ApiRequest.run(
      context,
      inputText,
      repPenText,
      participantNames,
      null
    );
    if(response == null)
      return null;

    var responseText = response.sequences.map(outputTextFromSequence).first;
    if(participantNames.contains(responseText))
      return responseText;
    return null;
  }

  Future<List<String>> generate(
    BuildContext context,
    String inputText,
    String? repPenText,
    Participant promptedParticipant,
    Set<String> blacklistWordsForRetry,
    bool continueLastMsg
  ) async {
    var apiModel = Provider.of<ApiModel>(context, listen: false);
    if(apiModel.isApiRunning)
      return [];

    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var conv = convModel.current;
    if(conv == null)
      return [];

    var inputMessages = msgModel.getMessagesSnapshot();
    apiModel.setApiRunning(true);
    try {
      var addedPromptSuffix = '';
      var promptedParticipantIndex = msgModel.participants.indexOf(promptedParticipant);
      if(conv.type == Conversation.typeGroupChat && promptedParticipantIndex != Message.youIndex && !continueLastMsg) {
        var participantNames = msgModel.getGroupParticipantNames(false);
        var participantName = await getNextGroupParticipantName(context, inputText, repPenText, participantNames);
        if(participantName == null)
          throw Exception('Cannot get the correct participant name');
        addedPromptSuffix = '$participantName${MessagesModel.chatPromptSeparator}';
        inputText += addedPromptSuffix;
        addedPromptSuffix += ' ';
      }

      var response = await ApiRequest.run(
          context,
          inputText,
          repPenText,
          null,
          blacklistWordsForRetry
      );
      if(response == null)
        return [];
      apiModel.setResponse(response);
      apiModel.setApiRunning(false);
      var combineLines = conv.type == Conversation.typeChat ? CombineChatLinesType.no : cfgModel.combineChatLines;
      convModel.updateUsedMessagesCount(
        response.usedPrompt, promptedParticipant, msgModel, inputMessages, combineLines, addedPromptSuffix, continueLastMsg);
      var lines = response.sequences.map(outputTextFromSequence).toList();
      lines = lines.map((line) => addedPromptSuffix + line).toList();
      return lines;
    } catch (e) {
      apiModel.setApiRunning(false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Consumer<ConversationsModel>(builder: (context, value, child) {
            return Text(value.current?.name ?? 'Neodim Chat');
          }),
          actions: [MainMenu()]
        ),

        drawer: Drawer(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Neodim Chat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),
                      textAlign: TextAlign.center
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        var c = Conversation.create('Conversation');
                        var data = ConversationData.empty();
                        await c.saveData(data);
                        Provider.of<ConversationsModel>(context, listen: false)
                          ..add(c)
                          ..save();
                        c.setAsCurrent(context, data);
                        Navigator.pop(context);
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage())
                        );
                      },
                      child: const Text('New conversation')
                    ),
                    ElevatedButton(
                      child: const Text('Help'),
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(builder: (context) => const HelpPage())
                        );
                      }
                    )
                  ]
                )
              ),
              Expanded(
                child: Consumer<ConversationsModel>(
                  builder: (context, conversations, child) {
                    return ListView.builder(
                      itemCount: conversations.conversations.length,
                      itemBuilder: (context, index) {
                        var c = conversations.conversations[conversations.conversations.length - 1 - index];
                        return ListTile(
                          title: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: conversations.current == c ? FontWeight.bold : FontWeight.normal
                            )
                          ),
                          onTap: () async {
                            await c.loadAsCurrent(context);
                            Navigator.pop(context);
                          }
                        );
                      }
                    );
                  }
                )
              )
            ]
          )
        ),

        body: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Chat(
                  generate: (text, repPenText, promptedParticipant, blacklistWordsForRetry, continueLastMsg) async =>
                    await generate(context, text, repPenText, promptedParticipant, blacklistWordsForRetry, continueLastMsg)
                )
              )
            ]
          )
        )
      )
    );
  }
}
