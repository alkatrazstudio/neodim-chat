// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:card_settings/card_settings.dart';
import 'package:change_case/change_case.dart';
import 'package:provider/provider.dart';

import '../apis/llama_cpp.dart';
import '../apis/neodim.dart';
import '../apis/request.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../pages/help_page.dart';
import '../util/enums.dart';
import '../widgets/card_settings_warpers_order.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage();

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final List<String> warpersOrder = [];

  ConversationType? convType;
  ApiType? apiType;
  TemperatureMode? temperatureMode;

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    if(curConv == null)
      return const SizedBox.shrink();

    convType ??= curConv.type;
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    apiType ??= cfgModel.apiType;
    temperatureMode ??= cfgModel.temperatureMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(curConv.name),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (context) => const HelpPage())
              );
            },
            icon: const Icon(Icons.help)
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () async {
          var state = formKey.currentState;
          if(state == null)
            return;
          if(!state.validate())
            return;

          state.save();
          var convModel = Provider.of<ConversationsModel>(context, listen: false);
          await ConversationsModel.saveList(context);
          await ConversationsModel.saveCurrentData(context);
          Navigator.of(context).pop();
        }
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Form(
              key: formKey,
              child: settings(context)
            ),
            const SizedBox(height: 65)
          ]
        )
      )
    );
  }

  String? validateRequired(String? s) {
    if(s == null || s.trim().isEmpty)
      return 'Required';
    return null;
  }

  String? validateNonNegativeInt(int? x) {
    if(x == null || x < 0)
      return 'Must be zero or above';
    return null;
  }

  String? validateNormalizedDouble(double x) {
    if(x < 0 || x > 1)
      return 'Must be between 0 and 1';
    return null;
  }

  String? validatePositiveDouble(double x) {
    if(x <= 0)
      return 'Must be greater than 0';
    return null;
  }

  String? validateNonNegativeDouble(double x) {
    if(x < 0)
      return 'Must be 0 or above';
    return null;
  }

  Function(String?) onStringSave(Function(String) f, {bool allowEmpty = false}) {
    return (String? s) {
      if(s == null)
        return;
      s = s.trim();
      if(s.isNotEmpty || allowEmpty)
        f(s);
    };
  }

  Function(int?) onIntSave(Function(int) f) {
    return (int? x) {
      if(x != null)
        f(x);
    };
  }

  Widget settings(BuildContext context) {
    var msgModel = Provider.of<MessagesModel>(context, listen: false);
    var convModel = Provider.of<ConversationsModel>(context, listen: false);
    var cfgModel = Provider.of<ConfigModel>(context, listen: false);
    var curConv = convModel.current;
    if(curConv == null)
      return const SizedBox.shrink();

    return CardSettings.sectioned(
      children: [
        conversationSection(context, msgModel, convModel, curConv, cfgModel),
        participantsSection(context, msgModel, curConv),
        configSection(context, cfgModel)
      ]
    );
  }

  CardSettingsSection conversationSection(
    BuildContext context,
    MessagesModel msgModel,
    ConversationsModel convModel,
    Conversation curConv,
    ConfigModel cfgModel
  ) {
    var typeEditable = msgModel.messages.isEmpty;

    return CardSettingsSection(
      header: CardSettingsHeader(
        label: 'Conversation'
      ),
      children: [
        CardSettingsText(
          label: 'Name',
          initialValue: curConv.name,
          validator: validateRequired,
          onSaved: onStringSave((s) => convModel.setName(curConv, s)),
          maxLength: 32
        ),
        CardSettingsParagraph(
          label: 'Preamble',
          initialValue: cfgModel.preamble,
          onSaved: onStringSave((s) => cfgModel.setPreamble(s), allowEmpty: true),
          maxLength: 65535,
        ),
        picker(
          label: typeEditable ? 'Type' : 'Type (cannot change if messages are present)',
          initialItem: curConv.type,
          items: ConversationType.values,
          onSaved: (s) => convModel.setType(curConv, s),
          onChanged: (s) {
            setState(() {
              convType = s;
            });
          },
          enabled: typeEditable
        )
      ]
    );
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

  CardSettingsSection participantsSection(BuildContext context, MessagesModel msgModel, Conversation curConv) {
    return CardSettingsSection(
      header: CardSettingsHeader(
        label: 'Participants'
      ),
      children: [
        for(var authorIndex = 0; authorIndex < msgModel.participants.length; authorIndex++)
          ...[
            if(convType != ConversationType.story || authorIndex != Message.youIndex)
              CardSettingsText(
                key: ValueKey('authorName-$authorIndex'),
                label: getPersonNameLabel(authorIndex),
                initialValue: msgModel.participants[authorIndex].name,
                validator: validateRequired,
                onSaved: onStringSave((s) => msgModel.setAuthorName(authorIndex, s)),
                maxLength: 64
              ),
            if(convType != ConversationType.story || authorIndex != Message.youIndex)
              CardSettingsColorPicker(
                key: ValueKey('authorColor-$authorIndex'),
                label: getPersonColorLabel(authorIndex),
                initialValue: msgModel.participants[authorIndex].color,
                onSaved: (c) {
                  if(c != null)
                    msgModel.setAuthorColor(authorIndex, c);
                },
              )
          ]
      ],
    );
  }

  CardSettingsListPicker picker<T extends Enum>({
    required String label,
    required T initialItem,
    required List<T> items,
    required Function(T) onSaved,
    Function(T)? onChanged,
    bool enabled = true
  }) {
    return CardSettingsListPicker<String>(
      label: label,
      initialItem: initialItem.name.toNoCase(),
      items: items.map((v) => v.name.toNoCase()).toList(),
      onSaved: (s) {
        if(s == null)
          return;
        var strVal = s.toCamelCase();
        var enumVal = items.byNameOrFirst(strVal);
        onSaved(enumVal);
      },
      onChanged: onChanged == null ? null : (s) {
        if(s == null)
          return;
        var strVal = s.toCamelCase();
        var enumVal = items.byNameOrFirst(strVal);
        onChanged(enumVal);
      },
      enabled: enabled
    );
  }

  CardSettingsText cardSettingsDouble({
    required String label,
    required double initialValue,
    required String? Function(double) validator,
    required void Function(double) onSaved
  }) {
    var intVal = initialValue.ceil();
    // Use raw text field with some modifications
    // because the original CardSettingsDouble uses auto-formatting
    // that prevents entering values like 0.01
    return CardSettingsText(
      label: label,
      initialValue: intVal == initialValue ? intVal.toString() : initialValue.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (s) {
        if(s == null)
          return 'Required';
        s = s.trim();
        if(s.isEmpty)
          return 'Required';
        var val = double.tryParse(s);
        if(val == null)
          return 'Invalid value';
        return validator(val);
      },
      onSaved: (s) {
        if(s == null)
          return;
        s = s.trim();
        var val = double.tryParse(s);
        if(val == null)
          return;
        onSaved(val);
      }
    );
  }

  CardSettingsSection configSection(BuildContext context, ConfigModel cfgModel) {
    var supportedWarpers = switch(apiType) {
      ApiType.neodim => NeodimRequest.supportedWarpers,
      ApiType.llamaCpp => LlamaCppRequest.supportedWarpers,
      _ => <Warper>[]
    };

    return CardSettingsSection(
      header: CardSettingsHeader(
        label: 'Configuration'
      ),
      children: [
        picker(
          label: 'API type',
          initialItem: cfgModel.apiType,
          items: ApiType.values,
          onSaved: (s) => cfgModel.setApiType(s),
          onChanged: (newApiType) {
            setState(() {
              apiType = newApiType;
            });
          }
        ),
        CardSettingsText(
          label: 'API endpoint',
          initialValue: cfgModel.apiEndpoint,
          validator: validateRequired,
          onSaved: onStringSave((s) => cfgModel.setApiEndpoint(s)),
          maxLength: 1024
        ),
        CardSettingsInt(
          label: 'Generated tokens',
          initialValue: cfgModel.generatedTokensCount,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setGeneratedTokensCount(x))
        ),
        if(apiType == ApiType.neodim)
          CardSettingsInt(
            label: 'Max total tokens',
            initialValue: cfgModel.maxTotalTokens,
            validator: validateNonNegativeInt,
            onSaved: onIntSave((x) => cfgModel.setMaxTotalTokens(x)),
          ),
        if(apiType == ApiType.llamaCpp)
          picker(
            label: 'Temperature mode',
            initialItem: cfgModel.temperatureMode,
            items: TemperatureMode.values,
            onSaved: (newTemperatureMode) => cfgModel.setTemperatureMode(newTemperatureMode),
            onChanged: (newTemperatureMode) {
              setState(() {
                temperatureMode = newTemperatureMode;
              });
            }
          ),
        if(temperatureMode == TemperatureMode.static || apiType != ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Temperature',
            initialValue: cfgModel.temperature,
            validator: validatePositiveDouble,
            onSaved: (x) => cfgModel.setTemperature(x)
          ),
        if(temperatureMode == TemperatureMode.dynamic && apiType == ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Min. temperature',
            initialValue: cfgModel.temperature,
            validator: validatePositiveDouble,
            onSaved: (x) => cfgModel.setTemperature(x)
          ),
        if(temperatureMode == TemperatureMode.dynamic && apiType == ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Max. temperature',
            initialValue: cfgModel.dynaTempHigh,
            validator: validatePositiveDouble,
            onSaved: (x) => cfgModel.setDynaTempHigh(x)
          ),
        if(temperatureMode == TemperatureMode.dynamic && apiType == ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Dynamic temperature exponent',
            initialValue: cfgModel.dynaTempExponent,
            validator: validatePositiveDouble,
            onSaved: (x) => cfgModel.setDynaTempExponent(x)
          ),
        CardSettingsInt(
          label: 'Top K',
          initialValue: cfgModel.topK,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setTopK(x))
        ),
        cardSettingsDouble(
          label: 'Top P (nucleus sampling)',
          initialValue: cfgModel.topP,
          validator: validateNormalizedDouble,
          onSaved: (x) => cfgModel.setTopP(x)
        ),
        if(apiType == ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Min P',
            initialValue: cfgModel.minP,
            validator: validateNormalizedDouble,
            onSaved: (x) => cfgModel.setMinP(x)
          ),
        cardSettingsDouble(
          label: 'Tail-free sampling',
          initialValue: cfgModel.tfs,
          validator: validateNormalizedDouble,
          onSaved: (x) => cfgModel.setTfs(x)
        ),
        cardSettingsDouble(
          label: 'Typical sampling',
          initialValue: cfgModel.typical,
          validator: validateNormalizedDouble,
          onSaved: (x) => cfgModel.setTypical(x)
        ),
        if(apiType == ApiType.neodim)
          cardSettingsDouble(
            label: 'Top A',
            initialValue: cfgModel.topA,
            validator: validateNormalizedDouble,
            onSaved: (x) => cfgModel.setTopA(x)
          ),
        if(apiType == ApiType.neodim)
          cardSettingsDouble(
            label: 'Penalty alpha',
            initialValue: cfgModel.penaltyAlpha,
            validator: validateNormalizedDouble,
            onSaved: (x) => cfgModel.setPenaltyAlpha(x)
          ),
        if(apiType == ApiType.llamaCpp)
          picker(
            label: 'Mirostat',
            initialItem: cfgModel.mirostat,
            items: MirostatVersion.values,
            onSaved: (s) => cfgModel.setMirostat(s)
          ),
        if(apiType == ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Mirostat Tau',
            initialValue: cfgModel.mirostatTau,
            validator: validatePositiveDouble,
            onSaved: (x) => cfgModel.setMirostatTau(x)
          ),
        if(apiType == ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Mirostat Eta',
            initialValue: cfgModel.mirostatEta,
            validator: validateNormalizedDouble,
            onSaved: (x) => cfgModel.setMirostatEta(x)
          ),
        cardSettingsDouble(
          label: 'Repetition penalty',
          initialValue: cfgModel.repetitionPenalty,
          validator: validateNonNegativeDouble,
          onSaved: (x) => cfgModel.setRepetitionPenalty(x)
        ),
        if(apiType == ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Frequency penalty',
            initialValue: cfgModel.frequencyPenalty,
            validator: validateNonNegativeDouble,
            onSaved: (x) => cfgModel.setFrequencyPenalty(x)
          ),
        if(apiType == ApiType.llamaCpp)
          cardSettingsDouble(
            label: 'Presence penalty',
            initialValue: cfgModel.presencePenalty,
            validator: validateNonNegativeDouble,
            onSaved: (x) => cfgModel.setPresencePenalty(x)
          ),
        CardSettingsInt(
          label: 'Penalty range',
          initialValue: cfgModel.repetitionPenaltyRange,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setRepetitionPenaltyRange(x))
        ),
        if(apiType == ApiType.neodim)
          cardSettingsDouble(
            label: 'Penalty slope',
            initialValue: cfgModel.repetitionPenaltySlope,
            validator: validateNonNegativeDouble,
            onSaved: (x) => cfgModel.setRepetitionPenaltySlope(x)
          ),
        CardSettingsSwitch(
          label: 'Include preamble in the penalty range',
          initialValue: cfgModel.repetitionPenaltyIncludePreamble,
          onSaved: (val) => cfgModel.setRepetitionPenaltyIncludePreamble(val ?? false),
        ),
        if(apiType == ApiType.neodim)
          picker(
            label: 'Include generated text in the penalty range',
            initialItem: cfgModel.repetitionPenaltyIncludeGenerated,
            items: RepPenGenerated.values,
            onSaved: (s) => cfgModel.setRepetitionPenaltyIncludeGenerated(s)
          ),
        if(apiType == ApiType.neodim)
          CardSettingsSwitch(
            label: 'Truncate the penalty range to the input',
            initialValue: cfgModel.repetitionPenaltyTruncateToInput,
            onSaved: (val) => cfgModel.setRepetitionPenaltyTruncateToInput(val ?? false),
          ),
        CardSettingsInt(
          label: 'Penalty lines without extra symbols',
          initialValue: cfgModel.repetitionPenaltyLinesWithNoExtraSymbols,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setRepetitionPenaltyLinesWithNoExtraSymbols(x))
        ),
        CardSettingsSwitch(
          label: 'Keep the original penalty text',
          initialValue: cfgModel.repetitionPenaltyKeepOriginalPrompt,
          onSaved: (val) => cfgModel.setRepetitionPenaltyKeepOriginalPrompt(val ?? false)
        ),
        CardSettingsSwitch(
          label: 'Remove participant names from the penalty text',
          initialValue: cfgModel.repetitionPenaltyRemoveParticipantNames,
          onSaved: (val) => cfgModel.setRepetitionPenaltyRemoveParticipantNames(val ?? true),
        ),
        if(apiType == ApiType.neodim)
          CardSettingsInt(
            label: 'No repeat N-gram size',
            initialValue: cfgModel.noRepeatNGramSize,
            validator: validateNonNegativeInt,
            onSaved: onIntSave((x) => cfgModel.setNoRepeatNGramSize(x))
          ),
        if(supportedWarpers.isNotEmpty)
          CardSettingsWarpersOrder(
            supportedWarpers: supportedWarpers,
            initialValue: cfgModel.warpersOrder,
            onSaved: (order) => cfgModel.setWarpersOrder(order)
          ),
        if(apiType == ApiType.neodim)
          CardSettingsInt(
            label: 'Generate extra sequences for quick retries',
            initialValue: cfgModel.extraRetries,
            validator: validateNonNegativeInt,
            onSaved: onIntSave((x) => cfgModel.setExtraRetries(x))
          ),
        CardSettingsInt(
          label: 'Add words to blacklist on retry',
          initialValue: cfgModel.addWordsToBlacklistOnRetry,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setAddWordsToBlacklistOnRetry(x))
        ),
        CardSettingsSwitch(
          label: 'Also add special symbols to blacklist',
          initialValue: cfgModel.addSpecialSymbolsToBlacklist,
          onSaved: (val) => cfgModel.setAddSpecialSymbolsToBlacklist(val ?? false)
        ),
        CardSettingsInt(
          label: 'Remove old words from blacklist on retry',
          initialValue: cfgModel.removeWordsFromBlacklistOnRetry,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setRemoveWordsFromBlacklistOnRetry(x))
        ),
        CardSettingsSwitch(
          label: 'Stop the generation on ".", "!", "?"',
          initialValue: cfgModel.stopOnPunctuation,
          onSaved: (val) => cfgModel.setStopOnPunctuation(val ?? false)
        ),
        CardSettingsSwitch(
          label: 'Undo the text up to these symbols: .!?*:()',
          initialValue: cfgModel.undoBySentence,
          onSaved: (val) => cfgModel.setUndoBySentence(val ?? false)
        ),
        if(convType == ConversationType.chat)
          picker(
            label: 'Combine chat lines',
            initialItem: cfgModel.combineChatLines,
            items: CombineChatLinesType.values,
            onSaved: (s) => cfgModel.setGroupChatLines(s)
          ),
        if(convType == ConversationType.chat || convType == ConversationType.groupChat)
          CardSettingsSwitch(
            label: 'Always alternate chat participants in continuous mode',
            initialValue: cfgModel.continuousChatForceAlternateParticipants,
            onSaved: (val) => cfgModel.setContinuousChatForceAlternateParticipants(val ?? true)
          ),
        if(convType == ConversationType.groupChat)
          CardSettingsSwitch(
            label: 'Colon at the start inserts the previous participant\'s name',
            initialValue: cfgModel.colonStartIsPreviousName,
            onSaved: (val) => cfgModel.setColonStartIsPreviousName(val ?? true),
            trueLabel: 'Yes, and no colon means a non-dialog line',
            falseLabel: 'No, colon inserts a non-dialog line'
          ),
        if(convType == ConversationType.groupChat)
          picker(
            label: 'Participant on retry',
            initialItem: cfgModel.participantOnRetry,
            items: ParticipantOnRetry.values,
            onSaved: (s) => cfgModel.setSameParticipantOnRetry(s)
          )
      ]
    );
  }
}
