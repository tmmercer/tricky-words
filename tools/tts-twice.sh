#!/bin/bash
# $1=key $2=text $3=speed -> t/raw_$1.wav ("text, text.") 
cd /tmp/tts; B=sherpa-onnx-v1.13.8-linux-x64-shared; K=kokoro-multi-lang-v1_0; export LD_LIBRARY_PATH=$PWD/$B/lib
body=$(echo "$2" | sed 's/[.!?:]*$//')
$B/bin/sherpa-onnx-offline-tts --kokoro-model=$K/model.onnx --kokoro-voices=$K/voices.bin --kokoro-tokens=$K/tokens.txt \
  --kokoro-data-dir=$K/espeak-ng-data --kokoro-dict-dir=$K/dict --kokoro-lexicon=$K/lexicon-us-en.txt \
  --num-threads=2 --sid=3 --kokoro-length-scale=$3 --output-filename=/home/claude/gen3/t2/raw_$1.wav "$body, $2" >/dev/null 2>&1
