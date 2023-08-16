// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../models/neodim_model.dart';
import '../pages/help_page.dart';
import '../pages/settings_page.dart';
import '../util/neodim_api.dart';
import '../widgets/chat.dart';
import '../widgets/main_menu.dart';

class HomePage extends StatelessWidget {
  static const String requiredServerVersion = '>=0.13';

  String outputTextFromSequence(NeodimSequence s) {
    var text = s.generatedText;
    if(s.stopString == MessagesModel.sentenceStopsRx)
      text = text + s.stopStringMatch;
    return text.trim();
  }

  NeodimRequest? getRequest(
    BuildContext context,
    String inputText, String?
    repPenText, List<String>?
    participantNames,
    Set<String>? blacklistWordsForRetry
  ) {
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var conv = convModel.current;
    if(conv == null)
      return null;

    var cfgModel = Provider.of<ConfigModel>(context, listen: false);

    List<String> truncatePromptUntil;
    List<String> stopStrings;
    List<String>? wordsWhitelist;

    var stopStringsType = StopStringsType.string;
    int sequencesCount;
    int? noRepeatNGramSize;
    if(participantNames != null) {
      truncatePromptUntil = [MessagesModel.messageSeparator];
      stopStrings = [MessagesModel.chatPromptSeparator];
      sequencesCount = 1;
      wordsWhitelist = List.from(participantNames);
      wordsWhitelist.add(MessagesModel.chatPromptSeparator);
      noRepeatNGramSize = null;
    } else {
      switch(conv.type)
      {
        case Conversation.typeChat:
        case Conversation.typeGroupChat:
          truncatePromptUntil = [MessagesModel.messageSeparator];
          stopStrings = [MessagesModel.messageSeparator];
          break;

        case Conversation.typeAdventure:
          truncatePromptUntil = [...MessagesModel.sentenceStops, MessagesModel.actionPrompt];
          stopStrings = [MessagesModel.actionPrompt];
          break;

        case Conversation.typeStory:
          truncatePromptUntil = MessagesModel.sentenceStops;
          stopStrings = [];
          break;

        default:
          return null;
      }
      if(cfgModel.stopOnPunctuation) {
        stopStrings = stopStrings.map(RegExp.escape).toList();
        stopStrings.add(MessagesModel.sentenceStopsRx);
        stopStringsType = StopStringsType.regex;
      }
      sequencesCount = 1 + cfgModel.extraRetries;
      noRepeatNGramSize = cfgModel.noRepeatNGramSize;
    }

    List<String> wordsBlacklist = blacklistWordsForRetry?.toList() ?? [];

    var request = NeodimRequest(
      prompt: inputText,
      preamble: cfgModel.inputPreamble,
      generatedTokensCount: cfgModel.generatedTokensCount,
      maxTotalTokens: cfgModel.maxTotalTokens,
      temperature: cfgModel.temperature,
      topP: (cfgModel.topP == 0 ||cfgModel.topP == 1)  ? null : cfgModel.topP,
      topK: cfgModel.topK == 0 ? null : cfgModel.topK,
      tfs: (cfgModel.tfs == 0 || cfgModel.tfs == 1) ? null : cfgModel.tfs,
      typical: (cfgModel.typical == 0 || cfgModel.typical == 1) ? null : cfgModel.typical,
      topA: cfgModel.topA == 0 ? null : cfgModel.topA,
      penaltyAlpha: cfgModel.penaltyAlpha == 0 ? null : cfgModel.penaltyAlpha,
      warpersOrder: cfgModel.warpersOrder,
      repetitionPenalty: cfgModel.repetitionPenalty,
      repetitionPenaltyRange: cfgModel.repetitionPenaltyRange,
      repetitionPenaltySlope: cfgModel.repetitionPenaltySlope,
      repetitionPenaltyIncludePreamble: cfgModel.repetitionPenaltyIncludePreamble,
      repetitionPenaltyIncludeGenerated: cfgModel.repetitionPenaltyIncludeGenerated,
      repetitionPenaltyTruncateToInput: cfgModel.repetitionPenaltyTruncateToInput,
      repetitionPenaltyPrompt: repPenText,
      sequencesCount: sequencesCount,
      stopStrings: stopStrings,
      stopStringsType: stopStringsType,
      truncatePromptUntil: truncatePromptUntil,
      wordsWhitelist: wordsWhitelist,
      wordsBlacklist: wordsBlacklist,
      wordsBlacklistAtStart: ['\n', '<'], // typical tokens that may end the inference
      noRepeatNGramSize: noRepeatNGramSize,
      requiredServerVersion: requiredServerVersion
    );
    return request;
  }

  Future<String?> getNextGroupParticipantName(
    BuildContext context,
    String inputText,
    String? repPenText,
    List<String> participantNames
  ) async {
    if(participantNames.length == 1)
      return participantNames[0];
    var request = getRequest(context, inputText, repPenText, participantNames, null);
    if(request == null)
      return null;
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    final api = NeodimApi(endpoint: cfgModel.apiEndpoint);
    var response = await api.run(request);
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
    var neodimModel = Provider.of<NeodimModel>(context, listen: false);
    if(neodimModel.isApiRunning)
      return [];

    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var conv = convModel.current;
    if(conv == null)
      return [];

    var inputMessages = msgModel.getMessagesSnapshot();
    neodimModel.setApiRunning(true);
    try {
      var addedPromptSuffix = '';
      var promptedParticipantIndex = msgModel.participants.indexOf(promptedParticipant);
      if(conv.type == Conversation.typeGroupChat && promptedParticipantIndex != Message.youIndex) {
        var participantNames = msgModel.getGroupParticipantNames(false);
        var participantName = await getNextGroupParticipantName(context, inputText, repPenText, participantNames);
        if(participantName == null)
          throw Exception('Cannot get the correct participant name');
        addedPromptSuffix = '$participantName${MessagesModel.chatPromptSeparator}';
        inputText += addedPromptSuffix;
        addedPromptSuffix += ' ';
      }

      var request = getRequest(context, inputText, repPenText, null, blacklistWordsForRetry);
      if(request == null)
        return [];
      neodimModel.setRequest(request);
      final api = NeodimApi(endpoint: cfgModel.apiEndpoint);
      var response = await api.run(request);
      neodimModel.setResponse(response);
      neodimModel.setApiRunning(false);
      var combineLines = conv.type == Conversation.typeChat ? CombineChatLinesType.no : cfgModel.combineChatLines;
      convModel.updateUsedMessagesCount(
        response.usedPrompt, promptedParticipant, msgModel, inputMessages, combineLines, addedPromptSuffix, continueLastMsg);
      var lines = response.sequences.map(outputTextFromSequence).toList();
      lines = lines.map((line) => addedPromptSuffix + line).toList();
      return lines;
    } catch (e) {
      neodimModel.setApiRunning(false);
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
