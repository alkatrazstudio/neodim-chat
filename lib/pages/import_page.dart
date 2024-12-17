// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/conversations.dart';
import '../widgets/conversations_selector.dart';
import '../widgets/pad.dart';
import '../util/popups.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({
    required this.importData
  });

  final ImportData importData;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  var selectedConversations = <String>[];
  var allConversations = <Conversation>[];
  Future<void>? importFuture;

  @override
  void initState() {
    super.initState();
    allConversations = widget.importData.conversations.toList();
    selectedConversations = allConversations.map((c) => c.id).toList();
  }

  Future<void> import(List<String> convIds) async {
    try {
      var convModel = Provider.of<ConversationsModel>(context, listen: false);
      await convModel.setCurrent(context, null);
      var failedConvs = await ConversationsModel.import(context, widget.importData, convIds);
      Navigator.pop(context);
      if(failedConvs.isEmpty) {
        showPopupMsg(context, 'Import done!');
      } else {
        var failedNames = failedConvs.map((c) => c.name).join(', ');
        showPopupMsg(context, 'Import partially done. Could not import: $failedNames');
      }
    } catch(e) {
      Navigator.pop(context);
      showPopupMsg(context, 'Import failed: $e');
    }
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import')
      ),
      body: Column(
        children: [
          Text('The file date is ${DateFormat.yMMMd().format(widget.importData.createdAt)}, ${DateFormat.jm().format(widget.importData.createdAt)}.'),
          const Text('Select the conversations to import.').padHorizontal,
          Expanded(
            child: ConversationsSelector(
              allConversations: allConversations,
              selectedConversations: selectedConversations,
              onChanged: (newSelectedConversations) {
                setState(() {
                  selectedConversations = newSelectedConversations;
                });
              },
            ),
          ),
          FutureBuilder(
            future: importFuture,
            builder: (context, snapshot) {
              var isRunning = importFuture != null && snapshot.connectionState != ConnectionState.done;
              return ElevatedButton(
                onPressed: isRunning || selectedConversations.isEmpty ? null : () {
                  setState(() {
                    importFuture = import(selectedConversations);
                  });
                },
                child: isRunning ? const CircularProgressIndicator() : const Text('Import')
              );
            }
          ),
        ],
      ),
    );
  }
}
