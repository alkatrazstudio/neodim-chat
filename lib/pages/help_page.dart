// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

import 'package:flutter/material.dart';
import 'package:help_page/help_page.dart';

const _llamaCppBaseUrl = 'https://github.com/ggml-org/llama.cpp';

const _manualHtml = '''
<p>
  Neodim Chat is a client application that can be used together with
  <a href="$_llamaCppBaseUrl">llama.cpp</a>.
  Before using Neodim Chat, make sure that that server is up and running,
  and accessible (e.g. via LAN IP, for example: 192.168.1.123).
</p>

<h2>Settings</h2>

<p>
  The chat will be between two participants.
  You can write for any of them, and the server can write for any of them too.
</p>

<p>
  Below are explanations for the settings for a conversation.
  Some parameters represent parameters for
  <a href="$_llamaCppBaseUrl">llama.cpp</a>,
  so you can find an additional information about them on the corresponding website</a>.
  It is advisable to read all the documentation about the server you use before using Neodim Chat.
  Some parameters are only available only when other certain parameters are set.
  If the parameter is not supported for any reason it will not be shown on the settings page.
</p>

<h3>Conversation</h3>
<ul>
  <li>
    <strong>Name</strong> - the identifier for your chat.
    Can be any string. Will be shown in the side drawer.
  </li>
  <li>
    <strong>Type</strong> - what this conversation represents.
    "Chat" mean a regular chat between two participants.
    "Adventure" means playing a text adventure game.
    I this case, the first participant (with speech bubbles on the right) represents the player.
    The other participant represents "the story", i.e. it's not a person talking but just simple story text.
    "Story" means just writing a story text as-is.
    "Group chat" is a chat where the second participant is a group of different participants.
    In this case you need to write all the names of these participants
    in the "Group participants names", separating them with commas.
    You can not change the type if there are any messages in the chat.
    One exception: you can convert a chat to a group chat.
  </li>
  <li>
    <strong>Preamble</strong> - the text that will be prepended to the prompt.
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

<h3>Server</h3>
<ul>
  <li>
    <strong>API endpoint</strong> - the URL that points to the llama.cpp server.
    It may contain the protocol and the port, e.g. "http://192.168.1.123:8080".
    Or you can just specify only IP or the hostname, e.g. "192.168.1.123".
    In this case the rest parts (protocol, port, path) will be chosen automatically.
  </li>
  <li>
    <strong>Stream the response</strong> - if set, the generated text will be appearing gradually,
    as soon as the next word/token is generated - it will appear right away.
    If not set - the generated text will only appear at the end, when all the response from the server is completed.
  </li>
  <li>
    <strong>Save the cache after N seconds of processing</strong> -
    save the prompt processing cache on disk after the server spends at least N seconds of processing the request.
    If the cache is saved it will be loaded if you restart the server and Neodim Chat.
    By default, if you just restart the server, but not Neodim Chat, the cache won't be restored.
    However, you may pass --metrics to the server,
    in this case Neodim Chat will attempt to detect whether the server was restarted,
    and reload the cache if needed.
    You need to pass --slot-save-path to the server for the saving feature to work.
    And you must not pass --no-slots.
    The value of 0 will disable the saving.
    However, if the cache is found, it will still be loaded, even if this parameter is zero.
    The unquantized cache will be approximately 1-1.5 GB per 10K tokens.
    You can quantize the cache by passing --cache-type-k and/or --cache-type-v to the server,
    but it may lower the quality of the generated text.
    The cache files are stored in the folder specified in --slot-save-path,
    and they will have filenames like "&lt;uuid&gt;.neodim.cache", e.g. "20fda557-91bb-40d4-9a11-7d795cc78b58.neodim.cache".
    A cache can only be loaded if it was created with the same combination of
    --model, --cache-type-k and --cache-type-v server parameters.
    You can also manually save the cache from the main menu.
  </li>
</ul>

<h3>Sampling</h3>
<ul>
  <li>
    <strong>Generated tokens</strong> - how many tokens to generate for a reply.
  </li>
  <li>
    <strong>Temperature mode</strong> -
    how to calculate the final temperature.
    <ul>
      <li>static - use the specified value</li>
      <li>
        dynamic - automatically adjust the temperature in the specified range.
        The more AI is uncertain about the next token, the more the temperature will rise.
        It can make the text more varying yet coherent at the same time.
      </li>
    </ul>
  </li>
  <li>
    <strong>Temperature</strong> - the randomness of the output.
    Can be any non-negative value.
    Recommended values are 0.5 - 1.
  </li>
  <li>
    <strong>Min. temperature</strong> - the lower bound of the temperature value.
  </li>
  <li>
    <strong>Max. temperature</strong> - the upper bound of the temperature value.
  </li>
  <li>
    <strong>Dynamic temperature exponent</strong> -
    the bigger this value, the slower the temperature will rise.
    Higher values make the text less random.
    Must be a positive value.
  </li>
  <li>
    <strong>Top K</strong> - limiting the amount of chosen tokens.
    Only consider this amount of top-probability results.
    For example, if top_k = 2 the algorithm will only choose between two top results for a next token.
    It's not really recommended using this sampler alone by itself.
    However, it can be used in combination with other sampler.
    The value of 40 is considered to be adequate.
  </li>
  <li>
    <strong>Top P (nucleus sampling)</strong> - limiting the amount of chosen tokens.
    Top-p sampling (sometimes called "nucleus sampling")
    chooses from the smallest possible set of tokens
    whose cumulative probability exceeds the given probability.
    Higher values will include more tokens, which will make the text more random.
    Allowed range: 0 < x < 1. Recommended values: 0.6 - 0.95.
    By default, this sampler is off.
  </li>
  <li>
    <strong>Min P</strong> - limiting the amount of chosen tokens.
    The bigger the value the less random the output text will be.
    Possible values: 0 to 1. Recommended value: 0.05.
    Not recommended to use with Top P or Top K.
  </li>
  <li>
    <strong>Typical sampling</strong> - limiting the amount of chosen tokens.
    Typical sampling will pick samples based not on appearance probability,
    but on expected amount of information produced.
    It can make the resulting text more interesting by excluding the most likely words
    if there's a big pool of words to choose from for the next token.
    Lower values will make the generated text to maintain the same "rhythm" as the prompt.
    Higher values will include more choices for the next token, and the text will be more random.
    Allowed range: 0 < x < 1.
    Recommended values: 0.2 is assumed to be a good choice for a generic story-writing;
    however, higher values may also produce good results, depending on the expected result.
    By default, this filter is off.
  </li>
  <li>
    <strong>Mirostat</strong> - enables Mirostat sampling.
    This sampling will automatically adjust other hyper-params to make the generated text
    not too repetitive, and not too random.
  </li>
  <li>
    <strong>Mirostat Tau</strong> - Mirostat Tau parameter.
    A lower value will result in more focused and coherent text,
    while a higher value will lead to more diverse and potentially less coherent text.
    Proposed values are 3-5.
  </li>
  <li>
    <strong>Mirostat Eta</strong> - Mirostat Eta parameter.
    Influences how quickly the algorithm responds to feedback from the generated text.
    A lower value will result in slower adjustments,
    while a higher learning rate will make the algorithm more responsive.
  </li>
  <li>
    <strong>XTC probability</strong> -
    probability of applying XTC (Exclude Top Choice) sampler when choosing the next token.
    Recommended value: 0.5.
  </li>
  <li>
    <strong>XTC threshold</strong> -
    if XTC (Exclude Top Choice) sampler is applied,
    remove all tokens that have this or higher probability except for the least probable token among them.
    Since at least one token in the threshold range must be preserved,
    the threshold cannot be higher than 0.5, because there can only be one token with a probability higher than 0.5.
    Recommended value: 0.1. Recommended to use in the combination with the Min-P sampler.
  </li>
  <li>
    <strong>DRY multiplier</strong> -
    (Don't Repeat Yourself) repetition penalty multiplier.
    Controls the strength of the DRY sampling effect.
    A value of 0.0 disables DRY sampling, while higher values increase its influence.
    Recommended value: 0.8.
  </li>
  <li>
    <strong>DRY base</strong> -
    sets the base value for the exponential penalty calculation in DRY sampling.
    Higher values lead to more aggressive penalization of repetitions.
    Recommended value: 1.75.
  </li>
  <li>
    <strong>DRY allowed length</strong> -
    the maximum length of repeated sequences that will not be penalized.
    Repetitions shorter than or equal to this length are not penalized.
  </li>
  <li>
    <strong>DRY penalty range</strong> -
    how many recent tokens to consider when applying the DRY penalty.
    A value of 0 considers the entire context.
  </li>
  <li>
    <strong>Top N Sigma</strong> -
    applies Top N Sigma sampling. Helps to maintain coherence at high temperatures.
    A higher value will take more noisy tokens into consideration,
    while a lower value will focus on the more informative region of the sampling space.
    Negative values disable it.
    Only compatible with Top K and Temperature. Disable other samplers and penalties when using Top N Sigma.
    Recommended value: 1.
  </li>
  <li>
    <strong>Warpers order</strong> - the order in which the filters/samplers/warpers are applied.
    The recommended order is the following:
    top k -> repetition penalty -> temperature -> top n sigma -> everything else
  </li>
</ul>

<h3>Penalties</h3>
<ul>
  <li>
    <strong>Repetition penalty</strong> - make generated text more different than the already existing text.
    Change the probability of the tokens that are already included in the input text (preamble and/or prompt).
    Values higher than 1 will decrease the probability that tokens in the input text will appear in the generated text.
    Higher values will apply more penalty, which means that new generated tokens will more likely be different from input tokens.
    The value of 1 will disable this penalty. Recommended values: 1 - 1.3.
    By default, the repetition penalty is off (i.e. the same as specifying 1).
  </li>
  <li>
    <strong>Frequency penalty</strong> -
    make frequently repeated words less likely to appear again.
    The bigger the value, the more this penalty will be applied to a word per instance.
    The optimal value depends on the model.
  </li>
  <li>
    <strong>Presence penalty</strong> -
    the same as the repetition penalty, but additive instead of multiplicative.
    May be preferable for longer texts.
    The optimal value depends on the model.
  </li>
  <li>
    <strong>Penalty range</strong> - how much of the latest text to use for the penalty calculation.
    Setting it to zero will include the entire chat.
  </li>
  <li>
    <strong>Include preamble in the penalty range</strong> -
    if not set then repetition penalty will only be applied to the tokens in the prompt.
  </li>
  <li>
    <strong>Penalty lines without extra symbols</strong> -
    this many last lines of chat will have their punctuation and other symbols preserved
    for the purpose of calculating the penalty.
    Only applies to the chat mode.
  </li>
  <li>
    <strong>Keep the original penalty text</strong> -
    do not modify the penalty text in any way
    (i.e. it will include punctuation, special symbols, newlines, etc).
    In any case, the penalty text won't include the names of the participants.
    Enabling this setting will disable the "Penalty lines without extra symbols" setting.
  </li>
  <li>
    <strong>Remove participant names from the penalty text</strong> -
    if set then the penalty won't be applied to the tokens that represent participant's names.
  </li>
  <li>
  <strong>Blacklist</strong> -
  specify words or phrases to exclude.
  One word/phrase per line.
  This will not ban the lines as a whole, but instead it will ban all the tokens from specified lines.
  Because of that, prefer adding short words.
  May not work properly or impact the coherence of the inference depending on the model.
  </li>
  <li>
  <strong>Add words to the blacklist on retry</strong> -
  when pressing "retry" button, add this number of random words
  from the last speech bubble to a blacklist.
  It means that these words will (probably) not appear on the next try.
  The blacklist is only valid until all previous text remains the same.
  When anything, except the last line, changes, the blacklist will be reset.
  NOTE: this setting highly depends on the model.
  It may not work or give weird results.
</li>
<li>
  <strong>Also add special symbols to the blacklist</strong> -
  add symbols (, ), * to the blacklist.
</li>
<li>
  <strong>Remove old words from the blacklist on retry</strong> -
  removes the specified amount of words from blacklist befoire adding new words.
  Removed words may be re-added, but only on subsequent retries
  (i.e. the removed words won't be re-added immediately).
</li>
</ul>

<h3>Control</h3>
<ul>
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
    <strong>Undo the text up to these symbols: .!?*:()</strong> -
    when pressing the Undo button, only the last sentence will be removed,
    not the whole message.
  </li>
  <li>
    <strong>Combine chat lines</strong> -
    whether to combine consecutive chat lines from one participant into one line.
    This may help AI to generate longer lines in the long run,
    but may confuse some language models.
    "no" - do not combine;
    "only for server" - combine lines before sending them to the server,
    but keep them separate in the user interface,
    the newly generated line will be the continuation of the previous one (only on the server)
    if it has the same participant
    (with this mode AI may not generate anything if it thinks that it won't be able to continue the previous line);
    "previous lines" - the same as "only for server",
    but the server will be told to generate a new line as a separate line of a dialog,
    not a continuation of the previous line
    (however that line will still be concatenated with the previous one on next generations)
  </li>
  <li>
    <strong>Always alternate chat participants in continuous mode</strong> -
    if enabled, there will be no two consecutive lines by the same participant
    when the chat is in continuous generation mode
    (read more about this mode in the "Miscellaneous" section).
  </li>
  <li>
    <strong>Colon at the start inserts the previous participant's name</strong> -
    if enabled, then if you start the message of the left participant with a colon in group chat mode
    the previous participant's name will be used.
    And if you write the message without a colon at all,
    then it will be added as a comment (non-dialog line).
    If this setting is not enabled, then the above logic is inverted:
    starting message with a colon writes a comment
    (does not work if the original line has more than one comma),
    and no colon means the previous participant.
  </li>
  <li>
    <strong>Participant on retry</strong> -
    how to choose the participant when retrying a "left" message in a group chat.
    <ul>
      <li>any - choose any valid participant</li>
      <li>same - choose the same participant as it was in the original message</li>
      <li>different - choose a different participant than the one in the original message</li>
    </ul>
  </li>
</ul>

<h2>Controls</h2>
Below is the list of the controls that are located below the input field.

<h3>Chat/Group Chat mode</h3>
<div><widget name="participants"></widget> Participants (only in the group chat mode) - choose a participant's name.</div>
<div><widget name="undo"></widget> Undo - removes the last message.</div>
<div><widget name="redo"></widget> Redo - restores the previously removed message.</div>
<div><widget name="retry"></widget> Retry - generates new text for the last message.</div>
<div><widget name="genLeft"></widget> Generate a new message for the second (left) participant.</div>
<div><widget name="genRight"></widget> Generate a new message for the first (right) participant.</div>
<div><widget name="addLeft"></widget> Add the user text (in the input field) to the second (left) participant.</div>
<div><widget name="addRight"></widget> Add the user text (in the input field) to the first (right) participant.</div>
<p>
You can also press the send button <widget name="send"></widget> in the input field
or the send button on your keyboard to add currently edited text in the input field
to the chat and start generating a reply.
</p>

<h3>Adventure mode</h3>
<div><widget name="undo"></widget> Undo - removes the last message.</div>
<div><widget name="redo"></widget> Redo - restores the removed message.</div>
<div><widget name="retry"></widget> Retry - generates new text for the last message.</div>
<div><widget name="genLeft"></widget> Generate a new portion of the story.</div>
<div><widget name="addLeft"></widget> Add the user text (in the input field) as a new portion of the story.</div>
<p>
You can also press the send button <widget name="send"></widget> in the input field
or the send button on your keyboard to add currently edited text in the input field
as the player's action.
</p>

<h3>Story mode</h3>
<div><widget name="genLeft"></widget> Generate a new potion of the story.</div>
<div><widget name="undo"></widget> Undo - removes the last message.</div>
<div><widget name="redo"></widget> Redo - restores the removed message.</div>
<div><widget name="retry"></widget> Retry - generates new text for the last message.</div>
<p>
To add your own text to the story press the send button <widget name="send"></widget> in the input field
or the send button on your keyboard.
</p>

<h3>Long tap</h3>
<p>You can long tap a button to perform its secondary action.
Here's the list of secondary actions for each button:</p>

<div><widget name="undo"></widget> Undo - undo the entire speech bubble, ignoring the "Undo the text up to these symbols" setting.</div>
<div><widget name="retry"></widget> Retry - reset the blacklist before retrying</div>
<div><widget name="genLeft"></widget><widget name="genRight"></widget> Generate - continue the last speech bubble instead of generating a new one</div>
<div><widget name="addLeft"></widget><widget name="addRight"></widget> Add - add a message without any formatting</div>

<h2>Miscellaneous</h2>
<ul>
  <li>Tap the message to edit it. It will open an editing dialog.
  You can long press the OK button in it to save the message without formatting (without needing to uncheck the "Auto-format" checkbox).</li>
  <li>If a message has a slight red border around it,
    then it means that it was generated by AI and never modified by you.</li>
  <li>Try not to move away from the main screen while server generates a new message.
    If the main window is out of focus, then the message may not arrive.</li>
  <li>If the input field is empty then pressing the send button <widget name="send"></widget> will
    generate a new reply in the chat mode or a new portion of the story in the adventure mode.</li>
  <li>Long pressing the send button <widget name="send"></widget> will start a continuous generation.
    It can be stopped by pressing the button <widget name="sendContinuous"></widget> again.</li>
  <li>By default, in the group chat mode, you can write non-dialog comments.
    Enter a line without ":" as the left participant, it will be recognized as a comment.
    This behavior can be changed via the "Colon at the start..." setting.</li>
  <li>By default, in the group chat mode, you can start the message of the left participant with a ":".
    This will automatically prepend the previous participant's name.
    This behavior can be changed via the "Colon at the start..." setting.</li>
  <li>If supported by the API server, you can stop the generation
    by pressing the <widget name="stop"></widget> button</li>
  <li>If the context is getting too big for the model, you can truncate it.
    Tap the message you want to be the start of the context, then press "set as context start".
    Messages that won't be passed to the server will be displayed as dimmed.</li>
</ul>
''';

