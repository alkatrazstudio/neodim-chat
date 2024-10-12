// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:change_case/change_case.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_extra_fields/form_builder_extra_fields.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:provider/provider.dart';

import '../apis/llama_cpp.dart';
import '../apis/neodim.dart';
import '../apis/request.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../pages/help_page.dart';
import '../widgets/pad.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage();

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static required<T>() => FormBuilderValidators.required<T>(errorText: 'Required');
}

class _SettingsPageState extends State<SettingsPage> {
  var formKey = GlobalKey<FormBuilderState>();

  ConversationType? convType;
  ApiType? apiType;
  TemperatureMode? temperatureMode;
  MirostatVersion? mirostat;

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    if(curConv == null)
      return const SizedBox.shrink();

    convType ??= curConv.type;
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    apiType ??= cfgModel.apiType;
    temperatureMode ??= cfgModel.temperatureMode;
    mirostat ??= cfgModel.mirostat;
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(curConv.name),
        actions: [
          IconButton(
            onPressed: () => showHelpPage(context),
            icon: const Icon(Icons.help)
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () async {
          if(!await save(curConv, convModel, cfgModel, msgModel))
            return;
          Navigator.of(context).pop();
        }
      ),
      body: SingleChildScrollView(
        child: FormBuilder(
          key: formKey,
          autovalidateMode: AutovalidateMode.always,
          child: Column(
            children: [
              ...conversationSection(msgModel, convModel, curConv, cfgModel),
              ...participantsSection(msgModel, curConv),
              ...serverSection(cfgModel),
              ...samplingSection(cfgModel),
              ...penaltiesSection(cfgModel),
              ...controlSection(cfgModel),
              const SizedBox(height: 65)
            ]
          )
        )
      )
    );
  }

  Future<bool> save(
    Conversation curConv,
    ConversationsModel convModel,
    ConfigModel cfgModel,
    MessagesModel msgModel
  ) async {
    var state = formKey.currentState;
    if(state == null)
      return false;
    if(!state.validate())
      return false;

    var cfgJsonToSave = state.fields.map((key, field) {
      return MapEntry(key, field.transformedValue);
    });
    var newCfgJson = cfgModel.toJson();
    newCfgJson.addAll(cfgJsonToSave);
    var config = ConfigModel.fromJson(cfgJsonToSave);

    convModel.setName(curConv, cfgJsonToSave['name']);
    convModel.setType(curConv, ConversationType.values.byName(cfgJsonToSave['type']));
    await ConversationsModel.saveList(context);

    for(var authorIndex = 0; authorIndex < msgModel.participants.length; authorIndex++) {
      if(!newCfgJson.containsKey('authorName-$authorIndex'))
        continue;
      msgModel.setAuthorName(authorIndex, newCfgJson['authorName-$authorIndex']);
      msgModel.setAuthorColor(authorIndex, newCfgJson['authorColor-$authorIndex']);
    }

    cfgModel.load(config);
    var curData = curConv.getCurrentData(context);
    await curConv.saveData(ConversationData(
      msgModel: curData.msgModel,
      config: config
    ));

    return true;
  }

  List<Widget> conversationSection(
    MessagesModel msgModel,
    ConversationsModel convModel,
    Conversation curConv,
    ConfigModel cfgModel
  ) {
    var typeEditable = msgModel.messages.isEmpty;

    return [
      const SettingsHeader('Conversation'),
      SettingContainer(
        label: 'Name',
        child: FormBuilderTextField(
          name: 'name',
          initialValue: curConv.name,
          valueTransformer: (s) => s?.trim(),
          validator: FormBuilderValidators.compose([
            SettingsPage.required(),
            FormBuilderValidators.maxLength(32, errorText: '32 symbols max')
          ])
        )
      ),
      SettingContainer(
        label: typeEditable ? 'Type' : 'Type (cannot change if messages are present)',
        child: FormBuilderDropdown(
          name: 'type',
          initialValue: curConv.type,
          items: enumToDropdown(ConversationType.values),
          valueTransformer: (v) => v?.name,
          enabled: typeEditable,
          onChanged: (type) => setState(() => convType = type)
        ),
      ),
      SettingContainer(
        label: 'Preamble',
        vertical: true,
        child: FormBuilderTextField(
          name: 'preamble',
          minLines: 5,
          maxLines: 10,
          initialValue: cfgModel.preamble,
          valueTransformer: (s) => s?.trim(),
        )
      ),
    ];
  }

  List<Widget> participantsSection(MessagesModel msgModel, Conversation curConv) {
    return [
      const SettingsHeader('Participants'),
      for(var authorIndex = 0; authorIndex < msgModel.participants.length; authorIndex++)
        ...[
          if(convType != ConversationType.story || authorIndex != Message.youIndex)
            SettingContainer(
              label: getPersonNameLabel(authorIndex),
              vertical: authorIndex != Message.youIndex && convType == ConversationType.groupChat,
              child: FormBuilderTextField(
                key: ValueKey('authorName-$authorIndex'),
                name: 'authorName-$authorIndex',
                initialValue: msgModel.participants[authorIndex].name,
                valueTransformer: (s) => s?.trim(),
                minLines: 1,
                maxLines: authorIndex != Message.youIndex && convType == ConversationType.groupChat ? 5 : 1,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
                validator: FormBuilderValidators.compose([
                  SettingsPage.required()
                ]),
                textInputAction: TextInputAction.done
              )
            ),
          if(convType != ConversationType.story || authorIndex != Message.youIndex)
            SettingContainer(
              label: getPersonColorLabel(authorIndex),
              child: FormBuilderColorPickerField(
                key: ValueKey('authorColor-$authorIndex'),
                name: 'authorColor-$authorIndex',
                initialValue: msgModel.participants[authorIndex].color
              )
            ),
        ]
    ];
  }

  List<Widget> serverSection(ConfigModel cfgModel) {
    return [
      const SettingsHeader('Server'),
      SettingContainer(
        label: 'API type',
        child: FormBuilderDropdown(
          name: 'apiType',
          initialValue: cfgModel.apiType,
          items: enumToDropdown(ApiType.values),
          valueTransformer: (v) => v?.name,
          onChanged: (type) => setState(() => apiType = type)
        ),
      ),
      SettingContainer(
        label: 'Endpoint',
        child: FormBuilderTextField(
          name: 'apiEndpoint',
          initialValue: cfgModel.apiEndpoint,
          valueTransformer: (s) => s?.trim(),
          validator: FormBuilderValidators.compose([
            SettingsPage.required(),
            FormBuilderValidators.maxLength(1024, errorText: '1024 symbols max')
          ]),
        )
      ),
      if(apiType == ApiType.llamaCpp)
        SettingContainer(
          label: 'Stream the response',
          child: FormBuilderCheckbox(
            name: 'streamResponse',
            initialValue: cfgModel.streamResponse,
            title: const SizedBox.shrink()
          )
        )
    ];
  }

  List<Widget> samplingSection(ConfigModel cfgModel) {
    var supportedWarpers = switch(apiType) {
      ApiType.neodim => NeodimRequest.supportedWarpers,
      ApiType.llamaCpp => LlamaCppRequest.supportedWarpers,
      _ => <Warper>[]
    };

    return [
      const SettingsHeader('Sampling'),

      FieldInt(
        label: 'Generated tokens',
        name: 'generatedTokensCount',
        initialValue: cfgModel.generatedTokensCount,
        allowZero: false
      ),
      if(apiType == ApiType.neodim)
        FieldInt(
          label: 'Max total tokens',
          name: 'maxTotalTokens',
          initialValue: cfgModel.maxTotalTokens,
          allowZero: false
        ),
      if(apiType == ApiType.llamaCpp)
        SettingContainer(
          label: 'Temperature mode',
          child: FormBuilderDropdown(
            name: 'temperatureMode',
            initialValue: cfgModel.temperatureMode,
            items: enumToDropdown(TemperatureMode.values),
            valueTransformer: (v) => v?.name,
            onChanged: (mode) => setState(() => temperatureMode = mode)
          ),
        ),
      if(temperatureMode == TemperatureMode.static || apiType != ApiType.llamaCpp)
        FieldFloat(
          label: 'Temperature',
          name: 'temperature',
          initialValue: cfgModel.temperature,
          allowZero: false
        ),
      if(temperatureMode == TemperatureMode.dynamic && apiType == ApiType.llamaCpp)
        FieldFloat(
          label: 'Min. temperature',
          name: 'temperature',
          initialValue: cfgModel.temperature,
          allowZero: false
        ),
      if(temperatureMode == TemperatureMode.dynamic && apiType == ApiType.llamaCpp)
        FieldFloat(
          label: 'Max. temperature',
          name: 'dynaTempHigh',
          initialValue: cfgModel.dynaTempHigh,
          allowZero: false
        ),
      if(temperatureMode == TemperatureMode.dynamic && apiType == ApiType.llamaCpp)
        FieldFloat(
          label: 'Dynamic temperature exponent',
          name: 'dynaTempExponent',
          initialValue: cfgModel.dynaTempExponent,
          allowZero: false
        ),
      FieldInt(
        label: 'Top K',
        name: 'topK',
        initialValue: cfgModel.topK
      ),
      FieldFloat(
        label: 'Top P (nucleus sampling)',
        name: 'topP',
        initialValue: cfgModel.topP,
        normalized: true
      ),
      if(apiType == ApiType.llamaCpp)
        FieldFloat(
          label: 'Min P',
          name: 'minP',
          initialValue: cfgModel.minP,
          normalized: true
        ),
      FieldFloat(
        label: 'Tail-free sampling',
        name: 'tfs',
        initialValue: cfgModel.tfs,
        normalized: true
      ),
      FieldFloat(
        label: 'Typical sampling',
        name: 'typical',
        initialValue: cfgModel.typical,
        normalized: true
      ),
      if(apiType == ApiType.neodim)
        FieldFloat(
          label: 'Top A',
          name: 'topA',
          initialValue: cfgModel.topA,
          normalized: true
        ),
      if(apiType == ApiType.neodim)
        FieldFloat(
          label: 'Penalty Alpha',
          name: 'penaltyAlpha',
          initialValue: cfgModel.penaltyAlpha,
          normalized: true
        ),
      if(apiType == ApiType.llamaCpp)
        SettingContainer(
          label: 'Mirostat',
          child: FormBuilderDropdown(
            name: 'mirostat',
            initialValue: cfgModel.mirostat,
            items: enumToDropdown(MirostatVersion.values),
            valueTransformer: (v) => v?.name,
            onChanged: (version) => setState(() => mirostat = version)
          ),
        ),
      if(apiType == ApiType.llamaCpp && mirostat != MirostatVersion.none)
        FieldFloat(
          label: 'Mirostat Tau',
          name: 'mirostatTau',
          initialValue: cfgModel.mirostatTau,
          allowZero: false,
        ),
      if(apiType == ApiType.llamaCpp && mirostat != MirostatVersion.none)
        FieldFloat(
          label: 'Mirostat Eta',
          name: 'mirostatEta',
          initialValue: cfgModel.mirostatEta,
          normalized: true,
        ),
      FieldWarpers(
        supportedWarpers: supportedWarpers,
        initialValue: cfgModel.warpersOrder,
      )
    ];
  }

  List<Widget> penaltiesSection(ConfigModel cfgModel) {
    return [
      const SettingsHeader('Penalties'),

      FieldFloat(
        label: 'Repetition penalty',
        name: 'repetitionPenalty',
        initialValue: cfgModel.repetitionPenalty
      ),
      if(apiType == ApiType.llamaCpp)
        FieldFloat(
          label: 'Frequency penalty',
          name: 'frequencyPenalty',
          initialValue: cfgModel.frequencyPenalty
        ),
      if(apiType == ApiType.llamaCpp)
        FieldFloat(
          label: 'Presence penalty',
          name: 'presencePenalty',
          initialValue: cfgModel.presencePenalty
        ),
      FieldInt(
        label: 'Penalty range',
        name: 'repetitionPenaltyRange',
        initialValue: cfgModel.repetitionPenaltyRange
      ),
      if(apiType == ApiType.neodim)
        FieldFloat(
          label: 'Penalty slope',
          name: 'repetitionPenaltySlope',
          initialValue: cfgModel.repetitionPenaltySlope,
        ),
      SettingContainer(
        label: 'Include preamble in the penalty range',
        child: FormBuilderCheckbox(
          name: 'repetitionPenaltyIncludePreamble',
          initialValue: cfgModel.repetitionPenaltyIncludePreamble,
          title: const SizedBox.shrink()
        )
      ),
      if(apiType == ApiType.neodim)
        SettingContainer(
          label: 'Include generated text in the penalty range',
          child: FormBuilderDropdown(
            name: 'repetitionPenaltyIncludeGenerated',
            initialValue: cfgModel.repetitionPenaltyIncludeGenerated,
            items: enumToDropdown(RepPenGenerated.values),
            valueTransformer: (v) => v?.name
          )
        ),
      if(apiType == ApiType.neodim)
        SettingContainer(
          label: 'Truncate the penalty range to the input',
          child: FormBuilderCheckbox(
            name: 'repetitionPenaltyTruncateToInput',
            initialValue: cfgModel.repetitionPenaltyTruncateToInput,
            title: const SizedBox.shrink()
          )
        ),
      FieldInt(
        label: 'Penalty lines without extra symbols',
        name: 'repetitionPenaltyLinesWithNoExtraSymbols',
        initialValue: cfgModel.repetitionPenaltyLinesWithNoExtraSymbols
      ),
      SettingContainer(
        label: 'Keep the original penalty text',
        child: FormBuilderCheckbox(
          name: 'repetitionPenaltyKeepOriginalPrompt',
          initialValue: cfgModel.repetitionPenaltyKeepOriginalPrompt,
          title: const SizedBox.shrink()
        )
      ),
      SettingContainer(
        label: 'Remove participant names from the penalty text',
        child: FormBuilderCheckbox(
          name: 'repetitionPenaltyRemoveParticipantNames',
          initialValue: cfgModel.repetitionPenaltyRemoveParticipantNames,
          title: const SizedBox.shrink()
        )
      ),
      if(apiType == ApiType.neodim)
        FieldInt(
          label: 'No repeat N-gram size',
          name: 'noRepeatNGramSize',
          initialValue: cfgModel.noRepeatNGramSize
        ),
      FieldInt(
        label: 'Add words to the blacklist on retry',
        name: 'addWordsToBlacklistOnRetry',
        initialValue: cfgModel.addWordsToBlacklistOnRetry
      ),
      SettingContainer(
        label: 'Also add special symbols to the blacklist',
        child: FormBuilderCheckbox(
          name: 'addSpecialSymbolsToBlacklist',
          initialValue: cfgModel.addSpecialSymbolsToBlacklist,
          title: const SizedBox.shrink()
        )
      ),
      FieldInt(
        label: 'Remove old words from the blacklist on retry',
        name: 'removeWordsFromBlacklistOnRetry',
        initialValue: cfgModel.removeWordsFromBlacklistOnRetry
      ),
    ];
  }

  List<Widget> controlSection(ConfigModel cfgModel) {
    return [
      const SettingsHeader('Control'),

      if(apiType == ApiType.neodim)
        FieldInt(
          label: 'Generate extra sequences for quick retries',
          name: 'extraRetries',
          initialValue: cfgModel.extraRetries
        ),
      SettingContainer(
        label: 'Stop the generation on ".", "!", "?"',
        child: FormBuilderCheckbox(
          name: 'stopOnPunctuation',
          initialValue: cfgModel.stopOnPunctuation,
          title: const SizedBox.shrink()
        )
      ),
      SettingContainer(
        label: 'Undo the text up to these symbols: .!?*:()',
        child: FormBuilderCheckbox(
          name: 'undoBySentence',
          initialValue: cfgModel.undoBySentence,
          title: const SizedBox.shrink()
        )
      ),
      if(convType == ConversationType.chat)
        SettingContainer(
          label: 'Combine chat lines',
          child: FormBuilderDropdown(
            name: 'combineChatLines',
            initialValue: cfgModel.combineChatLines,
            items: enumToDropdown(CombineChatLinesType.values),
            valueTransformer: (v) => v?.name
          )
        ),
      if(convType == ConversationType.chat || convType == ConversationType.groupChat)
        SettingContainer(
          label: 'Always alternate chat participants in continuous mode',
          child: FormBuilderCheckbox(
            name: 'continuousChatForceAlternateParticipants',
            initialValue: cfgModel.continuousChatForceAlternateParticipants,
            title: const SizedBox.shrink()
          )
        ),
      if(convType == ConversationType.groupChat)
        SettingContainer(
          label: 'Colon at the start inserts the previous participant\'s name\nYes - no colon means a non-dialog line\nNo - colon inserts a non-dialog line',
          child: FormBuilderCheckbox(
            name: 'colonStartIsPreviousName',
            initialValue: cfgModel.colonStartIsPreviousName,
            title: const SizedBox.shrink()
          )
        ),
      if(convType == ConversationType.groupChat)
        SettingContainer(
          label: 'Participant on retry',
          child: FormBuilderDropdown(
            name: 'participantOnRetry',
            initialValue: cfgModel.participantOnRetry,
            items: enumToDropdown(ParticipantOnRetry.values),
            valueTransformer: (v) => v?.name
          )
        ),
    ];
  }

  List<DropdownMenuItem<T>> enumToDropdown<T extends Enum>(List<T> items) {
    return items.map((item) => DropdownMenuItem(
      value: item,
      child: Text(item.name.toNoCase()),
    )).toList();
  }

  String getPersonNameLabel(int authorIndex) {
    if(authorIndex == Message.youIndex) {
      if(convType == ConversationType.adventure)
        return 'Player name';
      return 'Person ${authorIndex + 1} (you) name';
    }
    if(convType == ConversationType.adventure || convType == ConversationType.story)
      return 'Storyteller name';
    if(convType == ConversationType.groupChat)
      return 'Group participants names (separate by commas)';
    return 'Person ${authorIndex + 1} name';
  }

  String getPersonColorLabel(int authorIndex) {
    if(authorIndex == Message.youIndex) {
      if(convType == ConversationType.adventure)
        return 'Player color';
      return 'Person ${authorIndex + 1} (you) color';
    }
    if(convType == ConversationType.adventure || convType == ConversationType.story)
      return 'Storyteller color';
    if(convType == ConversationType.groupChat)
      return 'Group participants color';
    return 'Person ${authorIndex + 1} color';
  }
}

