// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:card_settings/card_settings.dart';
import 'package:provider/provider.dart';

import '../apis/request.dart';
import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../pages/help_page.dart';
import '../widgets/card_settings_warpers_order.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage();

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final List<String> warpersOrder = [];

  late var convType = '';
  ApiType? apiType;

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    if(curConv == null)
      return const SizedBox.shrink();

    if(convType.isEmpty)
      convType = curConv.type;
    apiType ??= Provider.of<ConfigModel>(context, listen: false).apiType;

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
          await convModel.save();
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

  String? validateNormalizedDouble(double? x) {
    if(x == null || x < 0 || x > 1)
      return 'Must be between 0 and 1';
    return null;
  }

  String? validatePositiveDouble(double? x) {
    if(x == null || x <= 0)
      return 'Must be greater than 0';
    return null;
  }

  String? validateNonNegativeDouble(double? x) {
    if(x == null || x < 0)
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

  Function(double?) onDoubleSave(Function(double) f) {
    return (double? x) {
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
          items: Conversation.availableTypes,
          onSaved: (s) => convModel.setType(curConv, s),
          onChanged: (s) {
            setState(() {
              convType = s;
            });
          },
          cfgModel: cfgModel,
          enabled: typeEditable
        )
      ]
    );
  }

  String getPersonNameLabel(int authorIndex) {
    if(authorIndex == Message.youIndex)
      return 'Person ${authorIndex + 1} (you) name';
    if(convType == Conversation.typeGroupChat)
      return 'Group participants names (separate by commas)';
    return 'Person ${authorIndex + 1} name';
  }

  String getPersonColorLabel(int authorIndex) {
    if(authorIndex == Message.youIndex)
      return 'Person ${authorIndex + 1} (you) color';
    if(convType == Conversation.typeGroupChat)
      return 'Group participants color';
    return 'Person ${authorIndex + 1} name';
  }

  CardSettingsSection participantsSection(BuildContext context, MessagesModel msgModel, Conversation curConv) {
    return CardSettingsSection(
      header: CardSettingsHeader(
        label: 'Participants'
      ),
      children: [
        for(var authorIndex = 0; authorIndex < msgModel.participants.length; authorIndex++)
          ...[
            CardSettingsText(
              label: getPersonNameLabel(authorIndex),
              initialValue: msgModel.participants[authorIndex].name,
              validator: validateRequired,
              onSaved: onStringSave((s) => msgModel.setAuthorName(authorIndex, s)),
              maxLength: 64
            ),
            CardSettingsColorPicker(
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

  String enumValToText(String val) {
    var parts = val.split(RegExp(r'(?=[A-Z])'));
    var text = parts.join(' ').toLowerCase();
    return text;
  }

  String textToEnumVal(String text) {
    var parts = text.split(' ');
    if(parts.length == 1)
      return parts[0];
    var val = '${parts[0]}${parts.sublist(1).map((s) => '${s[0].toUpperCase()}${s.substring(1)}').join('')}';
    return val;
  }

  CardSettingsListPicker picker({
    required String label,
    required String initialItem,
    required List<String> items,
    required Function(String) onSaved,
    Function(String)? onChanged,
    required ConfigModel cfgModel,
    bool enabled = true
  }) {
    return CardSettingsListPicker<String>(
      label: label,
      initialItem: enumValToText(initialItem),
      items: items.map(enumValToText).toList(),
      onSaved: (s) {
        if(s == null)
          return;
        var val = textToEnumVal(s);
        onSaved(val);
      },
      onChanged: onChanged == null ? null : (s) {
        if(s == null)
          return;
        var val = textToEnumVal(s);
        onChanged(val);
      },
      enabled: enabled
    );
  }

  CardSettingsSection configSection(BuildContext context, ConfigModel cfgModel) {
    var combineLinesEditable = convType == Conversation.typeChat;
    var autoAlternateEnabled = convType == Conversation.typeChat || convType == Conversation.typeGroupChat;
    var colonStartIsPreviousNameEnabled = convType == Conversation.typeGroupChat;

    return CardSettingsSection(
      header: CardSettingsHeader(
        label: 'Configuration'
      ),
      children: [
        picker(
          label: 'API type',
          initialItem: cfgModel.apiType.name,
          items: ApiType.values.map((v) => v.name).toList(),
          onSaved: (s) => cfgModel.setApiTypeByName(s),
          onChanged: (newApiTypeName) {
            setState(() {
              apiType = ApiType.byNameOrDefault(newApiTypeName);
            });
          },
          cfgModel: cfgModel
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
        CardSettingsDouble(
          label: 'Temperature',
          initialValue: cfgModel.temperature,
          decimalDigits: 3,
          validator: validatePositiveDouble,
          onSaved: onDoubleSave((x) => cfgModel.setTemperature(x))
        ),
        CardSettingsInt(
          label: 'Top K',
          initialValue: cfgModel.topK,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setTopK(x))
        ),
        CardSettingsDouble(
          label: 'Top P (nucleus sampling)',
          initialValue: cfgModel.topP,
          decimalDigits: 3,
          validator: validateNormalizedDouble,
          onSaved: onDoubleSave((x) => cfgModel.setTopP(x))
        ),
        CardSettingsDouble(
          label: 'Tail-free sampling',
          initialValue: cfgModel.tfs,
          decimalDigits: 3,
          validator: validateNormalizedDouble,
          onSaved: onDoubleSave((x) => cfgModel.setTfs(x))
        ),
        CardSettingsDouble(
          label: 'Typical sampling',
          initialValue: cfgModel.typical,
          decimalDigits: 3,
          validator: validateNormalizedDouble,
          onSaved: onDoubleSave((x) => cfgModel.setTypical(x))
        ),
        if(apiType == ApiType.neodim)
          CardSettingsDouble(
            label: 'Top A',
            initialValue: cfgModel.topA,
            decimalDigits: 3,
            validator: validateNormalizedDouble,
            onSaved: onDoubleSave((x) => cfgModel.setTopA(x))
          ),
        if(apiType == ApiType.neodim)
          CardSettingsDouble(
            label: 'Penalty alpha',
            initialValue: cfgModel.penaltyAlpha,
            decimalDigits: 3,
            validator: validateNormalizedDouble,
            onSaved: onDoubleSave((x) => cfgModel.setPenaltyAlpha(x))
          ),
        if(apiType == ApiType.llamaCpp)
          picker(
            label: 'Mirostat',
            initialItem: cfgModel.mirostat.name,
            items: Mirostat.values.map((v) => v.name).toList(),
            onSaved: (s) => cfgModel.setMirostatByName(s),
            cfgModel: cfgModel
          ),
        if(apiType == ApiType.llamaCpp)
          CardSettingsDouble(
            label: 'Mirostat Tau',
            initialValue: cfgModel.mirostatTau,
            decimalDigits: 3,
            validator: validatePositiveDouble,
            onSaved: onDoubleSave((x) => cfgModel.setMirostatTau(x))
          ),
        if(apiType == ApiType.llamaCpp)
          CardSettingsDouble(
            label: 'Mirostat Eta',
            initialValue: cfgModel.mirostatEta,
            decimalDigits: 3,
            validator: validateNormalizedDouble,
            onSaved: onDoubleSave((x) => cfgModel.setMirostatEta(x))
          ),
        CardSettingsDouble(
          label: 'Repetition penalty',
          initialValue: cfgModel.repetitionPenalty,
          decimalDigits: 3,
          validator: validateNonNegativeDouble,
          onSaved: onDoubleSave((x) => cfgModel.setRepetitionPenalty(x))
        ),
        CardSettingsInt(
          label: 'Repetition penalty range',
          initialValue: cfgModel.repetitionPenaltyRange,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setRepetitionPenaltyRange(x))
        ),
        if(apiType == ApiType.neodim)
          CardSettingsDouble(
            label: 'Repetition penalty slope',
            initialValue: cfgModel.repetitionPenaltySlope,
            decimalDigits: 3,
            validator: validateNonNegativeDouble,
            onSaved: onDoubleSave((x) => cfgModel.setRepetitionPenaltySlope(x))
          ),
        CardSettingsSwitch(
          label: 'Include preamble in the repetition penalty range',
          initialValue: cfgModel.repetitionPenaltyIncludePreamble,
          onSaved: (val) => cfgModel.setRepetitionPenaltyIncludePreamble(val ?? false),
        ),
        if(apiType == ApiType.neodim)
          picker(
            label: 'Include generated text in the repetition penalty range',
            initialItem: cfgModel.repetitionPenaltyIncludeGenerated,
            items: const [
              RepPenGenerated.ignore,
              RepPenGenerated.expand,
              RepPenGenerated.slide
            ],
            onSaved: (s) => cfgModel.setRepetitionPenaltyIncludeGenerated(s),
            cfgModel: cfgModel
          ),
        if(apiType == ApiType.neodim)
          CardSettingsSwitch(
            label: 'Truncate the repetition penalty range to the input',
            initialValue: cfgModel.repetitionPenaltyTruncateToInput,
            onSaved: (val) => cfgModel.setRepetitionPenaltyTruncateToInput(val ?? false),
          ),
        CardSettingsInt(
          label: 'Repetition penalty lines without extra symbols',
          initialValue: cfgModel.repetitionPenaltyLinesWithNoExtraSymbols,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setRepetitionPenaltyLinesWithNoExtraSymbols(x))
        ),
        CardSettingsSwitch(
          label: 'Keep the original repetition penalty text',
          initialValue: cfgModel.repetitionPenaltyKeepOriginalPrompt,
          onSaved: (val) => cfgModel.setRepetitionPenaltyKeepOriginalPrompt(val ?? false)
        ),
        CardSettingsSwitch(
          label: 'Remove participant names from repetition penalty text',
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
        if(apiType == ApiType.neodim)
          CardSettingsWarpersOrder(
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
        picker(
          label: 'Combine chat lines${combineLinesEditable ? '' : ' (only available in chat mode)'}',
          initialItem: cfgModel.combineChatLines,
          items: const [
            CombineChatLinesType.no,
            CombineChatLinesType.onlyForServer,
            CombineChatLinesType.previousLines
          ],
          onSaved: (s) => cfgModel.setGroupChatLines(s),
          cfgModel: cfgModel,
          enabled: combineLinesEditable
        ),
        CardSettingsSwitch(
          label: 'Always alternate chat participants in continuous mode ${autoAlternateEnabled ? '' : ' (only available in chat or group chat mode)'}',
          initialValue: cfgModel.continuousChatForceAlternateParticipants,
          onSaved: (val) => cfgModel.setContinuousChatForceAlternateParticipants(val ?? true),
          enabled: autoAlternateEnabled
        ),
        CardSettingsSwitch(
          label: 'Colon at the start inserts the previous participant\'s name',
          initialValue: cfgModel.colonStartIsPreviousName,
          onSaved: (val) => cfgModel.setColonStartIsPreviousName(val ?? true),
          enabled: colonStartIsPreviousNameEnabled,
          trueLabel: 'Yes, and no colon means a non-dialog line',
          falseLabel: 'No, colon inserts a non-dialog line'
        )
      ]
    );
  }
}

class TextSetting extends StatelessWidget {
  TextSetting({
    required this.title,
    required this.initialValue,
    required this.onChanged
  });

  final String title;
  final String initialValue;
  final Function(String s) onChanged;
  final inputController = TextEditingController();

  void submit(BuildContext context) {
    var text = inputController.text.trim();
    if(text.isEmpty) {
      inputController.text = initialValue;
      return;
    }

    onChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    inputController.text = initialValue;

    return Focus(
      child: TextField(
        controller: inputController,
        onSubmitted: (text) {
          submit(context);
        },
        textInputAction: TextInputAction.done
      ),
      onFocusChange: (inFocus) async {
        if(!inFocus)
          submit(context);
      }
    );
  }
}
