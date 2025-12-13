// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/conversations.dart';
import '../models/messages.dart';
import '../pages/debug_page.dart';
import '../pages/help_page.dart';
import '../pages/settings_page.dart';
import '../pages/textual_view_page.dart';
import '../widgets/dialogs.dart';

class MainMenuItem {
  MainMenuItem(this.title, this.icon, this.onSelected);

  final String title;
  final IconData icon;
  final void Function(BuildContext context)? onSelected;
}

class MainMenu extends StatelessWidget {
  MainMenu({
    required this.onSaveCache
  });
  final void Function()? onSaveCache;

  late final List<MainMenuItem> items = [
    MainMenuItem('Settings', Icons.settings, (context) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage())
      );
    }),

    MainMenuItem('View as text', Icons.text_snippet, (context) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (context) => const TextualViewPage())
      );
    }),

    MainMenuItem('Save cache', Icons.save_alt, onSaveCache == null ? null : (context) {
      onSaveCache!();
    }),

    MainMenuItem('Duplicate', Icons.content_copy, (context) async {
      var convModel = Provider.of<ConversationsModel>(context, listen: false);
      var curConv = convModel.current;
      if(curConv == null)
        return;

      var result = await showConfirmDialogWithCheckbox(
        context: context,
        title: 'Duplicate "${curConv.name}"',
        text: 'Make a copy of this conversation?',
        checkboxText: 'Copy with messages',
        initialChecked: true
      );

      if(result == CheckboxDialogResult.no)
        return;

      var c = Conversation.create('${curConv.name} (copy)');
      c.type = curConv.type;
      var data = curConv.getCurrentData(context);
      await c.saveData(data);
      convModel.add(c);
      await ConversationsModel.saveList(context);
      await c.loadAsCurrent(context);
      if(result == CheckboxDialogResult.yesWithoutCheckbox)
        Provider.of<MessagesModel>(context, listen: false).clear();

      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage())
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
        await ConversationsModel.saveCurrentData(context);
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
      showHelpPage(context);
    }),

    MainMenuItem('Debug', Icons.bug_report, (context) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (context) => const DebugPage())
      );
    }),
  ];

  @override
  Widget build(BuildContext context) {
    var convModel = Provider.of<ConversationsModel>(context);
    return PopupMenuButton<MainMenuItem>(
      enabled: convModel.current != null,
      onSelected: (item) {
        if(item.onSelected != null)
          item.onSelected!(context);
      },
      itemBuilder: (context) {
        return items.map((item) => PopupMenuItem<MainMenuItem>(
          value: item,
          enabled: item.onSelected != null,
          child: ListTile(
            leading: Icon(item.icon),
            title: Text(item.title)
          )
        )).toList();
      }
    );
  }
}
