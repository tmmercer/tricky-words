# Tricky Word Treasure Hunt

A touch-friendly game for practicing Letterland tricky words and List A words on an iPad.

Three games, 10 words each:
- **Listen & Find** – hear a word, tap the matching one
- **Read It!** – read the word aloud, tap to check
- **Spell It** – build the word from letter tiles

Missed words are saved to a "Practice my tricky ones" list on the device.

It's a single static `index.html` with no build step.

## Voice

The words and sentences are pre-recorded MP3s in `audio/`, made with the open-source
[Kokoro v1.0](https://github.com/hexgrad/kokoro) text-to-speech model (American voice
`af_heart`, US English pronunciation, slowed down for young readers), run locally through
[sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx).

- `tools/sentences.txt` – the example sentence for each word (used in Spell It)
- `tools/audio-items.tsv` – every clip: key, text, speed
- `tools/generate-audio.sh` – the script that recorded them

If a clip can't load, the game falls back to the device's built-in voice.
