#!/bin/bash
set -euo pipefail

cloud="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
shared="$cloud/FactorioPad Saves"
saves="$HOME/Library/Application Support/factorio/saves"
backup="$HOME/Library/Application Support/factorio/saves.before-factoriopad"

if [ ! -d "$cloud" ]; then
    echo "Enable iCloud Drive on this Mac before you link Factorio saves." >&2
    exit 1
fi
if pgrep -x factorio >/dev/null || pgrep -x Factorio >/dev/null; then
    echo "Quit Factorio before you link its saves." >&2
    exit 1
fi
if [ -L "$saves" ]; then
    if [ "$(readlink "$saves")" = "$shared" ]; then
        echo "Factorio saves are already linked to $shared"
        exit 0
    fi
    echo "Factorio saves already point to another folder. Nothing changed." >&2
    exit 1
fi
if [ -e "$shared" ] && [ -n "$(ls -A "$shared")" ]; then
    echo "The iCloud folder already contains files. Nothing changed. Move them aside or merge them first." >&2
    exit 1
fi
if [ -e "$backup" ]; then
    echo "The backup path already exists: $backup. Nothing changed." >&2
    exit 1
fi
if [ -e "$saves" ] && [ ! -d "$saves" ]; then
    echo "Factorio saves is not a folder. Nothing changed." >&2
    exit 1
fi

mkdir -p "$shared" "$(dirname "$saves")"
if [ -d "$saves" ]; then
    ditto "$saves" "$shared"
    mv "$saves" "$backup"
    trap 'if [ ! -e "$saves" ] && [ -d "$backup" ]; then mv "$backup" "$saves"; fi' EXIT
fi
ln -s "$shared" "$saves"
trap - EXIT
echo "Factorio saves now use $shared"
if [ -d "$backup" ]; then echo "The original saves remain in $backup"; fi
