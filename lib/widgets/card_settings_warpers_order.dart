// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:card_settings/card_settings.dart';
import 'package:collection/collection.dart';

import '../apis/request.dart';

class CardSettingsWarpersOrder extends FormField<List<String>> implements CardSettingsWidget {
  CardSettingsWarpersOrder({
    required List<String> initialValue,
    required void Function(List<String> newValue) onSaved
  }) : super(
    initialValue: initialValue.toList(),
    onSaved: (val) => onSaved(val ?? []),
    builder: (field) => (field as CardSettingsWarpersOrderState).subBuild(field.context)
  );

  @override
  CardSettingsWarpersOrderState createState() => CardSettingsWarpersOrderState();

  @override
  bool? get showMaterialonIOS => false;

  @override
  bool? get visible => true;
}

class CardSettingsWarpersOrderState extends FormFieldState<List<String>> {
  final List<String> order = [];

  @override
  void initState() {
    super.initState();

    order
      ..clear()
      ..addAll(widget.initialValue ?? [])
      ..where((warper) => Warper.defaultOrder.contains(warper));

    for(var warper in Warper.defaultOrder) {
      if(!order.contains(warper))
        order.add(warper);
    }
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
        children: order.mapIndexed((index, name) => ListTile(
          key: Key(name),
          title: Text(name),
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle)
          ),
        )).toList()
      )
    );
  }
}
