#!/usr/bin/env bash

# Runs basic stream setup commands for a Sunshine streaming server.
#
# The script currently does a few things:
#   1. Turns on/off DND mode (based on passed argument).
#   2. Disables all displays except the primary to prevent content "bleed" from other displays.
#   3. Adjusts the display resolution to match the client's requested resolution.
#   4. Reduces the brightness of the primary display to 0 to reduce power draw.
#
# NOTE: All operations rely on commands that are specific to KDE Plasma, and will
# not work on other environments.
#
# Usage: kde-stream-manager.sh <on|off>

ACTION="$1"
DND_STATE_FILE="/tmp/sunshine-dnd-active.state"
MODE_STATE_FILE="/tmp/sunshine-mode.state"
INHIBIT_STATE_FILE="/tmp/sunshine-inhibit.cookie"
DDC_STATE_FILE="/tmp/sunshine-ddc.state"
KDE_BRIGHTNESS_FILE="/tmp/sunshine-kde-brightness.state"

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

toggle_power_management() {
    local target="$1"

    if [ "$target" = "on" ]; then
        local cookie
        cookie=$(qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Inhibit "Sunshine" "Streaming")
        if [ -n "$cookie" ]; then
            echo "$cookie" > "$INHIBIT_STATE_FILE"
        fi
    elif [ "$target" = "off" ]; then
        if [ -f "$INHIBIT_STATE_FILE" ]; then
            local cookie
            cookie=$(cat "$INHIBIT_STATE_FILE")
            qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.UnInhibit "$cookie"
            rm -f "$INHIBIT_STATE_FILE"
        fi
    fi
}

