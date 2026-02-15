#!/bin/sh

CONFIG_DIR="$HOME/lunaroconf"
CONFIG_FILE="$CONFIG_DIR/config"
FAV_FILE="$CONFIG_DIR/favorites"
APPIMAGE_DIR="$HOME/pwogams"
LOG_DIR="$HOME/lunarologs"
DEFAULT_GPU="dgpu"

# Create necessary directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$APPIMAGE_DIR"
mkdir -p "$LOG_DIR"

# Create default config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'EOF'
# Lunaro Configuration File
# Edit these values to customize your setup

# Directory where AppImages are stored
APPIMAGE_DIR=$HOME/pwogams

# Directory where logs are saved
LOG_DIR=$HOME/lunarologs

# Default GPU to use (dgpu or igpu)
DEFAULT_GPU=dgpu
EOF
    echo "Created default config at: $CONFIG_FILE"
fi

# Create favorites file if it doesn't exist
if [ ! -f "$FAV_FILE" ]; then
    touch "$FAV_FILE"
fi

# Read config file and override defaults
if [ -f "$CONFIG_FILE" ]; then
    # Source the config file
    . "$CONFIG_FILE"
fi

# Expand variables in case config uses $HOME
APPIMAGE_DIR=$(eval echo "$APPIMAGE_DIR")
LOG_DIR=$(eval echo "$LOG_DIR")

# Ensure directories exist (in case config changed them)
mkdir -p "$APPIMAGE_DIR"
mkdir -p "$LOG_DIR"

show_help() {
    cat << 'EOF'
Lunaro - AppImage Launcher

USAGE:
  <appname> [flags]

COMMANDS:
  list      - Show all AppImages in the app directory
  fav <app> - Add an app to favorites (shows at top of list)
  unfav <app> - Remove an app from favorites
  help      - Show this help message
  exit/quit - Exit Lunaro

FLAGS:
  -igpu     - Launch with integrated GPU
  -dgpu     - Launch with dedicated GPU (default)
  -l        - Enable logging
  -r        - Launch with root permissions (adds --no-sandbox if needed)
  -lr/-rl   - Enable both logging and root

EXAMPLES:
  LunarMC
  LunarMC -igpu
  LunarMC -r -l
  Discord -igpu -rl
  fav LunarMC
  unfav Discord

CONFIGURATION:
  Config file: ~/lunaroconf/config
  App directory: $APPIMAGE_DIR
  Log directory: $LOG_DIR
  Default GPU: $DEFAULT_GPU
EOF
}

