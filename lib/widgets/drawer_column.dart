// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/conversations.dart';
import '../pages/help_page.dart';
import '../pages/settings_page.dart';

class DrawerColumn extends StatefulWidget {
  @override
  State<DrawerColumn> createState() => DrawerColumnState();
}

class DrawerColumnState extends State<DrawerColumn> {
  var search = '';

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
                  Provider.of<ConversationsModel>(context, listen: false)
                    ..add(c)
                    ..save();
                  c.setAsCurrent(context, data);
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
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpPage())
                  );
                }
              )
            ]
          )
        ),
        TextField(
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
              return ListView.builder(
                itemCount: convList.length,
                itemBuilder: (context, index) {
                  var c = convList[convList.length - 1 - index];
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
        )
      ]
    );
  }
}
