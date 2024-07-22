#!/bin/bash

if [ "$1" == "" -o ! -d "$1" ]; then
  echo "Install script creates symlinks to the _8control.sh file with the individual commands,"
  echo "then symlinks them all to the <parameter1> directory."
  echo ""
  echo "Example: install.sh /usr/bin/"
  exit 0
fi

LOCDIR="`dirname "$0"`"
if [ "$LOCDIR" == "." ]; then LOCDIR="`pwd`"; fi
#echo "local dir: $LOCDIR (`dirname $0`) ($0)"
#exit 0

#echo "Creating command symlinks"
echo "Installing command symlinks"
grep '^  8.*' "$LOCDIR/_8control.sh" |cut -d ')' -f 1|tr '|' '\n'|tr -d ' ' \
  | while read x; do
      if [ -f "$1/$x" ]; then rm -v "$1/$x"; fi
      ln -vs "$LOCDIR/_8control.sh" "$1/$x"
    done
#ln -s `pwd`/8* "$1"
