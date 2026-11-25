#!/usr/bin/env bash
# Benchmark llama-server with the Qwen3.8 MTP model: VRAM, prompt processing
# (~10k tokens) and generation speed. Starts a server on :8099, then stops it.
#
# Usage (Git Bash):  my-setup/bench-server.sh <label> [extra llama-server args...]
#   my-setup/bench-server.sh n4 -c 98304 -ngl all -fa on -ctk q8_0 -ctv q8_0 \
#       --spec-type draft-mtp --spec-draft-n-max 4 --spec-draft-p-min 0.2
#
# Env overrides:
#   SERVER=path/to/llama-server.exe   another build (default: this repo's build\bin)
#   PROMPT="..."                      generation prompt (default: a coding task)
#   MAX_TOKENS=N                      tokens to generate (default: 600)
# Server logs go to my-setup/bench-logs/<label>.log (git-ignored).
set -u
[ $# -ge 1 ] || { sed -n '2,13p' "$0"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
LABEL=$1; shift

CUDA=$(ls -d "/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA"/v* 2>/dev/null | sort -V | tail -1)
[ -n "$CUDA" ] && export PATH="$CUDA/bin/x64:$CUDA/bin:$PATH"

MODEL=$(ls /c/Users/volen/.cache/huggingface/hub/models--ISTA-DASLab--Qwen3.8-27B-GSQ-RCO-GGUF/snapshots/*/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-mtp.gguf | head -1)
mkdir -p "$HERE/bench-logs"
LOG="$HERE/bench-logs/$LABEL.log"

"${SERVER:-$REPO/build/bin/llama-server.exe}" -m "$MODEL" --host 127.0.0.1 --port 8099 -np 1 --no-mmproj "$@" >"$LOG" 2>&1 &
PID=$!
for i in $(seq 1 180); do
  curl -sf http://127.0.0.1:8099/health >/dev/null 2>&1 && break
  kill -0 $PID 2>/dev/null || { echo "[$LABEL] server died:"; grep -iE "error|fail|out of memory" "$LOG" | tail -5; exit 1; }
  sleep 1
done
VRAM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader)

# Long prompt (~10k tokens) for prompt-processing speed
BODY=$(mktemp)
python -c "import json;print(json.dumps({'prompt':'Summarize in one sentence: ' + ' '.join(f'Item {i}: the quick brown fox jumps over the lazy dog number {i}.' for i in range(500)),'n_predict':1,'cache_prompt':False}))" >"$BODY"
PP=$(curl -s http://127.0.0.1:8099/completion -d @"$BODY" \
  | python -c "import sys,json;t=json.load(sys.stdin)['timings'];print(f\"pp {t['prompt_n']} tok @ {t['prompt_per_second']:.0f} t/s\")")
rm -f "$BODY"

# Generation: code task by default (realistic for MTP acceptance), 600 tokens
# (body built with json.dumps so PROMPT may contain quotes/newlines, e.g. PROMPT="$(cat file)")
export PROMPT="${PROMPT:-Write a complete Python implementation of an LRU cache class with get/put, type hints, docstrings and unit tests.}"
BODY=$(mktemp)
python -c "import json,os;print(json.dumps({'messages':[{'role':'user','content':os.environ['PROMPT']}],'max_tokens':int(os.environ.get('MAX_TOKENS','600')),'temperature':0.6,'chat_template_kwargs':{'enable_thinking':False}}))" >"$BODY"
GEN=$(curl -s http://127.0.0.1:8099/v1/chat/completions -d @"$BODY" \
  | python -c "import sys,json;d=json.load(sys.stdin);t=d['timings'];a=t.get('draft_n_accepted');n=t.get('draft_n');acc=f', draft accept {a}/{n}' if n else '';print(f\"tg {t['predicted_n']} tok @ {t['predicted_per_second']:.1f} t/s{acc}\")")

rm -f "$BODY"

echo "[$LABEL] VRAM $VRAM | $PP | $GEN"
kill $PID 2>/dev/null; wait $PID 2>/dev/null
sleep 2
