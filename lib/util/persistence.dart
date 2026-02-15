// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2026, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter_background/flutter_background.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> startPersistence() async {
  try {
    if(!await WakelockPlus.enabled)
      await WakelockPlus.enable();
  } catch(_) {
  }
  try {
    if(!FlutterBackground.isBackgroundExecutionEnabled) {
      var androidConfig = const FlutterBackgroundAndroidConfig(
        notificationTitle: 'Neodim Chat',
        notificationText: 'The inference is in progress',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(
          name: 'ic_notification'
        )
      );
      await FlutterBackground.initialize(androidConfig: androidConfig);
      await FlutterBackground.enableBackgroundExecution();
    }
  } catch(_) {
  }
}

Future<void> stopPersistence() async {
  try {
    if(await WakelockPlus.enabled)
      await WakelockPlus.disable();
  } catch(_) {
  }
  try {
    if(FlutterBackground.isBackgroundExecutionEnabled)
      await FlutterBackground.disableBackgroundExecution();
  } catch(_) {
  }
}