manage_displays() {
    local action="$1"

    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required."
        return 1
    fi

    local json_data
    json_data=$(kscreen-doctor --json 2>/dev/null)

    if [ -z "$json_data" ]; then
        echo "Error: Could not retrieve JSON display layout."
        return 1
    fi

    local primary_output
    primary_output=$(echo "$json_data" | jq -r '.outputs[] | select(.priority == 1) | .name')

    if [ -z "$primary_output" ] || [ "$primary_output" = "null" ]; then
        echo "Error: Could not determine primary display."
        return 1
    fi

    local ddc_allowed
    ddc_allowed=$(echo "$json_data" | jq -r --arg out "$primary_output" '.outputs[] | select(.name == $out) | .ddcCiAllowed')

    local all_outputs
    all_outputs=$(echo "$json_data" | jq -r '.outputs[].name')

    if [ "$action" = "disable" ]; then

        # 1. Save DDC Hardware Brightness FIRST (before the bus gets busy)
        if [ "$ddc_allowed" = "true" ] && command -v ddcutil &> /dev/null; then
            local curr_b curr_c
            curr_b=$(ddcutil getvcp 10 --terse 2>/dev/null | awk '{print $4}')
            curr_c=$(ddcutil getvcp 12 --terse 2>/dev/null | awk '{print $4}')

            # Validate output is a number, otherwise default to 100 / 75
            if ! [[ "$curr_b" =~ ^[0-9]+$ ]]; then curr_b=100; fi
            if ! [[ "$curr_c" =~ ^[0-9]+$ ]]; then curr_c=75; fi

            echo "$curr_b $curr_c" > "$DDC_STATE_FILE"
        fi

        # 2. Disable Secondary Displays
        for out in $all_outputs; do
            if [ "$out" != "$primary_output" ]; then
                echo "Disabling secondary display: $out"
                kscreen-doctor "output.$out.disable"
            fi
        done
        sleep 2 # Let Wayland stabilize

        # 3. Resolution Matching
        local current_mode
        current_mode=$(echo "$json_data" | jq -r --arg out "$primary_output" '.outputs[] | select(.name == $out) | .currentModeId')
        echo "$current_mode" > "$MODE_STATE_FILE"

        if [ -n "$SUNSHINE_CLIENT_WIDTH" ] && [ -n "$SUNSHINE_CLIENT_HEIGHT" ]; then
            local mode_id
            mode_id=$(echo "$json_data" | jq -r --argjson w "$SUNSHINE_CLIENT_WIDTH" --argjson h "$SUNSHINE_CLIENT_HEIGHT" --arg out "$primary_output" '
                .outputs[] | select(.name == $out) | .modes[] | select(.size.width == $w and .size.height == $h) | .id
            ' 2>/dev/null | head -n 1)

            if [ -n "$mode_id" ] && [ "$mode_id" != "null" ]; then
                echo "Switching primary display to ${SUNSHINE_CLIENT_WIDTH}x${SUNSHINE_CLIENT_HEIGHT}..."
                kscreen-doctor "output.$primary_output.mode.$mode_id"
                sleep 2 # Let Wayland stabilize resolution change
            fi
        fi

        # 4. Hardware Blackout (DDC)
        if [ "$ddc_allowed" = "true" ] && command -v ddcutil &> /dev/null; then
            echo "Dropping hardware brightness and contrast..."
            ddcutil setvcp 10 0
            ddcutil setvcp 12 0
        fi

        # 5. Software Blackout (KDE)
        local kde_b
        kde_b=$(qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightness 2>/dev/null)
        if [ -n "$kde_b" ]; then
            echo "$kde_b" > "$KDE_BRIGHTNESS_FILE"
            qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness 0
        fi


    elif [ "$action" = "enable" ]; then

        # 1. Restore Hardware Display Values (DDC) FIRST!
        # Do this while the bus is completely quiet, before messing with layout.
        if [ "$ddc_allowed" = "true" ] && command -v ddcutil &> /dev/null; then
            if [ -f "$DDC_STATE_FILE" ]; then
                read -r saved_b saved_c < "$DDC_STATE_FILE"

                # Failsafe validation
                if ! [[ "$saved_b" =~ ^[0-9]+$ ]]; then saved_b=100; fi
                if ! [[ "$saved_c" =~ ^[0-9]+$ ]]; then saved_c=75; fi

                echo "Restoring brightness ($saved_b) and contrast ($saved_c)..."
                ddcutil setvcp 10 "$saved_b"
                ddcutil setvcp 12 "$saved_c"
                rm -f "$DDC_STATE_FILE"
            else
                ddcutil setvcp 10 100
                ddcutil setvcp 12 75
            fi
            sleep 1
        fi

        # 2. Restore Resolution
        if [ -f "$MODE_STATE_FILE" ]; then
            local restore_mode
            restore_mode=$(cat "$MODE_STATE_FILE")
            echo "Restoring primary display resolution..."
            kscreen-doctor "output.$primary_output.mode.$restore_mode"
            rm -f "$MODE_STATE_FILE"

            sleep 2 # Crucial: Let 4K mode apply fully
        fi

        # 3. Enable Secondary Displays
        for out in $all_outputs; do
            if [ "$out" != "$primary_output" ]; then
                echo "Enabling secondary display: $out"
                kscreen-doctor "output.$out.enable"
            fi
        done

        sleep 3 # Crucial: Wait for KWin to finish geometry layout

        # 4. Restore Software Brightness (KDE) LAST
        if [ -f "$KDE_BRIGHTNESS_FILE" ]; then
            local saved_kde_b
            saved_kde_b=$(cat "$KDE_BRIGHTNESS_FILE")
            qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness "$saved_kde_b"
            rm -f "$KDE_BRIGHTNESS_FILE"
        fi
    fi
}

if [ "$ACTION" = "on" ]; then
    echo "Starting stream hooks..."
    toggle_power_management on
    toggle_dnd on
    manage_displays disable

elif [ "$ACTION" = "off" ]; then
    echo "Stopping stream hooks..."
    manage_displays enable
    toggle_dnd off
    toggle_power_management off
fi
