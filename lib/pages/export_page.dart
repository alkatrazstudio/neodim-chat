// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/conversations.dart';
import '../widgets/conversations_selector.dart';
import '../widgets/pad.dart';
import '../util/popups.dart';
import '../util/storage.dart';

class ExportPage extends StatefulWidget {
  const ExportPage();

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  var selectedConversations = <String>[];
  var allConversations = <Conversation>[];
  Future<void>? exportFuture;
  
  @override
  void initState() {
    super.initState();
    allConversations = Provider.of<ConversationsModel>(context, listen: false).conversations.toList();
    selectedConversations = allConversations.map((c) => c.id).toList();
  }

  Future<void> export(List<String> convIds) async {
    try {
      var importData = await ConversationsModel.export(context, convIds);
      var json = jsonEncode(importData);
      var bytes = utf8.encode(json);
      var uri = await Storage.saveFile('neodim.json', 'application/json', bytes);
      if(uri == null)
        return;
      Navigator.pop(context);
      showPopupMsg(context, 'Export done!');
    } catch(e) {
      Navigator.pop(context);
      showPopupMsg(context, 'Export failed: $e');
    }
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Export')
      ),
      body: Column(
        children: [
          const Text('Select the conversations to export.').padHorizontal,
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
            future: exportFuture,
            builder: (context, snapshot) {
              var isRunning = exportFuture != null && snapshot.connectionState != ConnectionState.done;
              return ElevatedButton(
                onPressed: isRunning || selectedConversations.isEmpty ? null : () {
                  setState(() {
                    exportFuture = export(selectedConversations);
                  });
                },
                child: isRunning ? const CircularProgressIndicator() : const Text('Export')
              );
            }
          ),
        ],
      ),
    );
  }
}