class SettingsHeader extends StatelessWidget {
  const SettingsHeader(this.text);

  final String text;

  @override
  Widget build(context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              text,
              style: Theme.of(context).textTheme.headlineSmall
            ).padAll
          )
        )
      ]
    );
  }
}

class SettingContainer extends StatelessWidget {
  const SettingContainer({
    required this.label,
    required this.child,
    this.vertical = false
  });

  final String label;
  final Widget child;
  final bool vertical;

  @override
  Widget build(context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium
              ),
            ),
            if(!vertical)
             Pad.horizontalSpace,
            if(!vertical)
              Expanded(
                //flex: 1,
                child: child
              )
          ],
        ),
        if(vertical)
          child,
        const Divider()
      ],
    ).padHorizontal;
  }
}

class FieldInt extends StatelessWidget {
  const FieldInt({
    required this.label,
    required this.name,
    required this.initialValue,
    this.allowZero = true
  });

  final String label;
  final String name;
  final int initialValue;
  final bool allowZero;

  @override
  Widget build(context) {
    return SettingContainer(
      label: label,
      child: FormBuilderTextField(
        name: name,
        initialValue: initialValue.toString(),
        valueTransformer: (s) => s == null ? initialValue : int.tryParse(s) ?? initialValue,
        keyboardType: TextInputType.number,
        validator: FormBuilderValidators.compose([
          SettingsPage.required(),
          FormBuilderValidators.integer(errorText: 'Must be an integer'),
          FormBuilderValidators.min(
            allowZero ? 0 : 1,
            errorText: allowZero ? 'Must not be negative' : 'Must be positive'
          )
        ]),
      )
    );
  }
}

