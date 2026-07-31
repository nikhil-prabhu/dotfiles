#!/usr/bin/env bash

# Runs basic stream setup commands for a Sunshine streaming server.
#
# The script currently does a few things:
#   1. Turns on/off DND mode (based on passed argument).
#   2. Disables all displays except the primary to prevent content "bleed" from other displays.
#   3. Adjusts the display resolution to match the client's requested resolution.
#
# NOTE: All operations rely on commands that are specific to KDE Plasma, and will most probably
# not work on other environments.
#
# Usage: kde-stream-manager.sh <on|off>

ACTION="$1"
DND_STATE_FILE="/tmp/sunshine-dnd-active.state"
MODE_STATE_FILE="/tmp/sunshine-mode.state"

toggle_dnd() {
    local target="$1"
    local currently_tracked=false

    if [ -f "$DND_STATE_FILE" ]; then
        currently_tracked=true
    fi

    if [ "$target" = "on" ] && [ "$currently_tracked" = "false" ]; then
        qdbus6 org.kde.kglobalaccel /component/plasmashell invokeShortcut "toggle do not disturb"
        touch "$DND_STATE_FILE"
    elif [ "$target" = "off" ] && [ "$currently_tracked" = "true" ]; then
        qdbus6 org.kde.kglobalaccel /component/plasmashell invokeShortcut "toggle do not disturb"
        rm -f "$DND_STATE_FILE"
    fi
}

manage_displays() {
    local action="$1"

    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required for JSON parsing."
        return 1
    fi

    local json_data
    json_data=$(kscreen-doctor --json 2>/dev/null)

    if [ -z "$json_data" ]; then
        echo "Error: Could not retrieve JSON display layout from kscreen-doctor."
        return 1
    fi

    # 1. Identify Primary Monitor
    local primary_output
    primary_output=$(echo "$json_data" | jq -r '.outputs[] | select(.priority == 1) | .name')

    if [ -z "$primary_output" ] || [ "$primary_output" = "null" ]; then
        echo "Error: Could not determine primary display from JSON."
        return 1
    fi

    # 2. Dynamic Resolution Matching
    if [ "$action" = "disable" ]; then
        # Save the current display mode ID before changing anything
        local current_mode
        current_mode=$(echo "$json_data" | jq -r --arg out "$primary_output" '.outputs[] | select(.name == $out) | .currentModeId')
        echo "$current_mode" > "$MODE_STATE_FILE"

        # If Sunshine passed client dimensions, find the matching mode ID
        if [ -n "$SUNSHINE_CLIENT_WIDTH" ] && [ -n "$SUNSHINE_CLIENT_HEIGHT" ]; then
            local mode_id
            mode_id=$(echo "$json_data" | jq -r --argjson w "$SUNSHINE_CLIENT_WIDTH" --argjson h "$SUNSHINE_CLIENT_HEIGHT" --arg out "$primary_output" '
                .outputs[] | select(.name == $out) | .modes[] | select(.size.width == $w and .size.height == $h) | .id
            ' 2>/dev/null | head -n 1)

            if [ -n "$mode_id" ] && [ "$mode_id" != "null" ]; then
                echo "Switching primary display to ${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}..."
                kscreen-doctor "output.$primary_output.mode.$mode_id"
            fi
        fi

    elif [ "$action" = "enable" ]; then
        # Restore the primary display to its original mode
        if [ -f "$MODE_STATE_FILE" ]; then
            local restore_mode
            restore_mode=$(cat "$MODE_STATE_FILE")
            echo "Restoring primary display resolution..."
            kscreen-doctor "output.$primary_output.mode.$restore_mode"
            rm -f "$MODE_STATE_FILE"
        fi
    fi

    # 3. Handle Secondary Displays
    local all_outputs
    all_outputs=$(echo "$json_data" | jq -r '.outputs[].name')

    for out in $all_outputs; do
        if [ "$out" = "$primary_output" ]; then
            continue
        fi

        if [ "$action" = "disable" ]; then
            echo "Disabling secondary display: $out"
            kscreen-doctor "output.$out.disable"
        elif [ "$action" = "enable" ]; then
            echo "Enabling secondary display: $out"
            kscreen-doctor "output.$out.enable"
        fi
    done
}

if [ "$ACTION" = "on" ]; then
    echo "Starting stream hooks..."
    toggle_dnd on
    manage_displays disable

elif [ "$ACTION" = "off" ]; then
    echo "Stopping stream hooks..."
    manage_displays enable
    toggle_dnd off
fi

