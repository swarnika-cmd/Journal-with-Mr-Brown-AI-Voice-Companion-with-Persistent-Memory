#!/usr/bin/env bash
# measure_turn.sh - time 20 sequential voice turns against a running backend.
#
# Usage:
#   TOKEN=<access token> scripts/measure_turn.sh <base_url> <audio_file>
#   e.g. TOKEN=... scripts/measure_turn.sh http://localhost:8001 my_recording.webm
#
# Timing source: client-side, curl -w '%{time_total}' on POST /api/entries/voice.
# It covers upload, STT, LLM, TTS, sentiment, DB write and the response download.
# The server does not send a total-time header. Per-stage server timings
# (sttMs, llmMs, ttsMs, totalMs) are in the "voice_turn" log line, keyed by the
# X-Request-Id response header, which this script prints for each turn.
#
# Percentiles: nearest-rank. For n sorted samples, p-th percentile is the value
# at rank ceil(p/100 * n) (1-based). With n=20: p50 = 10th value, p95 = 19th.
#
# Degraded turns: the server swallows LLM and TTS provider errors (canned reply,
# mrbrownAudio null) and still returns 200. A turn counts as degraded if the
# body has "degraded":true or "mrbrownAudio":null (null also covers audio with
# no speech). Degraded turns are excluded from the percentiles and counted. If
# the first turn is degraded the script aborts (keys or audio are wrong); the
# exit status is 1 if any turn was degraded.
#
# Pacing: the voice endpoint allows 20 requests per minute per IP, so each turn
# starts at least 4 s after the previous one started (20 turns take about 76 s).
#
# Notes:
#   - Needs real provider keys on the server (Deepgram, ElevenLabs, OpenAI or
#     Gemini). Audio with no speech skips the LLM and TTS stages, so use a
#     recording of someone speaking. scripts/make_sample_wav.py makes a tone
#     that is only good for a smoke test.
#   - Each turn writes a journal entry for the token's user. Use a test account.
#   - A failed turn (non-2xx) prints the server error body and aborts.
set -euo pipefail

N=20
BASE_URL="${1:-}"
AUDIO="${2:-}"
TOKEN="${TOKEN:-}"

if [[ -z "$BASE_URL" || -z "$AUDIO" ]]; then
  echo "usage: TOKEN=<access token> $0 <base_url> <audio_file>" >&2
  exit 2
fi
if [[ -z "$TOKEN" ]]; then
  echo "TOKEN env var is required" >&2
  exit 2
fi
if [[ ! -f "$AUDIO" ]]; then
  echo "audio file not found: $AUDIO" >&2
  exit 2
fi

case "$AUDIO" in
  *.wav) MIME="audio/wav" ;;
  *.mp3) MIME="audio/mpeg" ;;
  *.ogg) MIME="audio/ogg" ;;
  *) MIME="audio/webm" ;;
esac

body_file="$(mktemp)"
hdr_file="$(mktemp)"
trap 'rm -f "$body_file" "$hdr_file"' EXIT

times=()
degraded=0
for i in $(seq 1 "$N"); do
  start=$(date +%s)
  # Token goes through stdin (-H @-), not argv, so it is not visible in ps.
  if ! t=$(printf 'Authorization: Bearer %s\n' "$TOKEN" | curl -sS -o "$body_file" -D "$hdr_file" \
    -w '%{time_total}' --fail-with-body -H @- \
    -F "audio=@${AUDIO};type=${MIME}" \
    "${BASE_URL%/}/api/entries/voice"); then
    echo "turn $i failed; server response:" >&2
    cat "$body_file" >&2
    echo >&2
    exit 1
  fi
  rid=$(tr -d '\r' < "$hdr_file" | awk -F': ' 'tolower($1)=="x-request-id"{print $2}')
  if grep -Eq '"degraded":true|"mrbrownAudio":null' "$body_file"; then
    degraded=$((degraded + 1))
    echo "turn $i: ${t}s request_id=${rid:-none} DEGRADED (excluded)"
    if [[ $i -eq 1 ]]; then
      echo "first turn degraded: check provider keys and that the audio contains speech" >&2
      exit 1
    fi
  else
    echo "turn $i: ${t}s request_id=${rid:-none}"
    times+=("$t")
  fi
  elapsed=$(( $(date +%s) - start ))
  if [[ $i -lt $N && $elapsed -lt 4 ]]; then sleep $(( 4 - elapsed )); fi
done

m=${#times[@]}
if [[ $m -eq 0 ]]; then
  echo "no non-degraded turns" >&2
  exit 1
fi
sorted=$(printf '%s\n' "${times[@]}" | LC_ALL=C sort -n)

nearest_rank() {
  local p=$1
  local rank=$(( (p * m + 99) / 100 ))   # ceil(p/100 * m)
  echo "$sorted" | sed -n "${rank}p"
}

echo "turns=$N  used=$m  degraded=$degraded  p50=$(nearest_rank 50)s  p95=$(nearest_rank 95)s  (client-side curl time_total, nearest-rank)"
[[ $degraded -eq 0 ]]
