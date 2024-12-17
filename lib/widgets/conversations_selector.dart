// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/conversations.dart';
import '../widgets/pad.dart';
import '../widgets/search_field.dart';

class ConversationsSelector extends StatefulWidget {
  const ConversationsSelector({
    required this.allConversations,
    required this.selectedConversations,
    required this.onChanged
  });

  final List<Conversation> allConversations;
  final List<String> selectedConversations;
  final void Function(List<String> newSelectedConversations) onChanged;

  @override
  State<ConversationsSelector> createState() => _ConversationsSelectorState();
}

class _ConversationsSelectorState extends State<ConversationsSelector> {
  var search = '';

  @override
  Widget build(context) {
    var curConvs = Provider.of<ConversationsModel>(context).conversations;
    var allConvs = ConversationsModel.filteredAndSorted(widget.allConversations, search);
    return Column(
      children: [
        SearchField(
          onChanged: (s) {
            setState(() {
              search = s;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed: () {
                var allIds = allConvs.map((c) => c.id).toList();
                widget.onChanged(allIds);
              },
              child: const Text('select all')
            ),
            ElevatedButton(
              onPressed: () {
                widget.onChanged([]);
              },
              child: const Text('select none')
            ),
          ],
        ).padHorizontal,
        Expanded(
          child: ListView.builder(
            itemCount: allConvs.length,
            itemBuilder: (context, index) {
              var conv = allConvs[index];
              var isNew = curConvs.indexWhere((c) => c.id == conv.id) == -1;
              var isChecked = widget.selectedConversations.contains(conv.id);
              var dateStr = DateFormat.yMMMd().format(conv.createdAt);
              var lastSetAsCurrentAt = conv.lastSetAsCurrentAt;
              if(lastSetAsCurrentAt != null)
                dateStr += ' - ${DateFormat.yMMMd().format(lastSetAsCurrentAt)}';
              return ListTile(
                title: Text(conv.name),
                subtitle: Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).disabledColor
                  )
                ),
                leading: Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    var newSelectedConversations = widget.selectedConversations.toList();
                    if(value ?? false)
                      newSelectedConversations.add(conv.id);
                    else
                      newSelectedConversations.remove(conv.id);
                    widget.onChanged(newSelectedConversations);
                  },
                ),
                trailing: isNew ? Icon(Icons.new_releases) : null,
                onTap: () {
                  var newSelectedConversations = widget.selectedConversations.toList();
                  if(isChecked)
                    newSelectedConversations.remove(conv.id);
                  else
                    newSelectedConversations.add(conv.id);
                  widget.onChanged(newSelectedConversations);
                },
              );
            }
          ),
        )
      ],
    );
  }
}