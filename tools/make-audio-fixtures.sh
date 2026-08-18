#!/usr/bin/env bash
#
# Generates one audio fixture per corpus case using macOS text-to-speech, so
# the full audio → transcript → polish path can be exercised on a Mac with no
# microphone (the Mac Studio has none).
#
# Synthetic speech is not real dictation: no accent, no hesitation timing, no
# trailing-off. But the fillers are spoken, so the transcriber sees them and
# the polisher has something to remove. Good enough to catch pipeline
# regressions; not a substitute for real recordings when tuning the prompt.
#
# Usage: tools/make-audio-fixtures.sh [corpus.json] [output-dir]

set -euo pipefail

CORPUS="${1:-packages/SpokeKit/Fixtures/corpus.json}"
OUTPUT="${2:-packages/SpokeKit/Fixtures/audio}"
VOICE="${SPOKE_VOICE:-Samantha}"

mkdir -p "$OUTPUT"
echo "voice: $VOICE"

jq -r '.cases[] | "\(.id)\t\(.transcript)"' "$CORPUS" \
    | while IFS=$'\t' read -r id transcript; do
        say -v "$VOICE" -o "$OUTPUT/$id.aiff" "$transcript"
        echo "  $id.aiff"
    done
