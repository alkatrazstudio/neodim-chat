// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:bubble/bubble.dart';
import 'package:provider/provider.dart';

import '../models/conversations.dart';
import '../widgets/dialogs.dart';
import '../models/messages.dart';

class ChatMsg extends StatelessWidget {
  const ChatMsg({
    required this.msg,
    required this.author,
    required this.isUsed,
    required this.conversation
  });

  final Message msg;
  final Participant author;
  final bool isUsed;
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    double opacity = isUsed ? 1 : 0.5;

    return Bubble(
      key: UniqueKey(), // do not cache (otherwise it keeps the old color)
      margin: const BubbleEdges.only(top: 10),
      alignment: msg.isYou ? Alignment.topRight : Alignment.topLeft,
      nip: msg.isYou ? BubbleNip.rightBottom : BubbleNip.leftBottom,
      color: author.color.withOpacity(opacity),
      borderColor: msg.isGenerated ? Colors.red.withOpacity(0.25 * opacity) : null,
      child: SelectableText(
        msg.text,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyText1?.color?.withOpacity(opacity)
        ),
        onTap: () async {
          var chatFormat = conversation.type == Conversation.typeChat || msg.authorIndex == Message.youIndex;
          var result = await showMessageDialog(context, '${author.name}:', msg.text, chatFormat);
          if(result == null)
            return;
          var messages = Provider.of<MessagesModel>(context, listen: false);
          if(result.doDelete)
            messages.remove(msg);
          else
            messages.setText(msg, result.text, true);
          await ConversationsModel.saveCurrentData(context);
        }
      )
    );
  }
}