list_apps() {
    printf "Available AppImages in %s:\n" "$APPIMAGE_DIR"
    if [ -d "$APPIMAGE_DIR" ]; then
        found=0

        # Show favorites first
        if [ -s "$FAV_FILE" ]; then
            printf "\n⭐ FAVORITES:\n"
            while IFS= read -r fav; do
                # Check if the favorite actually exists
                for app in "$APPIMAGE_DIR"/*.AppImage; do
                    if [ -f "$app" ]; then
                        appname=$(basename "$app" .AppImage)
                        if [ "$appname" = "$fav" ]; then
                            printf "  %s\n" "$appname"
                            found=1
                        fi
                    fi
                done
            done < "$FAV_FILE"
        fi

        # Show all other apps
        printf "\n📦 ALL APPS:\n"
        for app in "$APPIMAGE_DIR"/*.AppImage; do
            if [ -f "$app" ]; then
                appname=$(basename "$app" .AppImage)
                # Check if it's a favorite
                is_fav=0
                if [ -f "$FAV_FILE" ]; then
                    while IFS= read -r fav; do
                        if [ "$appname" = "$fav" ]; then
                            is_fav=1
                            break
                        fi
                    done < "$FAV_FILE"
                fi

                # Only show if not already shown in favorites
                if [ "$is_fav" -eq 0 ]; then
                    printf "  %s\n" "$appname"
                fi
                found=1
            fi
        done

        if [ "$found" -eq 0 ]; then
            printf "  (none found)\n"
        fi
    else
        printf "  Directory does not exist\n"
    fi
}

add_favorite() {
    app_name="$1"
    if [ -z "$app_name" ]; then
        printf "Error: Please specify an app name\n"
        printf "Usage: fav <appname>\n"
        return
    fi

    # Check if app exists
    match=$(find "$APPIMAGE_DIR" -maxdepth 1 -type f -iname "$app_name.AppImage" 2>/dev/null | head -n 1)
    if [ -z "$match" ]; then
        printf "Error: App not found: %s\n" "$app_name"
        return
    fi

    # Get the actual case-sensitive name
    actual_name=$(basename "$match" .AppImage)

    # Check if already favorited
    if grep -Fxq "$actual_name" "$FAV_FILE" 2>/dev/null; then
        printf "'%s' is already in favorites\n" "$actual_name"
        return
    fi

    # Add to favorites
    echo "$actual_name" >> "$FAV_FILE"
    printf "Added '%s' to favorites ⭐\n" "$actual_name"
}

remove_favorite() {
    app_name="$1"
    if [ -z "$app_name" ]; then
        printf "Error: Please specify an app name\n"
        printf "Usage: unfav <appname>\n"
        return
    fi

    # Check if in favorites
    if ! grep -Fxq "$app_name" "$FAV_FILE" 2>/dev/null; then
        printf "'%s' is not in favorites\n" "$app_name"
        return
    fi

    # Remove from favorites
    grep -Fxv "$app_name" "$FAV_FILE" > "$FAV_FILE.tmp" 2>/dev/null
    mv "$FAV_FILE.tmp" "$FAV_FILE"
    printf "Removed '%s' from favorites\n" "$app_name"
}

easter_egg() {
    cat << 'EOF'
    🥚
   🥚
EOF
}

echo "Lunaro started."
echo "App directory: $APPIMAGE_DIR"
echo "Log directory: $LOG_DIR"
echo "Default GPU: $DEFAULT_GPU"
echo "Type 'help' for commands or 'exit' to quit."

while true
do
    printf "lunaro> "

    if ! IFS= read -r line; then
        break
    fi

    case "$line" in
        "") continue ;;
        exit|quit) break ;;
        help) show_help; continue ;;
        list) list_apps; continue ;;
        fav\ *) add_favorite "$(echo "$line" | sed 's/^fav //')"; continue ;;
        unfav\ *) remove_favorite "$(echo "$line" | sed 's/^unfav //')"; continue ;;
        eggegg) easter_egg; continue ;;
    esac

    use_log=0
    use_root=0
    use_igpu=0

    # Extract app name (first word) and flags (everything after)
    app_input=$(printf '%s\n' "$line" | awk '{print $1}')
    flags=$(printf '%s\n' "$line" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')

    # Check for GPU flags in the flags portion only
    case " $flags " in
        *" -igpu "*)
            use_igpu=1
            ;;
        *" -dgpu "*)
            use_igpu=0
            ;;
    esac

    # If no GPU flag specified, use default from config
    if [ -z "$flags" ] || { [ "$use_igpu" -eq 0 ] && ! printf '%s' " $flags " | grep -q " -dgpu "; }; then
        case "$DEFAULT_GPU" in
            igpu)
                use_igpu=1
                ;;
            dgpu)
                use_igpu=0
                ;;
        esac
    fi

    # Check for log and root flags in the flags portion only
    case " $flags " in
        *" -lr "*|*" -rl "*)
            use_log=1
            use_root=1
            ;;
        *" -l "*)
            use_log=1
            ;;
        *" -r "*)
            use_root=1
            ;;
    esac

    # Find the AppImage using POSIX-compliant approach
    match=""
    if [ -d "$APPIMAGE_DIR" ]; then
        match=$(find "$APPIMAGE_DIR" -maxdepth 1 -type f -iname "$app_input.AppImage" 2>/dev/null | head -n 1)
    fi

    if [ -z "$match" ]; then
        printf "Error: App not found: %s\n" "$app_input"
        printf "Use 'list' to see available apps\n"
        printf "Use the command \"help\" for more info\n"
        continue
    fi

    if [ ! -x "$match" ]; then
        chmod +x "$match" 2>/dev/null
        if [ $? -ne 0 ]; then
            printf "Error: Cannot make executable: %s\n" "$match"
            continue
        fi
    fi

    # Set up logging if requested
    if [ "$use_log" -eq 1 ]; then
        timestamp=$(date +%Y%m%d_%H%M%S 2>/dev/null || date +%s)
        logfile="$LOG_DIR/$(basename "$match" .AppImage)_${timestamp}.log"
        printf "Logging to: %s\n" "$logfile"
    fi

    # Set GPU environment variables based on selection
    if [ "$use_igpu" -eq 1 ]; then
        # Force integrated GPU
        DRI_PRIME=0
        __GLX_VENDOR_LIBRARY_NAME=mesa
        VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
        export DRI_PRIME __GLX_VENDOR_LIBRARY_NAME VK_ICD_FILENAMES
        gpu_name="iGPU"
    else
        # Force dedicated GPU
        DRI_PRIME=1
        VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/amd_icd64.json
        export DRI_PRIME VK_ICD_FILENAMES
        unset __GLX_VENDOR_LIBRARY_NAME
        gpu_name="dGPU"
    fi

    # Launch the app
    if [ "$use_root" -eq 1 ]; then
        # Add --no-sandbox for root launches (required for Chromium-based apps)
        if [ "$use_log" -eq 1 ]; then
            nohup sudo -E "$match" --no-sandbox > "$logfile" 2>&1 &
        else
            nohup sudo -E "$match" --no-sandbox > /dev/null 2>&1 &
        fi
        printf "Launched: %s with %s (root + --no-sandbox)\n" "$(basename "$match")" "$gpu_name"
    else
        if [ "$use_log" -eq 1 ]; then
            "$match" > "$logfile" 2>&1 &
        else
            "$match" > /dev/null 2>&1 &
        fi
        printf "Launched: %s with %s\n" "$(basename "$match")" "$gpu_name"
    fi

done

printf "Lunaro exited.\n"
```

**Added:**
- When an app is not found, it now prints: `Use the command "help" for more info`

So the error message now looks like:
```
Error: App not found: Whatever
Use 'list' to see available apps
Use the command "help" for more info
