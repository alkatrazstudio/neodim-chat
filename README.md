# Neodim Chat

A mobile application that allows you to chat with AI via
[Neodim Server](https://github.com/alkatrazstudio/neodim-server)
or [llama.cpp](https://github.com/ggerganov/llama.cpp).

**NOTE:** Before installing this application make sure that you can run
either [Neodim Server](https://github.com/alkatrazstudio/neodim-server)
or [llama.cpp](https://github.com/ggerganov/llama.cpp)
and that you understand how these servers works.
Neodim Chat fully relies on these external servers and does not work without them.

You can read the detailed help in the app itself.


## WARNING: The app will soon be removed from Google Play!

Neodim Chat will be removed from Google Play at the end of January 2025.
You will probably be able to continue to use this app if it's already installed,
but if you want to receive further updates you should migrate to the version from GitHub releases.

Here are the steps:

1. Update Neodim Chat from Google Play to the version `0.13.0` or later.
2. Open the app.
3. Open the side panel and choose `Export`.
4. On the export screen select all conversations and press `Export`.
5. Save the resulting JSON file somewhere.
6. Download [the latest app version](https://github.com/alkatrazstudio/neodim-chat/releases/latest) from GitHub releases.
7. Try to install this version.
8. If it fails, remove your current app and install the one from GitHub releases.
9. Open the app.
10. Open the side panel and choose `Import`.
11. Find and choose the exported JSON file.
12. On the import screen select all conversations and press `Import`.


## Key features

* Chat between [two](#chat-mode) or [more](#group-chat-mode) participants
* The next chat participant can be chosen by AI
* Write a [story](#story-mode) (as a "monologue" of one participant)
* Text [adventure game](#adventure-mode) simulation
* Write comments in between chat lines (i.e. non-dialog text)
* Quick controls to generate/edit messages for any chat participant and undo/redo/retry messages
* Only the required amount of tokens are requested, i.e. not wasting GPU time on what is not needed
* Continuous generation (AI chats with itself or generates a story until manually stopped)
* Advanced repetition penalty settings
* Force the use of new words when retrying message generation, i.e. no same message on retry
* Generate several messages upfront for quick retries (no loss of speed, but requires more VRAM, also only available when using Neodim Server)
* Auto-correcting some English grammar and punctuation, e.g. `i dont know, mr anderson` => `I don't know, Mr. Anderson.`
* View/copy the chat/story content as plain text
* Undo the text by sentence
* Color customization for speech bubbles
* Built-in help


## Chat mode

The main purpose of Neodim Chat is to allow you to have a conversation
with a chat bot that is powered by a language model.
The list of supported models depends on the chosen server:
* [Models supported by Neodim Server](https://github.com/alkatrazstudio/neodim-server#supported-models)
* [Models supported by llama.cpp](https://github.com/ggerganov/llama.cpp#description)

**An example of the chat mode**

<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/1_en-US.png?raw=true" alt="Chat mode" title="Chat mode" width="350" />

All blue messages were generated by AI.


## Group chat mode

This is similar to the chat mode, but allows you to have a conversation with multiple participants.

**An example of the group chat mode**

<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/2_en-US.png?raw=true" alt="Group chat mode" title="Group chat mode" width="350" />

All blue messages except the first two were generated by AI.

**Notes:**

* Not all language models support conversations between multiple participants.

* The next participant is chosen by the AI.
  But the AI may be confused about this when there's no context,
  so it's advisable to first write at least one or two chat lines for all other participants yourself
  (using `<name>: <message>` format).


## Adventure mode

Adventure mode lets you play a text adventure game.
In this mode the first chat participant is the player,
and the other one is the "story" (or a game master).

AI can't generate the player actions,
but you can write the story.

You may want to prefix all player's actions with "You",
e.g. "You pat the goblin" instead of just "Pat the goblin".
Or, you can write something like this in the preamble:
```
This is a transcript of a text adventure game.
Player choices start with ">" prompt.
```
The `>` symbol is used internally as the player's prompt,
so you may want to inform the AI about it in the preable.
With this preamble you may try to write your actions without "you",
e.g. just "Pat the goblin".

It may also help if you first write a couple responses yourself
to set the model on the right track.

But in the end, the method of achieving the best text adventure experience really depends on the model.

**An example of the adventure mode**

<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/3_en-US.png?raw=true" alt="Adventure mode" title="Adventure mode" width="350" />

All blue messages except the first one were generated by AI.


## Story mode

Story mode will let just write any text, but in "chat format".

In this mode there will be only one "chat participant",
and the whole text will be their "monologue".

**An example of the story mode**

<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/4_en-US.png?raw=true" alt="Story mode" title="Story mode" width="350" />

All blue messages except the first one were generated by AI.


## More screenshots

<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/5_en-US.png?raw=true" alt="Settings page" title="Settings page" width="350" />
<img src="fastlane/metadata/android/en-US/images/phoneScreenshots/6_en-US.png?raw=true" alt="Debug page" title="Debug page" width="350" />


## Download

Download the latest app version [here](https://github.com/alkatrazstudio/neodim-chat/releases/latest).

Google Play version will be removed soon.
Read the [migration guide](#warning-the-app-will-soon-be-removed-from-google-play).

If you still want to install the Google Play version:

<a target='_blank' rel='noopener noreferrer nofollow' href='https://play.google.com/store/apps/details?id=net.alkatrazstudio.neodim_chat'><img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' width='240'/></a>

Google Play and the Google Play logo are trademarks of Google LLC.


## Build

Neodim Chat is made with [Flutter](https://flutter.dev).

To build this application do the following:

1. Download this repository.

2. Install Flutter and Android SDK. It's easier to do it from [Android Studio](https://developer.android.com/studio).

3. At this point you can already debug the application from Android Studio.
   To build the release version follow the next steps.

4. Go inside the repository root and create the file
   `android/key.properties` based on [android/key.template.properties](android/key.template.properties).
   Fill in all fields.
   For more information see the official "[Signing the app](https://flutter.dev/docs/deployment/android#signing-the-app)" tutorial.

5. To build the release APK run `./build.sh apk` inside the repository root.
   To build the release Android App Bundle run `./build.sh bundle`.
   These scripts will remove the entire `build` directory before building,
   so e.g. `./build.sh bundle` will remove the APK file that was built by `./build.sh apk`.


## Upload to Google Play

For uploading production releases this project uses [fastlane](https://fastlane.tools).

1. Create `fastlane/Appfile` file using [fastlane/Appfile.template](fastlane/Appfile.template) as a template.

2. Use the following instructions to obtain `api-secret.json` file: https://docs.fastlane.tools/actions/supply/#setup.

3. Install [Bundler](https://bundler.io), e.g. on Ubuntu: `sudo apt install ruby-bundler`.

4. Run `bundle install`. It will install fastlane.

5. Make appropriate changes in `fastlane/metadata/android`.

6. Build and deploy a new release: `./build.sh upload`.

Repeat `5` and `6` for each new release.
These steps are not exhaustive. Consult [fastlane docs](https://docs.fastlane.tools) for more information.


## License

GPLv3
