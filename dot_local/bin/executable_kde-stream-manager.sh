#!/usr/bin/env bash

# Runs basic stream setup commands for a Sunshine streaming server.
#
# The script currently does 2 things:
#   1. Turns on/off DND mode (based on passed argument).
#   2. Disables all displays except the primary to prevent content "bleed" from other displays.
#
# NOTE: Both operations rely on commands that are specific to KDE Plasma, and will most probably
# not work on other environments.
#
# Usage: stream-manager.sh <on|off>

ACTION="$1"
STATE_FILE="/tmp/sunshine-dnd-active.state"

toggle_dnd() {
    local target="$1" # "on" or "off"
    local currently_tracked=false

    if [ -f "$STATE_FILE" ]; then
        currently_tracked=true
    fi

    if [ "$target" = "on" ] && [ "$currently_tracked" = "false" ]; then
        # Force DND on via Plasma shortcut toggle and record that we activated it
        qdbus6 org.kde.kglobalaccel /component/plasmashell invokeShortcut "toggle do not disturb"
        touch "$STATE_FILE"
    elif [ "$target" = "off" ] && [ "$currently_tracked" = "true" ]; then
        # Revert DND and clear our tracking state
        qdbus6 org.kde.kglobalaccel /component/plasmashell invokeShortcut "toggle do not disturb"
        rm -f "$STATE_FILE"
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

    # Query the output name where priority is 1 (primary display)
    local primary_output
    primary_output=$(echo "$json_data" | jq -r '.outputs[] | select(.priority == 1) | .name')

    if [ -z "$primary_output" ] || [ "$primary_output" = "null" ]; then
        echo "Error: Could not determine primary display from JSON."
        return 1
    fi

    # Extract all connected output names to loop through them
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