class FieldFloat extends StatelessWidget {
  const FieldFloat({
    required this.label,
    required this.name,
    required this.initialValue,
    this.allowZero = true,
    this.normalized = false
  });

  final String label;
  final String name;
  final double initialValue;
  final bool allowZero;
  final bool normalized;

  @override
  Widget build(context) {
    return SettingContainer(
      label: label,
      child: FormBuilderTextField(
        name: name,
        initialValue: initialValue.toString(),
        valueTransformer: (s) => s == null ? initialValue : double.tryParse(s) ?? initialValue,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: FormBuilderValidators.compose([
          SettingsPage.required(),
          FormBuilderValidators.numeric(errorText: 'Must be a number'),
          FormBuilderValidators.min(
            0,
            inclusive: allowZero,
            errorText: allowZero ? 'Must not be negative' : 'Must be positive'
          ),
          if(normalized)
            FormBuilderValidators.max(1, inclusive: true, errorText: 'Must be between 0 and 1'),
        ]),
      )
    );
  }
}

class FieldWarpers extends StatelessWidget {
  FieldWarpers({
    required List<Warper> initialValue,
    required this.supportedWarpers
  }) {
    normalizedInitialValue = initialValue.toList();
  }

  late final List<Warper> normalizedInitialValue;
  final List<Warper> supportedWarpers;