void showHelpPage(BuildContext context) {
  Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (context) => HelpPage(
      appTitle: 'Neodim Chat',
      githubAuthor: 'alkatrazstudio',
      githubProject: 'neodim-chat',
      manualHtml: _manualHtml,
      manualHtmlWidgets: {
        'participants': const Icon(Icons.person),
        'undo': const Icon(Icons.undo),
        'redo': const Icon(Icons.redo),
        'retry': const Icon(Icons.refresh),
        'genLeft': const Icon(Icons.speaker_notes_outlined),
        'genRight': Transform.scale(scaleX: -1, child: const Icon(Icons.speaker_notes_outlined)),
        'addLeft': Transform.scale(scaleX: -1, child: const Icon(Icons.add_comment_outlined)),
        'addRight': const Icon(Icons.add_comment_outlined),
        'send': const Icon(Icons.send),
        'stop': const Icon(Icons.stop),
        'sendContinuous': const Icon(Icons.fast_forward)
      },
      license: HelpPageLicense.gpl3,
      showGitHubReleasesLink: true,
      changelogFilename: 'CHANGELOG.md',
      author: 'Алексей Парфёнов (Alexey Parfenov) aka ZXED',
      authorWebsite: 'https://alkatrazstudio.net/',
      libraries: [
        HelpPagePackage.flutter('http', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('provider', HelpPageLicense.mit),
        HelpPagePackage.flutter('uuid', HelpPageLicense.mit),
        HelpPagePackage.flutter('bubble', HelpPageLicense.bsd2),
        HelpPagePackage.flutter('collection', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('json_annotation', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('path_provider', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('flutter_form_builder', HelpPageLicense.mit),
        HelpPagePackage.flutter('form_builder_validators', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('form_builder_extra_fields', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('intl', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('flutter_lints', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('build_runner', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('json_serializable', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('wakelock_plus', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('dio', HelpPageLicense.mit),
        HelpPagePackage.flutter('json_view', HelpPageLicense.mit),
        HelpPagePackage.flutter('change_case', HelpPageLicense.mit),
        HelpPagePackage.flutter('file_picker', HelpPageLicense.mit),
      ],
      assets: const []
    ))
  );
}
