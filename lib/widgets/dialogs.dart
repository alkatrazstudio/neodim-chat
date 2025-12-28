// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:provider/provider.dart';

import '../models/messages.dart';

enum MessageDialogAction {
  edit,
  deleteCurrent,
  deleteCurrentAndAfter,
  setAsContextStart
}

class MessageDialogResult {
  const MessageDialogResult({
    required this.participantIndex,
    required this.text,
    required this.action
  });

  final int participantIndex;
  final String text;
  final MessageDialogAction action;
}

Future<MessageDialogResult?> showMessageDialog(
  BuildContext context,
  String title,
  Message msg,
  bool chatFormat,
  List<Participant> participants
) async {
  var doFormat = true;
  var newParticipantIndex = msg.authorIndex;
  var isContextStart = Provider.of<MessagesModel>(context, listen: false).isContextStart(msg);

  void submitMsg(BuildContext ctx, String text, bool addPeriodAtEnd) {
    text = text.trim();
    if(doFormat)
      text = Message.format(text, forChat: chatFormat, addPeriodAtEnd: addPeriodAtEnd);
    if(text.isEmpty || (text == msg.text && newParticipantIndex == msg.authorIndex)) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop(MessageDialogResult(
        text: text,
        participantIndex: newParticipantIndex,
        action: MessageDialogAction.edit
      ));
    }
  }

  void nonEditAction(BuildContext ctx, MessageDialogAction action) {
    if(!context.mounted)
      return;
    Navigator.of(context).pop(MessageDialogResult(
      text: '',
      participantIndex: Message.noneIndex,
      action: action
    ));
  }

  return showDialog<MessageDialogResult>(
    context: context,
    builder: (BuildContext context) {
      final inputController = TextEditingController();
      inputController.text = msg.text;

      var rowKey = GlobalKey();
      var widthFuture = Completer<double>();

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widthFuture.complete(rowKey.currentContext?.size?.width ?? 100));

      return AlertDialog(
        content: StatefulBuilder(builder: (context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                key: rowKey,
                mainAxisSize: MainAxisSize.max,
                children: [
                  FutureBuilder(future: widthFuture.future, builder: (context, snapshot) {
                    var dialogWidth = snapshot.data;
                    if(dialogWidth == null)
                      return const SizedBox.shrink();
                    return DropdownMenu<int>(
                      width: dialogWidth,
                      dropdownMenuEntries: participants.mapIndexed(
                        (i, p) => DropdownMenuEntry<int>(
                          value: i,
                          label: p.name
                        )
                      ).toList(),
                      enableFilter: false,
                      enableSearch: false,
                      initialSelection: newParticipantIndex,
                      onSelected: (newIndex) {
                        if(newIndex == null)
                          return;
                        setState((){
                          newParticipantIndex = newIndex;
                        });
                      }
                    );
                  })
                ],
              ),

              TextField(
                minLines: 1,
                maxLines: 5,
                autofocus: true,
                controller: inputController,
                textInputAction: TextInputAction.go,
                onSubmitted: (text) {
                  submitMsg(context, text, true);
                }
              ),
              CheckboxListTile(
                title: const Text('Auto-format'),
                value: doFormat,
                onChanged: (newVal) => setState((){doFormat = newVal ?? false;}),
                controlAffinity: ListTileControlAffinity.leading
              ),

              Padding(
                padding: const EdgeInsets.only(top: 35),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MenuAnchor(
                      menuChildren: [
                        MenuItemButton(
                          child: const Text('Delete'),
                          onPressed: () {
                            nonEditAction(context, MessageDialogAction.deleteCurrent);
                          },
                        ),
                        MenuItemButton(
                          child: const Text('Delete this and below'),
                          onPressed: () async {
                            var delConfirmed = await showConfirmDialog(
                              context, 'Delete this and below?', 'Delete this message and everything after it?');
                            if(delConfirmed)
                              nonEditAction(context, MessageDialogAction.deleteCurrentAndAfter);
                          },
                        ),
                      ],
                      style: const MenuStyle(
                        alignment: Alignment.topLeft
                      ),
                      builder: (context, controller, child) {
                        return IconButton(
                          onPressed: () {
                            controller.open();
                          },
                          icon: const Icon(Icons.delete_forever)
                        );
                      },
                    ),
                    ElevatedButton(
                      onPressed: isContextStart ? null : () async {
                        nonEditAction(context, MessageDialogAction.setAsContextStart);
                      },
                      child: const Text('context start')
                    ),
                    TextButton(
                      child: const Text('OK'),
                      onPressed: () {
                        submitMsg(context, inputController.text, true);
                      },
                      onLongPress: () {
                        submitMsg(context, inputController.text, false);
                      }
                    )
                  ]
                )
              )
            ]
          );
        })
      );
    }
  );
}

Future<bool> showConfirmDialog(
  BuildContext context,
  String title,
  String text
) async {
  return (await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(context).pop()
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.of(context).pop(true)
          )
        ]
      );
    }
  )) ?? false;
}

enum CheckboxDialogResult {
  no,
  yesWithCheckbox,
  yesWithoutCheckbox
}

Future<CheckboxDialogResult> showConfirmDialogWithCheckbox({
  required BuildContext context,
  required String title,
  required String text,
  required String checkboxText,
  bool initialChecked = false
}) async {
  var isChecked = initialChecked;

  return (await showDialog<CheckboxDialogResult>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: StatefulBuilder(builder: (context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text),
              CheckboxListTile(
                  title: Text(checkboxText),
                  value: isChecked,
                  onChanged: (val) => setState(() {isChecked = val ?? false;}),
                  controlAffinity: ListTileControlAffinity.leading

              )
            ]
          );
        }),
        actions: [
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(context).pop()
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.of(context).pop(
              isChecked
                ? CheckboxDialogResult.yesWithCheckbox
                : CheckboxDialogResult.yesWithoutCheckbox
            )
          )
        ]
      );
    }
  )) ?? CheckboxDialogResult.no;
}
