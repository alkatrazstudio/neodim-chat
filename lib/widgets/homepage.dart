// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../models/neodim_model.dart';
import '../util/neodim_api.dart';
import '../widgets/chat.dart';
import '../widgets/help_page.dart';
import '../widgets/main_menu.dart';
import '../widgets/settings_page.dart';

class HomePage extends StatelessWidget {
  String outputTextFromSequence(NeodimSequence s) {
    var text = s.generatedText;
    if(MessagesModel.sentenceStops.contains(s.stopString))
      text = text + s.stopString;
    return text.trim();
  }

  Future<List<String>> generate(BuildContext context, String inputText, String repPenText, Participant promptedParticipant) async {
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var neodimModel = Provider.of<NeodimModel>(context, listen: false);
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var conv = convModel.current;
    if(conv == null)
      return [];

    if(neodimModel.isApiRunning)
      return [];

    var inputMessages = msgModel.getMessagesSnapshot();

    neodimModel.setApiRunning(true);
    try {
      final api = NeodimApi(endpoint: cfgModel.apiEndpoint);

      var truncatePromptUntil = conv.type == Conversation.typeChat
        ? [MessagesModel.messageSeparator]
        : [...MessagesModel.sentenceStops, MessagesModel.actionPrompt];
      var stopStings = conv.type == Conversation.typeChat
        ? [MessagesModel.messageSeparator]
        : <String>[];
      if(cfgModel.stopOnPunctuation)
        stopStings.addAll(MessagesModel.sentenceStops);
      stopStings.add(MessagesModel.sequenceEnd);
      var request = NeodimRequest(
        prompt: inputText,
        preamble: '${cfgModel.preamble}\n\n',
        generatedTokensCount: cfgModel.generatedTokensCount,
        maxTotalTokens: cfgModel.maxTotalTokens,
        temperature: cfgModel.temperature,
        topP: (cfgModel.topP == 0 ||cfgModel.topP == 1)  ? null : cfgModel.topP,
        topK: cfgModel.topK == 0 ? null : cfgModel.topK,
        tfs: (cfgModel.tfs == 0 || cfgModel.tfs == 1) ? null : cfgModel.tfs,
        typical: (cfgModel.typical == 0 || cfgModel.typical == 1) ? null : cfgModel.typical,
        topA: cfgModel.topA == 0 ? null : cfgModel.topA,
        warpersOrder: cfgModel.warpersOrder,
        repetitionPenalty: cfgModel.repetitionPenalty,
        repetitionPenaltyRange: cfgModel.repetitionPenaltyRange,
        repetitionPenaltySlope: cfgModel.repetitionPenaltySlope,
        repetitionPenaltyIncludePreamble: cfgModel.repetitionPenaltyIncludePreamble,
        repetitionPenaltyIncludeGenerated: cfgModel.repetitionPenaltyIncludeGenerated,
        repetitionPenaltyTruncateToInput: cfgModel.repetitionPenaltyTruncateToInput,
        repetitionPenaltyPrompt: repPenText,
        sequencesCount: 1 + cfgModel.extraRetries,
        stopStrings: stopStings,
        truncatePromptUntil: truncatePromptUntil
      );
      neodimModel.setRequest(request);
      var response = await api.run(request);
      neodimModel.setResponse(response);
      neodimModel.setApiRunning(false);
      convModel.updateUsedMessagesCount(
        response.usedPrompt, promptedParticipant, msgModel, inputMessages);
      return response.sequences.map(outputTextFromSequence).toList();
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
                          MaterialPageRoute(builder: (context) => SettingsPage())
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
                  generate: (text, repPenText, promptedParticipant) async =>
                    await generate(context, text, repPenText, promptedParticipant)
                )
              )
            ]
          )
        )
      )
    );
  }
}
