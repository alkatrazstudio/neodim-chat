// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:bubble/bubble.dart';
import 'package:provider/provider.dart';

import '../models/conversations.dart';
import '../models/messages.dart';
import '../widgets/dialogs.dart';

class ChatMsg extends StatelessWidget {
  const ChatMsg({
    required this.msg,
    required this.author,
    required this.isUsed,
    required this.conversation,
    this.allowTap = true
  });

  final Message msg;
  final Participant author;
  final bool isUsed;
  final Conversation conversation;
  final bool allowTap;

  @override
  Widget build(BuildContext context) {
    double opacity = isUsed ? 1 : 0.5;

    return Bubble(
      key: UniqueKey(), // do not cache (otherwise it keeps the old color)
      margin: const BubbleEdges.only(top: 10),
      alignment: msg.isYou ? Alignment.topRight : Alignment.topLeft,
      nip: msg.isYou ? BubbleNip.rightBottom : BubbleNip.leftBottom,
      color: author.color.withValues(alpha: opacity),
      borderColor: msg.isGenerated ? Colors.red.withValues(alpha: 0.25 * opacity) : null,
      child: SelectableText(
        msg.text,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: opacity)
        ),
        onTap: !allowTap ? null : () async {
          var chatFormat = conversation.isChat || msg.authorIndex == Message.youIndex;
          var participants = Provider.of<MessagesModel>(context, listen: false).participants;
          var result = await showMessageDialog(
            context,
            '${author.name}:',
            msg.text,
            chatFormat,
            participants,
            msg.authorIndex
          );
          if(result == null)
            return;
          var messages = Provider.of<MessagesModel>(context, listen: false);
          switch(result.action) {
            case MessageDialogAction.edit:
              messages.setTextAndAuthorIndex(msg, result.text, result.participantIndex, true);
              break;

            case MessageDialogAction.deleteCurrent:
              messages.remove(msg);
              break;

            case MessageDialogAction.deleteCurrentAndAfter:
              messages.removeToLast(msg);
              break;
          }
          await ConversationsModel.saveCurrentData(context);
        }
      )
    );
  }
}
