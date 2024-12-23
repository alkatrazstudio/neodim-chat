// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../models/api_model.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../pages/home_page.dart';

void appMain() {
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MessagesModel()),
      ChangeNotifierProvider(create: (_) => StreamMessageModel()),
      ChangeNotifierProvider(create: (_) => ConversationsModel()),
      ChangeNotifierProvider(create: (_) => ConfigModel()),
      ChangeNotifierProvider(create: (_) => ApiModel()),
      ChangeNotifierProvider(create: (_) => ApiCancelModel())
    ],
    child: App()
  ));
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Provider.of<ConversationsModel>(context, listen: false).load();

    return MaterialApp(
      home: HomePage(),
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark
      )
    );
  }
}
