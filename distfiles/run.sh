#!/bin/bash

#Export local shared libs

cd "$(dirname "$0")"
echo "DIR IN "$PWD
export LD_LIBRARY_PATH=./lib


#Create desktop entry if not found

DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_ENTRY="$DESKTOP_DIR/Orion.desktop"

if [ ! -f "$DESKTOP_ENTRY" ]; then

    mkdir -p "$DESKTOP_DIR"
    echo "Creating new desktop entry"

    {
        echo -e "[Desktop Entry]\nVersion=1.0\nType=Application\nName=Orion"
        echo "Icon=$PWD/orion.svg"
        echo "Exec=$PWD/run.sh"
        echo -e "Comment=A Twitch.tv desktop client\nCategories=AudioVideo;Video;Player;TV;Qt;\nTerminal=false\nStartupWMClass=orion"
    } > "$DESKTOP_ENTRY"
fi


#Run app

./orion
