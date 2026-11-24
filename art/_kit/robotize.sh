#!/bin/zsh
# Turns a human voice recording into a robot voice for Year 2029.
# Usage: _kit/robotize.sh <in.wav|m4a> <out.mp3>
# Chain: pitch down a little, ring modulate with a 70 Hz sine (mixed with some dry voice so words
# stay clear), light bit crush, short metallic echo, phone style band limit, then even out the level and limit peaks.
set -e
if [ $# -ne 2 ]; then
  echo "usage: $0 <in.wav|m4a> <out.mp3>" >&2
  exit 1
fi
in=$1
out=$2
ffmpeg -v error -y -i "$in" -filter_complex "
[0:a]aformat=sample_fmts=fltp:channel_layouts=mono,aresample=44100,
 asetrate=44100*0.9,aresample=44100,atempo=1.111,
 highpass=f=90,asplit=2[dry][toring];
sine=frequency=70:sample_rate=44100[carrier];
[toring][carrier]amultiply,volume=2[ring];
[dry][ring]amix=inputs=2:weights=0.45 1:duration=first:normalize=0,
 acrusher=bits=9:mix=0.35:mode=log:aa=1,
 aecho=0.8:0.5:11|17:0.35|0.22,
 highpass=f=220,lowpass=f=3800,
 dynaudnorm=f=150:g=15:p=0.89,alimiter=limit=0.89:level=disabled,
 apad=pad_dur=0.05
" -ac 1 -ar 44100 -c:a libmp3lame -b:a 128k "$out"
