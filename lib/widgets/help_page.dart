// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2022, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Tab {
  final String Function(BuildContext) label;
  final IconData icon;
  final Future<String> Function(BuildContext) htmlFunc;
  Future<String>? _html;

  Tab({
    required this.label,
    required this.icon,
    required this.htmlFunc
  });

  Future<String> html(BuildContext context) {
    _html ??= htmlFunc(context);
    return _html!;
  }
}

String _h(String s) {
  return const HtmlEscape().convert(s);
}

class _KeyValRow {
  final String key;
  final String? keyLink;
  final String val;
  final String? valLink;

  _KeyValRow({
    required this.key,
    this.keyLink,
    required this.val,
    this.valLink
  });

  static String renderLink(String text, String? link) {
    if(link == null)
      return _h(text);
    return '<a href="${_h(link)}">${_h(text)}</a>';
  }

  static String renderRows(List<_KeyValRow> rows) {
    return rows.map((row) {
      return '<tr><td>${renderLink(row.key, row.keyLink)}</td><td>${renderLink(row.val, row.valLink)}</td></tr>';
    }).join();
  }

  static String renderParagraphs(List<_KeyValRow> rows) {
    return rows.map((row) {
      return '<strong style="font-size: ${FontSize.larger.size}">${renderLink(row.key, row.keyLink)}:</strong>'
        '<div style="padding-bottom: 20">${renderLink(row.val, row.valLink)}</div>';
    }).join();
  }
}

class HelpPage extends StatefulWidget {
  const HelpPage();

  @override
  HelpPageState createState() => HelpPageState();

  static void open(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const HelpPage())
    );
  }
}

class HelpPageState extends State<HelpPage> {
  var selectedIndex = 0;

  var pageController = PageController(
    initialPage: 0,
    keepPage: true
  );
  var indexValue = ValueNotifier(0);

  var tabs = [
    manualTab(),
    aboutTab(),
    licensesTab()
  ];

