#!/system/bin/sh
# Inactive Slot Updater
# Copyright (C) 2022, VR25 @ xda-developers
# License: GPLv3+
# Last update: Wed, Jan 19, 2022

set -eu
echo
activeSuffix=$(getprop ro.boot.slot_suffix)
skipPart=" system_a system_b "

[ $activeSuffix = _a ] && inactiveSuffix=_b || inactiveSuffix=_a

printf "Updating inactive slot..."
for active in /dev/block/bootdevice/by-name/*$activeSuffix; do
  [ -e $active ] || continue
  echo "$skipPart" | grep -q " ${active##*/} " || {
    inactive=$(echo $active | sed s/$activeSuffix/$inactiveSuffix/)
    [ -e $inactive ] || continue
    activePart=$(readlink -fn $active)
    inactivePart=$(readlink -fn $inactive)
    [ $activePart != $inactivePart ] || continue
    printf "\n  ${active##*/} (${activePart##*/}) >>> ${inactive##*/} (${inactivePart##*/})"
    blockdev --setrw $inactivePart
    cat $activePart > $inactivePart
  }
done
printf "\nDone.\n\n"
