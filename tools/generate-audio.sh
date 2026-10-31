#!/bin/bash
# Generates audio/*.wav with Kokoro v1.0 (American voice af_heart, US lexicon) via sherpa-onnx.
cd /tmp/tts; B=sherpa-onnx-v1.13.8-linux-x64-shared; K=kokoro-multi-lang-v1_0; export LD_LIBRARY_PATH=$PWD/$B/lib
OUT=/home/claude/gen2/wav; mkdir -p $OUT
while IFS=$'\t' read -r k t speed; do
  [ -s $OUT/$k.wav ] && continue
  $B/bin/sherpa-onnx-offline-tts --kokoro-model=$K/model.onnx --kokoro-voices=$K/voices.bin --kokoro-tokens=$K/tokens.txt \
    --kokoro-data-dir=$K/espeak-ng-data --kokoro-dict-dir=$K/dict --kokoro-lexicon=$K/lexicon-us-en.txt \
    --num-threads=2 --sid=3 --kokoro-length-scale=$speed --output-filename=$OUT/$k.wav "$t" >/dev/null 2>&1
done < /home/claude/gen2/items.tsv
echo DONE $(ls $OUT | wc -l)