  void normalize(List<Warper> warpers) {
    ConfigModel.normalizeWarpers(warpers);
    warpers.removeWhere((warper) => !supportedWarpers.contains(warper));
  }

  @override
  Widget build(context) {
    normalize(normalizedInitialValue);

    return SettingContainer(
      label: 'Warpers order\n(drag by the handles to reorder)',
      child: FormBuilderField(
        name: 'warpersOrder',
        initialValue: normalizedInitialValue.map((w) => w.name).toList(),
        builder: (field) {
          var order = field.value?.toList() ?? [];
          var warpers = order.map((name) => Warper.values.byName(name)).toList();
          normalize(warpers);
          var normalizedOrder = warpers.map((w) => w.name).toList();
          if(!order.equals(normalizedOrder)) {
            WidgetsBinding.instance.addPostFrameCallback(
               (_) => field.didChange(normalizedOrder)
            );
          }
          return ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            onReorder: (int oldIndex, int newIndex) {
              if(oldIndex < newIndex)
                newIndex -= 1;
              var item = order.removeAt(oldIndex);
              order.insert(newIndex, item);
              field.didChange(order);
            },
            children: order.mapIndexed((index, warper) => ListTile(
              key: ValueKey(warper),
              title: Text(warper.toNoCase()),
              trailing: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle)
              ),
            )).toList()
          );
        }
      )
    );
  }
}
