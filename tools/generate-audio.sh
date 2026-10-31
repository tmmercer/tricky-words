#!/bin/bash
# usage: run.sh shard nshards
cd /tmp/tts; B=sherpa-onnx-v1.13.8-linux-x64-shared; K=kokoro-en-v0_19; export LD_LIBRARY_PATH=$PWD/$B/lib
mkdir -p /home/claude/gen/wav
awk -F'\t' -v s=$1 -v n=$2 '(NR-1)%n==s' /home/claude/gen/items.tsv | while IFS=$'\t' read -r k t; do
  [ -s /home/claude/gen/wav/$k.wav ] && continue
  $B/bin/sherpa-onnx-offline-tts --kokoro-model=$K/model.onnx --kokoro-voices=$K/voices.bin --kokoro-tokens=$K/tokens.txt --kokoro-data-dir=$K/espeak-ng-data --num-threads=2 --sid=1 --kokoro-length-scale=1.1 --output-filename=/home/claude/gen/wav/$k.wav "$t" >/dev/null 2>&1
done
