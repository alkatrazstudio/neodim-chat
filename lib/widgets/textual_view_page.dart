// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';

class TextualViewPage extends StatelessWidget {
  const TextualViewPage();

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    var msgModel = Provider.of<MessagesModel>(context);
    var cfgModel = Provider.of<ConfigModel>(context);

    String text;
    switch(curConv?.type)
    {
      case Conversation.typeChat:
        text = msgModel.chatText;
        break;

      case Conversation.typeAdventure:
        text = msgModel.adventureText;
        break;

      case Conversation.typeStory:
        text = msgModel.storyText;
        break;

      default:
        text = '';
    }

    text = cfgModel.inputPreamble + text;

    return Scaffold(
      appBar: AppBar(
        title: Text(curConv?.name ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to the clipboard'))
              );
            }
          )
        ]
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SelectableText(text)
        )
      )
    );
  }
}
