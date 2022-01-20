#!/system/bin/sh
# Fstab Patcher
# Copyright (C) 2022, VR25 @ xda-developers
# License: GPLv3+
# Last update: Thu, Jan 20, 2022

check() {
  grep -Eq "${2:-$header}" ${1:-$fstab}
}

exxit() {
  local e=$?
  set +eu
  mount -o remount,ro $vendorMnt
  blockdev --setro $vendor
  echo
  exit $e
} 2>/dev/null

failed() {
  echo "(!) Failed to [re]mount $vendorMnt rw!"
  exit 1
}

repeat() {
  echo "(i) Reboot and run me again to verify/repatch."
  touch $lockFile
  exit
}

echo
set -eu
trap exxit EXIT
[ -z "$LINENO" ] || PS4='$LINENO: '

header="# Tweaked by VR25 @ xda-developers"
vendorMnt=$(awk '/\/mirror\/vendor /{print $2}' /proc/mounts 2>/dev/null || :)
[ -n "$vendorMnt" ] || vendorMnt=/vendor
fstab="$vendorMnt/etc/fstab.*"
lockFile="/dev/.${0##*/}"
i=$(getprop ro.boot.slot_suffix)
vendor=/dev/block/by-name/vendor$i

[ -f $lockFile ] && repeat || {
  printf "(i) WARNING: you must FORMAT userdata after disabling encryption, or your system won't boot!

Backup vendor$i (optional):
  # cat $(readlink -fn $vendor) | gzip -1 > /sdcard/vendor$i.img.gz
  $ adb pull /sdcard/vendor$i.img.gz

Verify/patch fstab(s) now? (y/N) "
  i=
  read -n 1 i
  printf '\n\n'
  [ ".$i" = .y ] || exit 0
  blockdev --setrw $vendor || :
  mount -o remount,rw $vendorMnt 2>/dev/null \
    || mount -t auto -o rw $vendor $vendorMnt \
    || failed
  ! check || {
    echo "(i) fstab(s) already patched."
    exit
  }
}

for i in $fstab; do
  if [ -f $i ] && check $i "^/dev/block/.*/userdata /data "; then
    sed -Ei \
      -e "1i$header\n" \
      -e '/^\/.* voldmanaged=/s/ (tex|ex|v)fat / auto /' \
      -e '/^\/.* voldmanaged=/s/ (defaults) / \1,noatime /' \
      -e '/^\/.* voldmanaged=/s/,encryptable=userdat(a,|a$)/,/' \
      -e '/^\/.*\/userdata \/data /s/,(force(encrypt|fdeorfbe)|fileencryption)[^,]*//' \
      -e '/^\/.*\/userdata \/data /s/,quot(a,|a$)/,/' \
      -e '/^\/.*\/userdata \/data ext4 /s/,commit=[0-9]+//' \
      -e '/^\/.*/s/,$//' \
      -e '/^\/.*\/userdata \/data ext4 /s/$/,commit=60/' \
      -e '/^\/.*\/userdata \/data /s/,,+/,/g' $i
  fi
done

repeat
