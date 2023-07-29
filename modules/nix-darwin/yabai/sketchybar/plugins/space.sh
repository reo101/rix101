#!/bin/sh

# The ${SELECTED} variable is available for space components and indicates if
# the space invoking this script (with name: ${NAME}) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

BACKGROUND_COLOR=0x502a2d3d
HIGHLIGHT_COLOR=0x90faafa6

appearance=$(defaults read -g AppleInterfaceStyle)

if [[ ${appearance} != 'Dark' ]]; then
    BACKGROUND_COLOR=0x50f5f0f5
fi



if [ "${SELECTED}" == "true" ]; then
    sketchybar --set ${NAME} background.color=${HIGHLIGHT_COLOR}
else
    sketchybar --set ${NAME} background.color=${BACKGROUND_COLOR} \
                             blur_radius=30
fi
