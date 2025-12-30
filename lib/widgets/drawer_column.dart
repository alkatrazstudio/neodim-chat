// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../models/api_model.dart';
import '../models/conversations.dart';
import '../pages/export_page.dart';
import '../pages/help_page.dart';
import '../pages/import_page.dart';
import '../pages/settings_page.dart';
import '../util/popups.dart';

class DrawerColumn extends StatefulWidget {
  @override
  State<DrawerColumn> createState() => DrawerColumnState();
}

class DrawerColumnState extends State<DrawerColumn> {
  static var _scrollPos = 0.0;
  var scrollController = ScrollController(initialScrollOffset: _scrollPos);
  static var textController = TextEditingController();
  var search = textController.text;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() => _scrollPos = scrollController.offset);
  }

  @override
  Widget build(context) {
    return Column(
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
                  Provider.of<ConversationsModel>(context, listen: false).add(c);
                  ConversationsModel.saveList(context);
                  await c.setAsCurrent(context, data);
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage())
                  );
                },
                child: const Text('New conversation')
              ),
              ElevatedButton(
                child: const Text('Help'),
                onPressed: () => showHelpPage(context)
              )
            ]
          )
        ),
        TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Search...',
            contentPadding: EdgeInsets.only(left: 5, top: 15)
          ),
          onChanged: (s) {
            setState(() {
              search = s;
            });
          },
        ),
        Expanded(
          child: Consumer<ConversationsModel>(
            builder: (context, convModel, child) {
              var searchFilter = search.trim().toUpperCase();
              var convList = searchFilter.isEmpty
                ? convModel.conversations
                : convModel.conversations.where((c) => c.name.toUpperCase().contains(searchFilter)).toList();
              convList = convList.sorted((a, b) {
                var aDate = a.lastSetAsCurrentAt ?? a.createdAt;
                var bDate = b.lastSetAsCurrentAt ?? b.createdAt;
                return bDate.compareTo(aDate);
              });
              return ListView.builder(
                controller: scrollController,
                itemCount: convList.length,
                itemBuilder: (context, index) {
                  var c = convList[index];
                  return ListTile(
                    title: Text(
                      c.name,
                      style: TextStyle(
                        fontWeight: convModel.current == c ? FontWeight.bold : FontWeight.normal
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
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (context) => const ExportPage())
                );
              },
              child: const Text('Export')
            ),
            Consumer<ApiModel>(
              builder: (context, apiModel, child) {
                return ElevatedButton(
                  onPressed: apiModel.isApiRunning ? null : () async {
                    try {
                      var result = await FilePicker.platform.pickFiles(
                        allowMultiple: true,
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                        withData: true,
                      );
                      var bytes = result?.files.single.bytes;
                      if(bytes == null)
                        return;
                      var json = utf8.decode(bytes);
                      var jsonObj = jsonDecode(json) as Map<String, dynamic>;
                      var importData = ImportData.fromJson(jsonObj);
                      Navigator.pop(context);
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (context) => ImportPage(importData: importData))
                      );
                    } catch(e) {
                      Navigator.pop(context);
                      showPopupMsg(context, 'Import failed: $e');
                    }
                  },
                  child: const Text('Import')
                );
              }
            )
          ]
        )
      ]
    );
  }
}
