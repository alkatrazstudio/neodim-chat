// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/conversations.dart';
import '../models/messages.dart';
import '../widgets/dialogs.dart';
import '../widgets/help_page.dart';
import '../widgets/settings_page.dart';

class MainMenuItem {
  MainMenuItem(this.title, this.icon, this.onSelected);

  final String title;
  final IconData icon;
  final void Function(BuildContext context) onSelected;
}

class MainMenu extends StatelessWidget {
  final List<MainMenuItem> items = [
    MainMenuItem('Settings', Icons.settings, (context) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (context) => SettingsPage())
      );
    }),

    MainMenuItem('Clear', Icons.clear_all, (context) async {
      var curConv = Provider.of<ConversationsModel>(context, listen: false).current;
      if(curConv == null)
        return;
      var msgModel = Provider.of<MessagesModel>(context, listen: false);

      if(await showConfirmDialog(
        context, 'Clear "${curConv.name}"',
        'Remove all messages from this conversation?')
      ) {
        msgModel.clear();
        await curConv.saveCurrentData(context);
      }
    }),

    MainMenuItem('Delete', Icons.delete_forever, (context) async {
      var curConv = Provider.of<ConversationsModel>(context, listen: false).current;
      if(curConv == null)
        return;

      if(await showConfirmDialog(
        context, 'Removing "${curConv.name}"',
        'Remove this conversation?')
      ) {
        await ConversationsModel.delete(context, curConv);
      }
    }),

    MainMenuItem('Help', Icons.help, (context) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (context) => const HelpPage())
      );
    }),
  ];

  @override
  Widget build(BuildContext context) {
    var convModel = Provider.of<ConversationsModel>(context);
    return PopupMenuButton<MainMenuItem>(
      enabled: convModel.current != null,
      onSelected: (item) {
        item.onSelected(context);
      },
      itemBuilder: (context) {
        return items.map((item) => PopupMenuItem<MainMenuItem>(
          value: item,
          child: ListTile(
            leading: Icon(item.icon),
            title: Text(item.title)
          )
        )).toList();
      }
    );
  }
}