  static const bsd3 = 'BSD 3-Clause';
  static const bsd3Url = 'https://opensource.org/licenses/BSD-3-Clause';
  static const bsd2 = 'BSD 2-Clause';
  static const bsd2Url = 'https://opensource.org/licenses/BSD-2-Clause';
  static const mit = 'MIT';
  static const mitUrl = 'https://opensource.org/licenses/MIT';
  static const appBaseUrl = 'https://github.com/alkatrazstudio/neodim-chat';
  static const appBuildTimestamp = int.fromEnvironment('APP_BUILD_TIMESTAMP');
  static const appGitHash = String.fromEnvironment('APP_GIT_HASH');
  static const serverBaseUrl = 'https://github.com/alkatrazstudio/neodim-server';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neodim Chat')
      ),
      body: Center(
        child: PageView.builder(
          itemBuilder: (context, index) {
            return SingleChildScrollView(
              key: PageStorageKey('help-tab:$index'),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: FutureBuilder<String>(
                  future: tabs[index].html(context),
                  builder: (context, htmlFuture) {
                    if(!htmlFuture.hasData)
                      return const SizedBox.shrink();

                    return Html(
                      data: htmlFuture.data,
                      style: {
                        'th, td': Style(
                          fontSize: FontSize.larger,
                          padding: const EdgeInsets.only(top: 10, bottom: 10, right: 20),
                          border: const Border(bottom: BorderSide(color: Colors.grey))
                        ),
                        'th + th, td + td': Style(
                          padding: const EdgeInsets.only(top: 10, bottom: 10, right: 0)
                        ),
                        'h2, h3': Style(
                          padding: const EdgeInsets.only(top: 20)
                        ),
                        'li': Style(
                          padding: const EdgeInsets.only(bottom: 10),
                          listStylePosition: ListStylePosition.INSIDE
                        )
                      },
                      onLinkTap: (url, context, attributes, element) async {
                        if(url == null)
                          return;
                        if(!await canLaunchUrlString(url))
                          return;
                        await launchUrlString(url, mode: LaunchMode.externalApplication);
                      }
                    );
                  }
                )
              )
            );
          },
          itemCount: tabs.length,
          controller: pageController,
          onPageChanged: (value) {
            indexValue.value = value;
          }
        )
      ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: indexValue,
        builder: (context, int value, child) {
          return BottomNavigationBar(
            items: tabs.map((tab) => BottomNavigationBarItem(
              icon: Icon(tab.icon),
              label: tab.label(context)
            )).toList(),
            currentIndex: value,
            onTap: (newIndex) {
              pageController.animateToPage(
                newIndex,
                duration: const Duration(milliseconds: 200),
                curve: Curves.linear
              );
            }
          );
        }
      )
    );
  }

  static Tab manualTab() {
    return Tab(
      label: (context) => 'Manual',
      icon: Icons.help,
      htmlFunc: (context) async => '''
        <h1 style="text-align: center">Manual</h1>

        <p>
          This is a client application that can be used together with
          <a href="$serverBaseUrl">Neodim Server</a>.
          Before using Neodim Chat, make sure that Neodim Server is up and running,
          and accessible via LAN IP (e.g. 192.168.1.123).
        </p>

        <h2>Settings</h2>

        <p>
          The chat will be between two participants.
          You can write for any of them, and Neodim Server can write for any of them too.
        </p>

        <p>
          Below are explanations for the settings for a conversation.
          Some parameters represent parameters for Neodim Server,
          so you can find an additional information about them on
          <a href="$serverBaseUrl">Neodim Server's website</a>.
          It is advisable to read all Neodim Server documentation before using Neodim Chat.
        </p>

        <h3>Conversation</h3>
        <ul>
          <li>
            <strong>Name</strong> - the identifier for your chat.
            Can by any string. Will be shown in the side drawer.
          </li>
          <li>
            <strong>Preamble</strong> - the text that will sent to Neodim Server
            alongside with the chat text.
            <a href="$serverBaseUrl#prompt-and-preamble">more info</a>
          </li>
          <li>
            <strong>Type</strong> - what this conversation represents.
            "Chat" mean a regular chat between two participants.
            "Adventure" means playing a text adventure game.
            "Story" means just writing a story text as-is.
            The first participant (with speech bubbles on the right) represents the player.
            The other participant represents "the story", i.e. it's not a person talking but just simple story text.
          </li>
        </ul>

        <h3>Participants</h3>
        <ul>
          <li>
            <strong>Person name</strong> - the nickname of the participant.
          </li>
          <li>
            <strong>Person color</strong> - the color of the participant's speech bubble.
          </li>
        </ul>

        <h3>Configuration</h3>
        <ul>
          <li>
            <strong>API endpoint</strong> - the full URL that points to your Neodim Server instance.
            Must contain the protocol, the port and the "/generate" part,
            e.g. "http://192.168.1.123:8787/generate".
          </li>
          <li>
            <strong>Generated tokens</strong> - how many tokens to generate for a reply.
            <a href="$serverBaseUrl#generated_tokens_count-int-required">more info</a>
          </li>
          <li>
            <strong>Max total tokens</strong> - total amount of tokens that should be processed
            by Neodim Server when generating a reply.
            <a href="$serverBaseUrl#max_total_tokens-int-required">more info</a>
          </li>
          <li>
            <strong>Temperature</strong> - the randomness of the output.
            <a href="$serverBaseUrl#temperature-float-optional">more info</a>
          </li>
          <li>
            <strong>Top K</strong> - limiting the amount of chosen tokens.
            <a href="$serverBaseUrl#top_k-int-optional">more info</a>
          </li>
          <li>
            <strong>Top P (nucleus sampling)</strong> - limiting the amount of chosen tokens.
            <a href="$serverBaseUrl#top_p-float-optional">more info</a>
          </li>
          <li>
            <strong>Tail-free sampling</strong> - limiting the amount of chosen tokens.
            <a href="$serverBaseUrl#tfs-float-optional">more info</a>
          </li>
          <li>
            <strong>Typical sampling</strong> - limiting the amount of chosen tokens.
            <a href="$serverBaseUrl#typical-float-optional">more info</a>
          </li>
          <li>
            <strong>Top A</strong> - limiting the amount of chosen tokens.
            <a href="$serverBaseUrl#top_a-float-optional">more info</a>
          </li>
          <li>
            <strong>Penalty alpha</strong> - enables contrastive search.
            <a href="$serverBaseUrl#penalty_alpha-float-optional">more info</a>.
          </li>
          <li>
            <strong>Repetition penalty</strong> - make generated text more different than the already existing text.
            <a href="$serverBaseUrl#repetition_penalty-float-optional">more info</a>
          </li>
          <li>
            <strong>Repetition penalty range</strong> - how much of the latest text to use for the penalty calculation.
            Setting it to zero will include the entire chat.
            <a href="$serverBaseUrl#repetition_penalty_range-int-optional-default0">more info</a>
          </li>
          <li>
            <strong>Repetition penalty slope</strong> -
            <a href="$serverBaseUrl#repetition_penalty_slope-float-optional">more info</a>
          </li>
          <li>
            <strong>Include preamble in the repetition penalty range</strong> - self-explanatory.
            <a href="$serverBaseUrl#repetition_penalty_include_preamble-bool-optional-defaultfalse">more info</a>
          </li>
          <li>
            <strong>Include generated text in the repetition penalty range</strong> -
            how to include the generated text in the repetition penalty range.
            <a href="$serverBaseUrl#repetition_penalty_include_generated-enumignoreallowexpandslide-optionaldefaultslide">more info</a>
          </li>
          <li>
            <strong>Truncate the repetition penalty range to the input</strong> -
            limit the range to the input tokens.
            <a href="$serverBaseUrl#repetition_penalty_truncate_to_input-bool-optional-defaultfalse">more info</a>
          </li>
          <li>
            <strong>Repetition penalty lines without extra symbols</strong> -
            this many last lines of chat will have their punctuation and other symbols preserved
            for the purpose of calculating the repetition penalty.
            Only applies to the chat mode.
          </li>
          <li>
            <strong>Keep the original repetition penalty text</strong> -
            do not modify the repetition penalty text in any way
            (i.e. it will include punctuation, special symbols, newlines, etc).
            In any case, the repetition penalty text won't include the names of the participants.
            Enabling this setting will disable the "Repetition penalty lines without extra symbols" setting.
          </li>
          <li>
            <strong>Warpers order</strong> - the order in which the filters are applied
            (repetition penalty, temperature, top K, top P, tail-free, typical, top A).
            <a href="$serverBaseUrl#warpers_order-string-optional">more info</a>
          </li>
          <li>
            <strong>Generate extra sequences for quick retries</strong> -
            generate multiple replies at once and then use those replies
            when pressing the "retry" button without making additional requests to the server.
          </li>
          <li>
            <strong>Stop the generation on ".", "!", "?"</strong> -
            stops generating the text if any of these punctuation symbols are met.
            It may help to generate messages with models than have problems with newlines (e.g. XGLM or OPT).
          </li>
          <li>
            <strong>Undo the text up to ".", "!", "?", "*"</strong> -
            when pressing the Undo button, only the last sentence will be removed,
            not the whole message.
          </li>
        </ul>

        <h2>Controls</h2>
        Below is the list of the controls that are located below the input field.
        The controls are listed from left to right.

        <h3>Chat mode</h3>

        <h4>First row</h4>
        <ul>
          <li>Undo - removes the last message.</li>
          <li>Redo - restores the previously removed message.</li>
          <li>Retry - generates new text for the last message.</li>
        </ul>

        <h4>Second row</h4>
        <ul>
          <li>Generate new message for the second (left) participant.</li>
          <li>Generate new message for the first (right) participant.</li>
          <li>Add the user text (in the input field) to the second (left) participant.</li>
          <li>Add the user text (in the input field) to the first (right) participant.</li>
        </ul>

        You can also press the send button in the input field
        or the send button on your keyboard to add currently edited text in the input field
        to the chat and start generating a reply.

        <h3>Adventure mode</h3>

        <h4>First row</h4>
        <ul>
          <li>Undo - removes the last message.</li>
          <li>Redo - restores the removed message.</li>
          <li>Retry - generates new text for the last message.</li>
        </ul>

        <h4>Second row</h4>
        <ul>
          <li>Generate new potion of the story.</li>
          <li>Add the user text (in the input field) as a new portions of the story.</li>
        </ul>

        <h3>Story mode</h3>

        <ul>
          <li>Generate new potion of the story.</li>
          <li>Undo - removes the last message.</li>
          <li>Redo - restores the removed message.</li>
          <li>Retry - generates new text for the last message.</li>
        </ul>

        You can also press the send button in the input field
        or the send button on your keyboard to add currently edited text in the input field
        as the player's action.
        It's preferable to prefix all player's actions with "You",
        e.g. "You steal the crown" instead of just "Steal the crown".

        <h2>Miscellaneous</h2>
        <ul>
          <li>The red line(s) at the bottom represents the GPU usage.</li>
          <li>If the message is dimmed it means it wasn't part of the prompt (context) that was passed to the AI.
            Increase the "Max total tokens" parameter to pass more text to the AI.</li>
          <li>If a message has a slight red border around it,
            then it means that it was generated by AI and never modified by you.</li>
          <li>Try not to move away from the main screen while Neodim Server generates a new message.
            If the main window is out of focus, then the message may not arrive.</li>
          <li>If the input field is empty then pressing the send button will
            generate a new reply in the chat mode or a new portion of the story in the adventure mode.</li>
          <li>Long pressing the submit button will start a continuous generation.
            It can be stopped by pressing the button again.</li>
        </ul>
      '''
    );
  }

  static Tab aboutTab() {
    return Tab(
      label: (context) => 'About',
      icon: Icons.music_note,
      htmlFunc: (context) async {
        var info = await PackageInfo.fromPlatform();
        var buildDate = DateTime.fromMillisecondsSinceEpoch(appBuildTimestamp * 1000);
        var buildStr = DateFormat.yMMMMd().format(buildDate);

        return '''
          <h1 style="text-align: center">Neodim Chat</h1>
          <div style="text-align: center; padding-bottom: 50"><strong><em>v${_h(info.version)}</em></strong></div>
          ${_KeyValRow.renderParagraphs([
            _KeyValRow(key: 'Website', val: appBaseUrl, valLink: appBaseUrl),
            _KeyValRow(key: 'Google Play page', val: 'https://play.google.com/store/apps/details?id=${info.packageName}', valLink: 'https://play.google.com/store/apps/details?id=${info.packageName}'),
            _KeyValRow(key: 'File a bug report', val: '$appBaseUrl/issues', valLink: '$appBaseUrl/issues'),
            _KeyValRow(key: 'Changelog', val: '$appBaseUrl/blob/master/CHANGELOG.md', valLink: '$appBaseUrl/blob/master/CHANGELOG.md'),
            _KeyValRow(key: 'Build date', val: buildStr),
            _KeyValRow(key: 'Git hash', val: appGitHash, valLink: '$appBaseUrl/tree/$appGitHash'),
            _KeyValRow(key: 'Package name', val: info.packageName),
            _KeyValRow(key: 'Build signature', val: info.buildSignature),
            _KeyValRow(key: 'Build number', val: info.buildNumber),
            _KeyValRow(key: 'License', val: 'GPLv3', valLink: 'https://www.gnu.org/licenses/gpl-3.0.txt'),
            _KeyValRow(key: 'Author', val: 'Алексей Парфёнов (Alexey Parfenov) aka ZXED'),
            _KeyValRow(key: "Author's website", val: 'https://alkatrazstudio.net/', valLink: 'https://alkatrazstudio.net/')
          ])}
          ''';
      }
    );
  }

  static Tab licensesTab() {
    return Tab(
      label: (context) => 'Licenses',
      icon: Icons.sticky_note_2,
      htmlFunc: (context) async => '''
        <h1 style="text-align: center">Licenses</h1>

        <h2>Libraries</h2>
        <p>
          Below is the list of all libraries that are directly used by Neodim Chat.
          These libraries can use some other libraries.
          Tap on a library name to go to its website.
          Tap on a license name to read the license text online.
        </p>

        <table>
          <thead>
            <tr>
              <th>Library</th>
              <th>License</th>
            </tr>
          </thead>
          <tbody>
          ${_KeyValRow.renderRows([
            _KeyValRow(key: 'Flutter', keyLink: 'https://flutter.dev', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'http', keyLink: 'https://pub.dev/packages/http', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'provider', keyLink: 'https://pub.dev/packages/provider', val: mit, valLink: mitUrl),
            _KeyValRow(key: 'uuid', keyLink: 'https://pub.dev/packages/uuid', val: mit, valLink: mitUrl),
            _KeyValRow(key: 'bubble', keyLink: 'https://pub.dev/packages/bubble', val: bsd2, valLink: bsd2Url),
            _KeyValRow(key: 'collection', keyLink: 'https://pub.dev/packages/collection', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'json_annotation', keyLink: 'https://pub.dev/packages/json_annotation', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'path_provider', keyLink: 'https://pub.dev/packages/path_provider', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'card_settings', keyLink: 'https://pub.dev/packages/card_settings', val: mit, valLink: mitUrl),
            _KeyValRow(key: 'flutter_html', keyLink: 'https://pub.dev/packages/flutter_html', val: mit, valLink: mitUrl),
            _KeyValRow(key: 'url_launcher', keyLink: 'https://pub.dev/packages/url_launcher', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'package_info_plus', keyLink: 'https://pub.dev/packages/package_info_plus', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'intl', keyLink: 'https://pub.dev/packages/intl', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'flutter_lints', keyLink: 'https://pub.dev/packages/flutter_lints', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'build_runner', keyLink: 'https://pub.dev/packages/build_runner', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'json_serializable', keyLink: 'https://pub.dev/packages/json_serializable', val: bsd3, valLink: bsd3Url),
            _KeyValRow(key: 'wakelock', keyLink: 'https://pub.dev/packages/wakelock', val: bsd3, valLink: bsd3Url)
          ])}
          </tbody>
        </table>

        <h2>Assets</h2>
        <p>
          Below is the list of all assets that are directly used by {appTitle}.
          Some libraries that are used in {appTitle} may contain and/otr use other assets.
          Tap on an asset name to go to its website. Tap on a license name to read the license text online.
        </p>

        <table>
          <thead>
            <tr>
              <th>Asset</th>
              <th>License</th>
            </tr>
          </thead>
          <tbody>
          ${_KeyValRow.renderRows([
            _KeyValRow(key: 'Material design icons', keyLink: 'https://google.github.io/material-design-icons/', val: 'Apache License 2.0', valLink: 'https://www.apache.org/licenses/LICENSE-2.0.txt')
          ])}
          </tbody>
        </table>
      '''
    );
  }
}
