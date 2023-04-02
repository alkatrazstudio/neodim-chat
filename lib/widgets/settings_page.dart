// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';

import 'package:card_settings/card_settings.dart';
import 'package:provider/provider.dart';

import '../models/config.dart';
import '../models/conversations.dart';
import '../models/messages.dart';
import '../util/neodim_api.dart';
import '../widgets/card_settings_warpers_order.dart';
import '../widgets/help_page.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final List<String> warpersOrder = [];

  @override
  Widget build(BuildContext context) {
    var curConv = Provider.of<ConversationsModel>(context).current;
    if(curConv == null)
      return const SizedBox.shrink();

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
    var msgModel = Provider.of<MessagesModel>(context);
    var convModel = Provider.of<ConversationsModel>(context);
    var cfgModel = Provider.of<ConfigModel>(context);
    var curConv = convModel.current;
    if(curConv == null)
      return const SizedBox.shrink();

    return CardSettings.sectioned(
      children: [
        conversationSection(context, convModel, curConv, cfgModel),
        participantsSection(context, msgModel),
        configSection(context, cfgModel)
      ]
    );
  }

  CardSettingsSection conversationSection(BuildContext context, ConversationsModel convModel, Conversation curConv, ConfigModel cfgModel) {
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
          maxLength: 2048
        ),
        CardSettingsListPicker<String>(
          label: 'Type',
          initialItem: curConv.type,
          items: Conversation.availableTypes,
          onSaved: (s) {
            if(s == null)
              return;
            convModel.setType(curConv, s);
          }
        )
      ]
    );
  }

  CardSettingsSection participantsSection(BuildContext context, MessagesModel msgModel) {
    return CardSettingsSection(
      header: CardSettingsHeader(
        label: 'Participants'
      ),
      children: [
        for(var authorIndex = 0; authorIndex < msgModel.participants.length; authorIndex++)
          ...[
            CardSettingsText(
              label: 'Person ${authorIndex + 1}${authorIndex == Message.youIndex ? ' (you)' : ''} name',
              initialValue: msgModel.participants[authorIndex].name,
              validator: validateRequired,
              onSaved: onStringSave((s) => msgModel.setAuthorName(authorIndex, s)),
              maxLength: 32
            ),
            CardSettingsColorPicker(
              label: 'Person ${authorIndex + 1}${authorIndex == Message.youIndex ? ' (you)' : ''} color',
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

  CardSettingsSection configSection(BuildContext context, ConfigModel cfgModel) {
    return CardSettingsSection(
      header: CardSettingsHeader(
        label: 'Configuration'
      ),
      children: [
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
        CardSettingsInt(
          label: 'Max total tokens',
          initialValue: cfgModel.maxTotalTokens,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setMaxTotalTokens(x))
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
        CardSettingsDouble(
          label: 'Top A',
          initialValue: cfgModel.topA,
          decimalDigits: 3,
          validator: validateNormalizedDouble,
          onSaved: onDoubleSave((x) => cfgModel.setTopA(x))
        ),
        CardSettingsDouble(
          label: 'Penalty alpha',
          initialValue: cfgModel.penaltyAlpha,
          decimalDigits: 3,
          validator: validateNormalizedDouble,
          onSaved: onDoubleSave((x) => cfgModel.setPenaltyAlpha(x))
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
        CardSettingsListPicker<String>(
          label: 'Include generated text in the repetition penalty range',
          initialItem: cfgModel.repetitionPenaltyIncludeGenerated,
          items: const [
            NeodimRepPenGenerated.ignore,
            NeodimRepPenGenerated.expand,
            NeodimRepPenGenerated.slide
          ],
          onSaved: (s) {
            if(s == null)
              return;
            cfgModel.setRepetitionPenaltyIncludeGenerated(s);
          }
        ),
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
        CardSettingsWarpersOrder(
          initialValue: cfgModel.warpersOrder,
          onSaved: (order) => cfgModel.setWarpersOrder(order)
        ),
        CardSettingsInt(
          label: 'Generate extra sequences for quick retries',
          initialValue: cfgModel.extraRetries,
          validator: validateNonNegativeInt,
          onSaved: onIntSave((x) => cfgModel.setExtraRetries(x))
        ),
        CardSettingsSwitch(
          label: 'Stop the generation on ".", "!", "?"',
          initialValue: cfgModel.stopOnPunctuation,
          onSaved: (val) => cfgModel.setStopOnPunctuation(val ?? false)
        ),
        CardSettingsSwitch(
          label: 'Undo the text up to ".", "!", "?", "*"',
          initialValue: cfgModel.undoBySentence,
          onSaved: (val) => cfgModel.setUndoBySentence(val ?? false)
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
        autocorrect: false,
        enableSuggestions: false,
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
