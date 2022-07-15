// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

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

    var text = curConv?.type == Conversation.typeChat
      ? msgModel.chatText
      : msgModel.adventureText;

    text = cfgModel.inputPreamble + text;

    return Scaffold(
      appBar: AppBar(
        title: Text(curConv?.name ?? '')
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
