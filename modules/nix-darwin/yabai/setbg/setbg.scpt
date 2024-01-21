# Get argv
on run argv
    # Calculate argc
    set argc to count of argv

    # Debug mode
    set debug to true

    tell application "System Events"
        tell appearance preferences
            # Prepare wallpaper path
            if argc < 1
                log "No argument given, wanted a filepath as the first argument"
                return
            end if
            set filePath to item 1 of argv

            if debug then log "Set filePath to " & filePath

            # Save current focussed spaces and window (to restore afterwards)
            set visibleSpaceIndices to do shell script "yabai -m query --spaces | jq '.[] | select(.[\"is-visible\"] == true) | .index'"
            if debug then log "Set visibleSpaceIndices to " & visibleSpaceIndices
            set focussedWindowId to do shell script "yabai -m query --windows | jq '.[] | select(.[\"has-focus\"] == true) | .id'"
            if debug then log "Set focussedWindowId to " & focussedWindowId

            # Tell the OS ...
            tell application "System Events"
                set displayCount to count of desktops
                if debug then log "Set displayCount to " & displayCount

                # ... for each display (desktop in Apple's terms) ...
                repeat with displayIndex from 1 to displayCount
                    if debug then log "Set displayIndex to " & displayIndex

                    set spaceIds to do shell script "yabai -m query --spaces | jq '.[] | select(.display == " & displayIndex & ") | .index'"
                    if debug then log "Set spaceIds to " & spaceIds

                    tell desktop displayIndex
                        # ... iterating through all of its spaces' ids ...
                        repeat with spaceId in paragraphs of spaceIds
                            # ... focus each space ...
                            do shell script "yabai -m space --focus " & spaceId
                            if debug then log "Focus to space " & spaceId

                            # ... and set its wallpaper to the selected one
                            set picture to filePath
                            if debug then log "Set picture to " & picture
                        end repeat
                    end tell
                end repeat
            end tell

            # Focus back the visible space(s)
            repeat with visibleSpaceId in paragraphs of visibleSpaceIndices
                do shell script "yabai -m space --focus " & visibleSpaceId
                if debug then log "Focus to visible space " & visibleSpaceId
            end repeat

            # Focus back the original focussed window
            do shell script "yabai -m window --focus " & focussedWindowId
            if debug then log "Focus to window " & focussedWindowId
        end tell
    end tell
end run
