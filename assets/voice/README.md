# Colin's voice

Drop a clip in and he says that line. Ship nothing and he is silent — which is
what the game does today.

    assets/voice/<locale>/<catalogue key>.mp3

`<locale>` is a shipped catalogue id (`en`, `de`, `ja`, …) and the file name is
the key the card's body comes from — `coachtip.welcome.mp3`, not the sentence.
There is no list to keep in step: the asset manifest is the lookup, so a file
that is here is played and one that is not is skipped.

Two rules worth knowing before recording:

- **A line with a name or a fee in it cannot be recorded.** Those cards hand the
  voice no key at all (see `CoachCardFrame.speaksKey`), so they stay quiet
  whatever is in here. The ones worth recording are the fixed story beats.
- **No falling back to English.** A clip is only ever played for the locale it
  is filed under, because a line in the wrong language is worse than silence.

`services/voice_service.dart` holds the rest: he speaks one line at a time, he
is cut when the app goes away, and he has his own volume under the master sound
switch.
