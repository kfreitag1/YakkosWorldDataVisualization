#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") -i INDICATOR [options]

Generates the remotion video / rubberband 
  audio and combines them with FFMPEG.

Video options:
-i, --indicator  WDB indicator (eg. SP.POP.TOTL) (REQUIRED)
-f, --format     Py format string (eg. "{:,.0f} people")
-t, --title      Title string (eg. "Population (total)")

-b, --background Background option (def. TOPOGRAPHIC)
-m, --min-speed  Min segment speed (def. 0.3)
-x, --max-speed  Max segment speed (def. 2.5)
-q, --inequality Inequality factor (def. 0.9)

Helper options:
-h, --help      Print this help and exit
-bg,            Print background options
-v, --verbose   Print script debug info
-p, --preview   Generate preview images to check title and end card
EOF
  exit
}

background() {
  cat <<EOF
TOPOGRAPHIC FUNKY  JIGSAW  JUPITER CUTOUT
HOUNDSTOOTH YYY    CIRCUIT SQUARES AUTUMN
TRIANGLES   FOOD   LINES   LISBON  RANDOM
BATHROOM    GEARS  PIANO   LEAF    MOROCCAN
HEXAGONS    SKULLS ZIGZAG  GREEK   ANCHOR
DOMINOES    ARCS
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # Default values
  format_string='{:,.0f}'
  title='UNTITLED'
  ascending=false
  background='TOPOGRAPHIC'
  min_speed=0.3
  max_speed=3.0
  inequality=0.9
  preview=false

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -bg ) background ;;
    -v | --verbose) set -x ;;
    -a | --ascending) ascending=true ;;
    -p | --preview) preview=true ;;
    -i | --indicator)
      indicator="${2-}"
      shift
      ;;
    -f | --format)
      format_string="${2-}"
      shift
      ;;
    -t | --title)
      title="${2-}"
      shift
      ;;
    -b | --background)
      background="${2-}"
      shift
      ;;
    -m | --min-speed)
      min_speed="${2-}"
      shift
      ;;
    -x | --max-speed)
      max_speed="${2-}"
      shift
      ;;
    -q | --inequality)
      inequality="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # Require indicator parameter
  [[ -z "${indicator-}" ]] && die "Missing required parameter: indicator"

  return 0
}

parse_params "$@"

# Run pre-generation python script from that directory
cd "${script_dir}/pre_generate"
.venv/bin/python generate_video_input.py "$indicator" \
 "$format_string" "$title" "$ascending" "$background" \
 "$min_speed" "$max_speed" "$inequality" "$preview"
cd ..

# Generate remotion stills/video from generation folder
cd generate_video
if $preview ; then
  # If previewing, genenerate stills at selected frames
  npx remotion still main ../preview1.png --frame=60
  npx remotion still main ../preview2.png --frame=400
  npx remotion still main ../preview3.png --frame=-2
else
  # Render 4k complete video
  npx remotion render main ../video.mp4 --concurrency 8 \
  --jpeg-quality 90 --crf 16 --scale 3 --muted \
#   --gl angle  # WAY faster rendering, but has a memory leak...

  # Combine with audio into final output
  cd ..
  ffmpeg -i video.mp4 -i audio.wav -c:v copy -c:a aac output.mp4
fi