let
  plugin_dir = ./plugins;
in
''
PLUGIN_DIR="${plugin_dir}"

##### Bar Appearance #####
BACKGROUND_COLOR="0x502a2d3d"

appearance=''$''\(defaults read -g AppleInterfaceStyle''\)

if [[ ''$''\{appearance''\} != 'Dark' ]]; then
    BACKGROUND_COLOR="0x50f5f0f5"
fi

sketchybar --bar height="32"               \
                 blur_radius="25"          \
                 position="top"            \
                 sticky="on"               \
                 margin="10"               \
                 color="0x002a2d3d"        \
                 notch_offset="5"          \
                 corner_radius="12"        \
                 border_color="0x80c4a7e7" \
                 border_width="0"

##### Changing Defaults #####
# We now change some default values that are applied to all further items
# For a full list of all available item properties see:
# https://felixkratz.github.io/SketchyBar/config/items

sketchybar --default updates="when_shown"                  \
                     icon.font="SF Pro Rounded:Bold:14.0"  \
                     icon.color="0xffc6ceef"               \
                     label.font="SF Pro Rounded:Bold:14.0" \
                     label.color="0xffc6ceef"              \
                     padding_left="3"                      \
                     padding_right="3"                     \
                     label.padding_left="4"                \
                     label.padding_right="4"               \
                     icon.padding_left="4"                 \
                     icon.padding_right="4"

##### Adding Mission Control Space Indicators #####
# Now we add some mission control spaces:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item
# to indicate active and available mission control spaces

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16")

for i in "''$''\{!SPACE_ICONS[@]''\}"; do
  sid=$(($i+1))
  sketchybar --add space space.''$''\{sid''\} left                                   \
             --set space.''$''\{sid''\} associated_space="''$''\{sid''\}"                    \
                                icon="''$''\{SPACE_ICONS[i]''\}"                     \
                                background.color="0x44ffffff"                \
                                background.corner_radius="7"                 \
                                background.height="20"                       \
                                background.drawing="on"                      \
                                background.border_color="0x952a2d3d"         \
                                background.border_width="1"                  \
                                label.drawing="off"                          \
                                script="''$''\{PLUGIN_DIR''\}/space.sh"              \
                                click_script="yabai -m space --focus ''$''\{sid''\}"
done

##### Adding Left Items #####
# We add some regular items to the left side of the bar
# only the properties deviating from the current defaults need to be set

sketchybar --add item space_separator left                              \
           --set space_separator icon="λ"                               \
                                 icon.color="0xffff946f"                \
                                 padding_left="10"                      \
                                 padding_right="10"                     \
                                 label.drawing="off"                    \
                                                                        \
           --add item front_app left                                    \
           --set front_app       script="''$''\{PLUGIN_DIR''\}/front_app.sh"    \
                                 icon.drawing="off"                     \
                                 background.color="''$''\{BACKGROUND_COLOR''\}" \
                                 background.corner_radius="7"           \
                                 blur_radius="30"                       \
                                 background.border_color="0x80c4a7e7"   \
                                 background.border_width="1"            \
           --subscribe front_app front_app_switched

##### Adding Right Items #####
# In the same way as the left items we can add items to the right side.
# Additional position (e.g. center) are available, see:
# https://felixkratz.github.io/SketchyBar/config/items#adding-items-to-sketchybar

# Some items refresh on a fixed cycle, e.g. the clock runs its script once
# every 10s. Other items respond to events they subscribe to, e.g. the
# volume.sh script is only executed once an actual change in system audio
# volume is registered. More info about the event system can be found here:
# https://felixkratz.github.io/SketchyBar/config/events

sketchybar --add item test right                                         \
           --set test    script="''$''\{PLUGIN_DIR''\}/theme.sh"                 \
                         icon="􀝦"                                        \
                         background.height="30"                          \
                         background.color="''$''\{BACKGROUND_COLOR''\}"          \
                         background.corner_radius="7"                    \
                         icon.padding_left="10"                          \
                         icon.padding_right="13"                         \
                         blur_radius="30"                                \
                         background.border_color="0x80c4a7e7"            \
                         background.border_width="1"                     \
                         label.drawing="off"                             \
                         click_script="~/.dotfiles/macos/wallpapers.zsh" \
            --add item clock right   i                                   \
            --set clock  update_freq="10"                                \
                         icon="􀐬"                                        \
                         background.color="''$''\{BACKGROUND_COLOR''\}"          \
                         background.corner_radius="7"                    \
                         icon.padding_left="10"                          \
                         label.padding_right="10"                        \
                         blur_radius="30"                                \
                         background.border_color="0x80c4a7e7"            \
                         background.border_width="1"                     \
                         script="''$''\{PLUGIN_DIR''\}/clock.sh"                 \
                                                                         \
           --add item wifi right                                         \
           --set wifi    script="''$''\{PLUGIN_DIR''\}/wifi.sh"                  \
                         icon="􀙇"                                        \
                         background.color="''$''\{BACKGROUND_COLOR''\}"          \
                         background.corner_radius="7"                    \
                         icon.padding_left="10"                          \
                         label.padding_right="10"                        \
                         blur_radius="30"                                \
                         background.border_color="0x80c4a7e7"            \
                         background.border_width="1"                     \
           --subscribe wifi wifi_change                                  \
                                                                         \
           --add item volume right                                       \
           --set volume  script="''$''\{PLUGIN_DIR''\}/volume.sh"                \
                         background.color="''$''\{BACKGROUND_COLOR''\}"          \
                         background.corner_radius="7"                    \
                         icon.padding_left="10"                          \
                         label.padding_right="10"                        \
                         blur_radius="30"                                \
                         background.border_color="0x80c4a7e7"            \
                         background.border_width="1"                     \
           --subscribe volume volume_change                              \
                                                                         \
           --add item battery right                                      \
           --set battery script="''$''\{PLUGIN_DIR''\}/battery.sh"               \
                         update_freq="120"                               \
                         background.color="''$''\{BACKGROUND_COLOR''\}"          \
                         background.corner_radius="7"                    \
                         icon.padding_left="10"                          \
                         label.padding_right="10"                        \
                         blur_radius="30"                                \
                         background.border_color="0x80c4a7e7"            \
                         background.border_width="1"                     \
           --subscribe battery system_woke power_source_change           \

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
''
