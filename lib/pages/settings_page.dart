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
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../pages/help_page.dart';
import '../widgets/dialogs.dart';
import '../widgets/pad.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage();

  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static FormFieldValidator<T> required<T>() => FormBuilderValidators.required<T>(errorText: 'Required');
}

class _SettingsPageState extends State<SettingsPage> {
  var formKey = GlobalKey<FormBuilderState>();

  ConversationType? convType;
  TemperatureMode? temperatureMode;
  MirostatVersion? mirostat;

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    if(curConv == null)
      return const SizedBox.shrink();

    convType ??= curConv.type;
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
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
        child: Column(
          children: [
            FormBuilderDropdown(
              name: 'type',
              initialValue: curConv.type,
              items: enumToDropdown(ConversationType.values),
              valueTransformer: (v) => v?.name,
              enabled: typeEditable,
              onChanged: (type) => setState(() => convType = type)
            ),
            if(!typeEditable && curConv.type == ConversationType.chat)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: ElevatedButton(
                  onPressed: () async {
                    if(!await showConfirmDialog(context, curConv.name, 'Convert to group chat?\n\nThis cannot be undone.'))
                      return;
                    await curConv.convertChatToGroupChat(context);
                    await curConv.loadAsCurrent(context);
                    formKey.currentState?.patchValue({
                      'type': ConversationType.groupChat
                    });
                  },
                  child: const Text('Convert to\ngroup chat')
                )
              )
          ],
        )
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
    var supportedWarpers = LlamaCppRequest.supportedWarpers;

    return [
      const SettingsHeader('Sampling'),

      FieldInt(
        label: 'Generated tokens',
        name: 'generatedTokensCount',
        initialValue: cfgModel.generatedTokensCount,
        allowZero: false
      ),
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
      if(temperatureMode == TemperatureMode.static)
        FieldFloat(
          label: 'Temperature',
          name: 'temperature',
          initialValue: cfgModel.temperature,
          minInclusive: true
        ),
      if(temperatureMode == TemperatureMode.dynamic)
        FieldFloat(
          label: 'Min. temperature',
          name: 'temperature',
          initialValue: cfgModel.temperature,
          minInclusive: true
        ),
      if(temperatureMode == TemperatureMode.dynamic)
        FieldFloat(
          label: 'Max. temperature',
          name: 'dynaTempHigh',
          initialValue: cfgModel.dynaTempHigh,
          minInclusive: true
        ),
      if(temperatureMode == TemperatureMode.dynamic)
        FieldFloat(
          label: 'Dynamic temperature exponent',
          name: 'dynaTempExponent',
          initialValue: cfgModel.dynaTempExponent,
          minInclusive: false
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
        maxValue: 1
      ),
      FieldFloat(
        label: 'Min P',
        name: 'minP',
        initialValue: cfgModel.minP,
        maxValue: 1
      ),
      FieldFloat(
        label: 'Typical sampling',
        name: 'typical',
        initialValue: cfgModel.typical,
        maxValue: 1
      ),
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
      if(mirostat != MirostatVersion.none)
        FieldFloat(
          label: 'Mirostat Tau',
          name: 'mirostatTau',
          initialValue: cfgModel.mirostatTau,
          minInclusive: false,
        ),
      if(mirostat != MirostatVersion.none)
        FieldFloat(
          label: 'Mirostat Eta',
          name: 'mirostatEta',
          initialValue: cfgModel.mirostatEta,
          maxValue: 1
        ),
      FieldFloat(
        label: 'XTC probability',
        name: 'xtcProbability',
        initialValue: cfgModel.xtcProbability,
        maxValue: 1
      ),
      FieldFloat(
        label: 'XTC threshold',
        name: 'xtcThreshold',
        initialValue: cfgModel.xtcThreshold,
        maxValue: 0.5
      ),
      FieldFloat(
        label: 'DRY multiplier',
        name: 'dryMultiplier',
        initialValue: cfgModel.dryMultiplier
      ),
      FieldFloat(
        label: 'DRY base',
        name: 'dryBase',
        initialValue: cfgModel.dryBase
      ),
      FieldInt(
        label: 'DRY allowed length',
        name: 'dryAllowedLength',
        initialValue: cfgModel.dryAllowedLength
      ),
      FieldInt(
        label: 'DRY penalty range\n(0 - unlimited)',
        name: 'dryRange',
        initialValue: cfgModel.dryRange
      ),
      FieldFloat(
        label: 'Top N Sigma',
        name: 'topNSigma',
        initialValue: cfgModel.topNSigma,
        minValue: -1,
        minInclusive: true
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
      FieldFloat(
        label: 'Frequency penalty',
        name: 'frequencyPenalty',
        initialValue: cfgModel.frequencyPenalty
      ),
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
      SettingContainer(
        label: 'Include preamble in the penalty range',
        child: FormBuilderCheckbox(
          name: 'repetitionPenaltyIncludePreamble',
          initialValue: cfgModel.repetitionPenaltyIncludePreamble,
          title: const SizedBox.shrink()
        )
      ),
      FieldStringList(
        label: 'Blacklist (one word or phrase per line)',
        name: 'initialBlacklist',
        initialValue: cfgModel.initialBlacklist
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
    this.minValue = 0,
    this.maxValue,
    this.minInclusive = true
  });

  final String label;
  final String name;
  final double initialValue;
  final bool minInclusive;
  final double? minValue;
  final double? maxValue;

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
          if(minValue != null)
            FormBuilderValidators.min(
              minValue!,
              inclusive: minInclusive,
              errorText: minInclusive ? 'Must be $minValue or bigger' : 'Must be bigger than $minValue'
            ),
          if(maxValue != null)
            FormBuilderValidators.max(maxValue!, inclusive: true, errorText: 'Must be between 0 and $maxValue')
        ]),
      )
    );
  }
}

class FieldStringList extends StatelessWidget {
  FieldStringList({
    required this.label,
    required this.name,
    required List<String> initialValue
  }):
    initialValue = initialValue.toList();

  final String label;
  final String name;
  final List<String> initialValue;

  @override
  Widget build(context) {
    return SettingContainer(
      label: label,
      child: FormBuilderTextField(
        name: name,
        initialValue: initialValue.join('\n'),
        valueTransformer: (s) => s?.split('\n') ?? initialValue,
        minLines: 5,
        maxLines: 10
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
