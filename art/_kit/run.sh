#!/bin/zsh
# Builds Year 2029 models one at a time without cooking the laptop: waits for a cool, quiet machine
# and the shared lock, then runs Blender alone, low priority, 2 threads. One Blender per item.
# Usage: _kit/run.sh <build file> [quick] name name ...   (no names = every item in the file)
cd "$(dirname "$0")/.." || exit 1
LOCK=_kit/.blender.lock
hot() {
  pmset -g batt | grep -q "Battery Power" && [ "$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d %)" -lt 30 ] && return 0
  pmset -g therm | grep -q "CPU_Speed_Limit" && [ "$(pmset -g therm | awk -F= '/CPU_Speed_Limit/{print int($2)}')" -lt 100 ] && return 0
  pgrep -f "Blender.app/Contents/MacOS/Blender.*-b |blender -b" >/dev/null && return 0
  [ "$(sysctl -n vm.loadavg | awk '{print int($2*10)}')" -ge 60 ]
}
got=0
trap '[ $got = 1 ] && rmdir $LOCK 2>/dev/null' EXIT INT TERM
f=$1; shift
q=""; [ "$1" = quick ] && { q=quick; shift; }
names=("$@")
if [ ${#names} -eq 0 ]; then
  names=($(grep -Eo '^@item\("[a-z0-9_]+"' "$f" | sed 's/@item("//;s/"//'))
  [ ${#names} -eq 0 ] && names=("")
fi
for n in "${names[@]}"; do
  # a lock left by a crashed run is cleared after 20 minutes
  [ -d $LOCK ] && [ -n "$(find $LOCK -maxdepth 0 -mmin +20)" ] && rmdir $LOCK 2>/dev/null
  for i in {1..240}; do
    if ! hot && mkdir $LOCK 2>/dev/null; then got=1; break; fi
    sleep $((20 + RANDOM % 20))
  done
  if [ $got != 1 ]; then echo "STILL HOT OR BUSY, stopped before $n"; exit 1; fi
  nice -n 15 /opt/homebrew/bin/blender -b -t 2 --factory-startup -P "$f" -- $n $q 2>&1 | grep "TRIM\|BUILT\|TOO MANY\|Error\|Traceback\|line [0-9]\|MISS\|CHECK"
  rmdir $LOCK 2>/dev/null; got=0
done
