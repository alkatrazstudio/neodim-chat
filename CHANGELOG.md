# Neodim Chat - CHANGELOG


## v0.8.1 (August 26, 2023)

- Added: a button to choose a participant name for the group chat
- Added: "Colon at the start inserts the previous participant's name" flag
- Fixed: long tap on the Add button
- Fixed: continuing the message (by long tap on the Generate button) in group chat mode
- Changed: capitalize first letter of a group chat participant
- Improved: "Undo the text up to these symbols" algorithm
- Improved: message formatting


## v0.8.0 (August 6, 2023)

- Changed: Neodim Server v0.13 is required
- Changed: default settings
- Added: secondary actions to the buttons
- Added: new options for retry blacklist
  ("Also add special symbols to blacklist" and "Remove old words from blacklist on retry")
- Added: ability to write comments in a group chat
- Added: ability to auto-generate the previous participant name in the group chat mode
- Added: new way to concatenate dialog lines (Combine chat lines = `previous lines`)
- Improved: try not to generate just an empty text
- Improved: formatting and auto-correction


## v0.7.1 (June 18, 2023)

- Added: "Add words to blacklist on retry" option
- Fixed: help page formatting and text


## v0.7.0 (April 23, 2023)

- Changed: Neodim Server v0.11 is required
- Added: [group chat mode](README.md#group-chat-mode)
- Added: ability ot change the author of the message
- Added: "Always alternate chat participants in continuous mode" option
- Added: "No repeat N-gram size" option
- Added: "Remove participant names from repetition penalty text" option
- Added: "Combine chat lines" option
- Added: "Penalty alpha" option
- Changed: treat colon and asterisk as a sentence separator while performing undo
- Improved: messages formatting and auto-corrections
- Improved: write error message if using incompatible Neodim Server version


## v0.6.1 (February 19, 2023)

- Improved: messages formatting and auto-corrections
- Changed: submitting empty text is not allowed anymore


## v0.6.0 (December 18, 2022)

- Changed: Neodim Server v0.8 is required
- Changed: the original penalty text is now kept intact by default
- Added: continuous text generation (on long pressing the submit button)
- Improved: stopping on sentence end
- Improved: the warpers order now include repetition penalty


## v0.5.0 (July 31, 2022)

- Added: ability to undo the text by sentence
- Changed: the leading punctuation is now not lost in the adventure/story mode
- Changed: the undo stack is now not auto-cleared
- Changed: default settings
- Fixed: some auto-correction rules
- Fixed: participant colors are not updated right away


## v0.4.0 (July 17, 2022)

- Added: support for typical sampling
- Added: support for top A sampling
- Added: ability to reorder filters/sampling/warpers
- Added: ability to clear all messages from a conversation
- Added: ability to duplicate a conversation
- Added: textual view of a conversation
- Added: ability to keep the unfiltered repetition penalty text
- Added: story mode
- Changed: default settings
- Fixed: various problems with adventure mode text


## v0.3.0 (July 3, 2022)

- Added: option to stop the generation on `.`, `!` or `?`.
- Improved: new auto-correct rules
- Improved: stop on sequence-end tokens
- Changed: formatting edited messages in adventure mode
  won't capitalize the first letter and won't set the trailing dot
- Changed: debug and release builds now use the same signing config
- Fixed: error texts in settings


## v0.2.0 (June 12, 2022)

- Added: auto-formatting edited messages
- Added: removing messages


## v0.1.1 (May 9, 2022)

- Open links in an external browser


## v0.1.0 (May 8, 2022)

- Initial release
