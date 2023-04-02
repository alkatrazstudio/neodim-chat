// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../models/messages.dart';

class MessageDialogResult {
  const MessageDialogResult({
    required this.participantIndex,
    required this.text,
    required this.doDelete
  });

  final int participantIndex;
  final String text;
  final bool doDelete;
}

Future<MessageDialogResult?> showMessageDialog(
  BuildContext context,
  String title,
  String initialText,
  bool chatFormat,
  List<Participant> participants,
  int participantIndex
) async {
  var doFormat = true;
  var newParticipantIndex = participantIndex;

  void submitMsg(BuildContext ctx, String text) {
    text = text.trim();
    if(doFormat)
      text = Message.format(text, chatFormat);
    if(text.isEmpty || (text == initialText && newParticipantIndex == participantIndex))
      Navigator.of(context).pop();
    else
      Navigator.of(context).pop(MessageDialogResult(
        text: text,
        participantIndex: newParticipantIndex,
        doDelete: false
      ));
  }

  void deleteMsg(BuildContext ctx) {
    Navigator.of(context).pop(const MessageDialogResult(
      text: '',
      participantIndex: Message.noneIndex,
      doDelete: true
    ));
  }

  return showDialog<MessageDialogResult>(
    context: context,
    builder: (BuildContext context) {
      final inputController = TextEditingController();
      inputController.text = initialText;

      return AlertDialog(
        content: StatefulBuilder(builder: (context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  DropdownMenu<int>(
                    dropdownMenuEntries: participants.mapIndexed(
                      (i, p) => DropdownMenuEntry<int>(
                        value: i,
                        label: p.name,
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
                  )
                ],
              ),

              TextField(
                minLines: 1,
                maxLines: 5,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                controller: inputController,
                textInputAction: TextInputAction.go,
                onSubmitted: (text) {
                  submitMsg(context, text);
                }
              ),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Auto-format'),
                      value: doFormat,
                      onChanged: (newVal) => setState((){doFormat = newVal ?? false;}),
                      controlAffinity: ListTileControlAffinity.leading
                    )
                  )
                ]
              ),
              Padding(
                padding: const EdgeInsets.only(top: 35),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: const Text('DELETE'),
                      onPressed: () {
                        deleteMsg(context);
                      }
                    ),
                    TextButton(
                      child: const Text('OK'),
                      onPressed: () {
                        submitMsg(context, inputController.text);
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
