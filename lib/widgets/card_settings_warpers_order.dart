// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:card_settings/card_settings.dart';
import 'package:change_case/change_case.dart';
import 'package:collection/collection.dart';

import '../models/config.dart';

class CardSettingsWarpersOrder extends FormField<List<Warper>> implements CardSettingsWidget {
  CardSettingsWarpersOrder({
    required this.supportedWarpers,
    required List<Warper> initialValue,
    required void Function(List<Warper> newValue) onSaved
  }) : super(
    initialValue: initialValue,
    onSaved: (val) => onSaved(val ?? []),
    builder: (field) => (field as CardSettingsWarpersOrderState).subBuild(field.context)
  );

  final List<Warper> supportedWarpers;

  @override
  CardSettingsWarpersOrderState createState() => CardSettingsWarpersOrderState(supportedWarpers: supportedWarpers);

  @override
  bool? get showMaterialonIOS => false;

  @override
  bool? get visible => true;
}

class CardSettingsWarpersOrderState extends FormFieldState<List<Warper>> {
  CardSettingsWarpersOrderState({
    required this.supportedWarpers
  });

  final List<Warper> order = [];
  final List<Warper> supportedWarpers;

  @override
  void initState() {
    super.initState();

    order.clear();
    order.addAll(widget.initialValue ?? []);

    for(var warper in Warper.values) {
      if(!order.contains(warper))
        order.add(warper);
    }

    order.removeWhere((warper) => !supportedWarpers.contains(warper));
  }

  Widget subBuild(BuildContext context) {
    return CardSettingsField(
      labelAlign: TextAlign.left,
      fieldPadding: null,
      requiredIndicator: null,
      label: 'Warpers order\n(drag by the handles to reorder)',
      content:  ReorderableListView(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        onReorder: (int oldIndex, int newIndex) {
          if(oldIndex < newIndex)
            newIndex -= 1;
          var item = order.removeAt(oldIndex);
          order.insert(newIndex, item);
          didChange(order);
        },
        children: order.mapIndexed((index, warper) => ListTile(
          key: ValueKey(warper),
          title: Text(warper.name.toNoCase()),
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle)
          ),
        )).toList()
      )
    );
  }
}
