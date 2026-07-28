#!/bin/sh

VERSION="2.1.0"

CONFIG_DIR="$HOME/lunaroconf"
CONFIG_FILE="$CONFIG_DIR/config"
FAV_FILE="$CONFIG_DIR/favorites"
ALIAS_FILE="$CONFIG_DIR/aliases"
APPIMAGE_DIR="$HOME/pwogams"
LOG_DIR="$HOME/lunarologs"
DEFAULT_GPU="dgpu"
LUNARO_UI="ask"

mkdir -p "$CONFIG_DIR"
mkdir -p "$APPIMAGE_DIR"
mkdir -p "$LOG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'EOF'
# ╔══════════════════════════════╗
# ║     Lunaro Configuration     ║
# ╚══════════════════════════════╝

# ── Directories ──────────────────────────────────────────
# Where your apps (.AppImage, .jar, .py, .sh) are stored
APPIMAGE_DIR=$HOME/pwogams

# Where launch logs are saved (only used when -l flag is set)
LOG_DIR=$HOME/lunarologs

# ── GPU ──────────────────────────────────────────────────
# Which GPU to use by default when launching apps
#   dgpu  →  Dedicated GPU (recommended for gaming)
#   igpu  →  Integrated GPU (saves power)
DEFAULT_GPU=dgpu

# ── Interface ────────────────────────────────────────────
# How Lunaro opens
#   ask   →  Ask every time (GUI or CLI)
#   gui   →  Always open the graphical interface
#   cli   →  Always open in terminal
LUNARO_UI=ask
EOF
    echo "Created config at: $CONFIG_FILE"
fi

if [ ! -f "$FAV_FILE" ]; then
    touch "$FAV_FILE"
fi

if [ ! -f "$ALIAS_FILE" ]; then
    cat > "$ALIAS_FILE" << 'EOF'
# ╔══════════════════════════════╗
# ║       Lunaro Aliases         ║
# ╚══════════════════════════════╝
# Create short names for your apps.
# Format: alias=RealAppName
# Example:
#   discord=Discord
#   mc=Minecraft
#   ide=IntelliJ-IDEA
EOF
fi

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

APPIMAGE_DIR=$(echo "$APPIMAGE_DIR" | sed "s|\$HOME|$HOME|g")
LOG_DIR=$(echo "$LOG_DIR" | sed "s|\$HOME|$HOME|g")

mkdir -p "$APPIMAGE_DIR"
mkdir -p "$LOG_DIR"

USE_WAYLAND=0
USE_SWITCHEROO=0

if [ -n "$WAYLAND_DISPLAY" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    USE_WAYLAND=1
    if command -v switcherooctl >/dev/null 2>&1; then
        USE_SWITCHEROO=1
    fi
fi

IGPU_ENV=""
DGPU_ENV=""

if [ "$USE_SWITCHEROO" -eq 1 ]; then
    switcheroo_output=$(switcherooctl list 2>/dev/null)
    IGPU_ENV=$(echo "$switcheroo_output" | grep -A 10 "Discrete:.*no" | grep "Environment:" | head -n 1 | sed 's/^[[:space:]]*Environment:[[:space:]]*//')
    DGPU_ENV=$(echo "$switcheroo_output" | grep -A 10 "Discrete:.*yes" | grep "Environment:" | head -n 1 | sed 's/^[[:space:]]*Environment:[[:space:]]*//')
fi

detect_terminal() {
    for term in xterm konsole gnome-terminal xfce4-terminal mate-terminal lxterminal tilix kitty alacritty wezterm foot rxvt urxvt terminator termite st; do
        if command -v "$term" >/dev/null 2>&1; then
            echo "$term"
            return
        fi
    done
    echo ""
}

TERMINAL=$(detect_terminal)

terminal_exec() {
    cmd="$1"
    case "$TERMINAL" in
        xterm)           xterm -e sh -c "$cmd" ;;
        konsole)         konsole -e sh -c "$cmd" ;;
        gnome-terminal)  gnome-terminal -- sh -c "$cmd" ;;
        xfce4-terminal)  xfce4-terminal -e "sh -c '$cmd'" ;;
        mate-terminal)   mate-terminal -e "sh -c '$cmd'" ;;
        lxterminal)      lxterminal -e "sh -c '$cmd'" ;;
        tilix)           tilix -e "sh -c '$cmd'" ;;
        kitty)           kitty sh -c "$cmd" ;;
        alacritty)       alacritty -e sh -c "$cmd" ;;
        wezterm)         wezterm start -- sh -c "$cmd" ;;
        foot)            foot sh -c "$cmd" ;;
        rxvt|urxvt)      "$TERMINAL" -e sh -c "$cmd" ;;
        terminator)      terminator -e "sh -c '$cmd'" ;;
        termite)         termite -e "sh -c '$cmd'" ;;
        st)              st -e sh -c "$cmd" ;;
        *) sh -c "$cmd" ;;
    esac
}

# ==================== ALIASES ====================

resolve_alias() {
    input="$1"
    if [ ! -f "$ALIAS_FILE" ]; then
        echo "$input"
        return
    fi
    resolved=$(grep -v '^#' "$ALIAS_FILE" | grep -v '^$' | grep "^$input=" | cut -d= -f2- | head -n1)
    if [ -n "$resolved" ]; then
        echo "$resolved"
    else
        echo "$input"
    fi
}

add_alias() {
    alias_name="$1"
    target="$2"
    if [ -z "$alias_name" ] || [ -z "$target" ]; then
        printf "Usage: alias <shortname> <AppName>\n"
        return
    fi
    match=$(find_app "$target")
    if [ -z "$match" ]; then
        printf "App not found: %s\n" "$target"
        return
    fi
    grep -v "^$alias_name=" "$ALIAS_FILE" > "$ALIAS_FILE.tmp" 2>/dev/null
    mv "$ALIAS_FILE.tmp" "$ALIAS_FILE"
    echo "$alias_name=$target" >> "$ALIAS_FILE"
    printf "Alias set: %s → %s\n" "$alias_name" "$target"
}

remove_alias() {
    alias_name="$1"
    if [ -z "$alias_name" ]; then
        printf "Usage: unalias <shortname>\n"
        return
    fi
    if ! grep -q "^$alias_name=" "$ALIAS_FILE" 2>/dev/null; then
        printf "Alias not found: %s\n" "$alias_name"
        return
    fi
    grep -v "^$alias_name=" "$ALIAS_FILE" > "$ALIAS_FILE.tmp" 2>/dev/null
    mv "$ALIAS_FILE.tmp" "$ALIAS_FILE"
    printf "Removed alias: %s\n" "$alias_name"
}

list_aliases() {
    printf "Aliases:\n"
    found=0
    if [ -f "$ALIAS_FILE" ]; then
        while IFS= read -r line; do
            case "$line" in
                "#"*|"") continue ;;
            esac
            alias_name=$(echo "$line" | cut -d= -f1)
            target=$(echo "$line" | cut -d= -f2-)
            printf "  %-20s → %s\n" "$alias_name" "$target"
            found=1
        done < "$ALIAS_FILE"
    fi
    [ "$found" -eq 0 ] && printf "  (none set)\n"
}

# ==================== APP HELPERS ====================

find_app() {
    app_input="$1"
    for ext in AppImage jar py sh; do
        found=$(find "$APPIMAGE_DIR" -maxdepth 1 -type f -iname "$app_input.$ext" 2>/dev/null | head -n 1)
        if [ -n "$found" ]; then
            echo "$found"
            return
        fi
    done
    echo ""
}

get_appname() {
    basename "$1" | sed 's/\.[^.]*$//'
}

get_ext() {
    echo "${1##*.}"
}

needs_terminal() {
    case "$1" in
        *.py|*.jar) return 0 ;;
        *) return 1 ;;
    esac
}

is_favorite() {
    grep -Fxq "$1" "$FAV_FILE" 2>/dev/null
}

add_favorite() {
    app_name="$1"
    [ -z "$app_name" ] && printf "Usage: fav <appname>\n" && return
    match=$(find_app "$app_name")
    [ -z "$match" ] && printf "App not found: %s\n" "$app_name" && return
    actual_name=$(get_appname "$match")
    grep -Fxq "$actual_name" "$FAV_FILE" 2>/dev/null && printf "'%s' already in favorites\n" "$actual_name" && return
    echo "$actual_name" >> "$FAV_FILE"
    printf "Added '%s' to favorites ⭐\n" "$actual_name"
}

remove_favorite() {
    app_name="$1"
    [ -z "$app_name" ] && printf "Usage: unfav <appname>\n" && return
    grep -Fxq "$app_name" "$FAV_FILE" 2>/dev/null || { printf "'%s' not in favorites\n" "$app_name"; return; }
    grep -Fxv "$app_name" "$FAV_FILE" > "$FAV_FILE.tmp" 2>/dev/null
    mv "$FAV_FILE.tmp" "$FAV_FILE"
    printf "Removed '%s' from favorites\n" "$app_name"
}

set_gpu_env() {
    use_igpu=$1
    unset DRI_PRIME __GLX_VENDOR_LIBRARY_NAME VK_ICD_FILENAMES
    unset __NV_PRIME_RENDER_OFFLOAD __VK_LAYER_NV_optimus VK_LOADER_DRIVERS_SELECT

    if [ "$USE_SWITCHEROO" -eq 1 ]; then
        if [ "$use_igpu" -eq 1 ]; then
            if [ -n "$IGPU_ENV" ]; then
                for var in $IGPU_ENV; do
                    key=$(echo "$var" | cut -d= -f1)
                    value=$(echo "$var" | cut -d= -f2-)
                    export "$key=$value"
                done
                gpu_name="iGPU"
            else
                gpu_name="iGPU (detection failed)"
            fi
        else
            if [ -n "$DGPU_ENV" ]; then
                for var in $DGPU_ENV; do
                    key=$(echo "$var" | cut -d= -f1)
                    value=$(echo "$var" | cut -d= -f2-)
                    export "$key=$value"
                done
                gpu_name="dGPU"
            else
                gpu_name="dGPU (detection failed)"
            fi
        fi
    else
        if [ "$use_igpu" -eq 1 ]; then
            DRI_PRIME=0
            __GLX_VENDOR_LIBRARY_NAME=mesa
            VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.x86_64.json
            export DRI_PRIME __GLX_VENDOR_LIBRARY_NAME VK_ICD_FILENAMES
            gpu_name="iGPU"
        else
            DRI_PRIME=1
            VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/amd_icd64.json
            export DRI_PRIME VK_ICD_FILENAMES
            gpu_name="dGPU"
        fi
    fi
}

launch_app() {
    match="$1"
    use_igpu="$2"
    use_root="$3"
    use_log="$4"

    case "$match" in
        *.AppImage|*.sh)
            if [ ! -x "$match" ]; then
                chmod +x "$match" 2>/dev/null || { printf "Error: Cannot make executable: %s\n" "$match"; return 1; }
            fi
            ;;
    esac

    if [ "$use_log" -eq 1 ]; then
        timestamp=$(date +%Y%m%d_%H%M%S 2>/dev/null || date +%s)
        logfile="$LOG_DIR/$(get_appname "$match")_${timestamp}.log"
        printf "Logging to: %s\n" "$logfile"
    fi

    set_gpu_env "$use_igpu"
    appname=$(get_appname "$match")

    case "$match" in
        *.AppImage) cmd="\"$match\"" ;;
        *.sh)       cmd="bash \"$match\"" ;;
        *.py)       cmd="python3 \"$match\"" ;;
        *.jar)      cmd="java -jar \"$match\"" ;;
    esac

    [ "$use_root" -eq 1 ] && cmd="sudo -E $cmd --no-sandbox"

    if needs_terminal "$match" && [ -n "$TERMINAL" ]; then
        if [ "$use_log" -eq 1 ]; then
            terminal_exec "$cmd > \"$logfile\" 2>&1" &
        else
            terminal_exec "$cmd" &
        fi
    else
        if [ "$use_log" -eq 1 ]; then
            nohup sh -c "$cmd" > "$logfile" 2>&1 &
        else
            nohup sh -c "$cmd" > /dev/null 2>&1 &
        fi
    fi

    printf "Launched: %s with %s\n" "$appname" "$gpu_name"
}

# ==================== YAD HELPERS ====================

YAD_COMMON="--center --borders=12 --window-icon=application-x-executable"
YAD_TITLE="Lunaro"

yad_error() {
    yad $YAD_COMMON \
        --title="$YAD_TITLE — Error" \
        --image="dialog-error" \
        --text="$1" \
        --button="OK:0" \
        --width=300
}

yad_info() {
    yad $YAD_COMMON \
        --title="$YAD_TITLE" \
        --image="dialog-information" \
        --text="$1" \
        --button="OK:0" \
        --width=300
}

# ==================== GUI MODE ====================

build_app_list() {
    filter="$1"
    for ext in AppImage jar py sh; do
        for app in "$APPIMAGE_DIR"/*.$ext; do
            if [ -f "$app" ]; then
                appname=$(get_appname "$app")
                if [ -z "$filter" ] || echo "$appname" | grep -qi "$filter"; then
                    printf "%s\n%s\n" "$appname" "$ext"
                fi
            fi
        done
    done
}

gui_mode() {
    filter=""

    while true; do
        app_list=$(build_app_list "$filter")

        if [ -z "$app_list" ]; then
            if [ -z "$filter" ]; then
                yad_error "No apps found in $APPIMAGE_DIR"
                return
            fi
            yad_error "No apps found matching: $filter"
            filter=""
            continue
        fi

        selected=$(printf "%s\n" "$app_list" | yad $YAD_COMMON \
            --title="$YAD_TITLE — Apps" \
            --list \
            --column="Name" \
            --column="Type" \
            --text="Select an app to launch$([ -n "$filter" ] && echo " <small>(filter: <b>$filter</b>)</small>")" \
            --button="Launch:0" \
            --button="Search:2" \
            --button="Quit:1" \
            --width=420 --height=440 \
            --print-column=1)

        ret=$?

        case "$ret" in
            1|252)
                return
                ;;
            2)
                new_filter=$(yad $YAD_COMMON \
                    --title="$YAD_TITLE — Search" \
                    --entry \
                    --text="Type to filter apps:" \
                    --entry-text="$filter" \
                    --button="Search:0" \
                    --button="Clear:1" \
                    --width=300)
                search_ret=$?
                if [ $search_ret -eq 1 ]; then
                    filter=""
                elif [ $search_ret -eq 0 ]; then
                    filter="$new_filter"
                fi
                continue
                ;;
            0)
                app_input=$(echo "$selected" | tr -d '|' | tr -d '\n')
                [ -z "$app_input" ] && continue

                match=$(find_app "$app_input")
                [ -z "$match" ] && continue

                gpu_choice=$(yad $YAD_COMMON \
                    --title="$YAD_TITLE — GPU" \
                    --list \
                    --column="GPU" \
                    --text="Select GPU for <b>$app_input</b>" \
                    --button="Select:0" \
                    --button="Back:1" \
                    --width=280 --height=180 \
                    --print-column=1 \
                    "Dedicated (dGPU)" \
                    "Integrated (iGPU)")

                [ $? -ne 0 ] && continue

                case "$gpu_choice" in
                    *iGPU*) use_igpu=1 ;;
                    *)       use_igpu=0 ;;
                esac

                opts=$(yad $YAD_COMMON \
                    --title="$YAD_TITLE — Options" \
                    --form \
                    --text="Launch options for <b>$app_input</b>" \
                    --field="Enable logging:CHK" "FALSE" \
                    --field="Run as root:CHK" "FALSE" \
                    --button="Launch:0" \
                    --button="Back:1" \
                    --width=300)

                [ $? -ne 0 ] && continue

                use_log=$(echo "$opts" | cut -d'|' -f1)
                use_root=$(echo "$opts" | cut -d'|' -f2)

                [ "$use_log" = "TRUE" ] && use_log=1 || use_log=0
                [ "$use_root" = "TRUE" ] && use_root=1 || use_root=0

                launch_app "$match" "$use_igpu" "$use_root" "$use_log"
                yad_info "<b>$app_input</b> launched with $gpu_name"
                ;;
        esac
    done
}

# ==================== CLI MODE ====================

show_help() {
    cat << 'EOF'
Lunaro - App Launcher

USAGE:
  <appname> [flags]
  <alias> [flags]

SUPPORTED FILE TYPES:
  .AppImage  Runs directly
  .jar       Runs with java (in terminal)
  .py        Runs with python3 (in terminal)
  .sh        Runs with bash

COMMANDS:
  list              Show all apps
  fav <app>         Add app to favorites
  unfav <app>       Remove app from favorites
  alias <n> <app>   Create a short name for an app
  unalias <n>       Remove an alias
  aliases           List all aliases
  help              Show this help
  exit/quit         Exit Lunaro

FLAGS:
  -igpu   Launch with iGPU
  -dgpu   Launch with dGPU (default)
  -l      Enable logging
  -r      Run as root
  -lr/-rl Logging + root
EOF
}

list_apps() {
    printf "Apps in %s:\n" "$APPIMAGE_DIR"
    found=0

    if [ -s "$FAV_FILE" ]; then
        printf "\n⭐ Favorites:\n"
        while IFS= read -r fav; do
            result=$(find_app "$fav")
            if [ -n "$result" ]; then
                printf "  %-30s .%s\n" "$fav" "$(get_ext "$result")"
                found=1
            fi
        done < "$FAV_FILE"
    fi

    printf "\n📦 All Apps:\n"
    for ext in AppImage jar py sh; do
        for app in "$APPIMAGE_DIR"/*.$ext; do
            if [ -f "$app" ]; then
                appname=$(get_appname "$app")
                is_fav=0
                if [ -f "$FAV_FILE" ]; then
                    while IFS= read -r fav; do
                        [ "$appname" = "$fav" ] && is_fav=1 && break
                    done < "$FAV_FILE"
                fi
                [ "$is_fav" -eq 0 ] && printf "  %-30s .%s\n" "$appname" "$ext"
                found=1
            fi
        done
    done

    [ "$found" -eq 0 ] && printf "  (none found)\n"
}

cli_mode() {
    echo "Lunaro v$VERSION"
    echo "────────────────────────────"
    echo "App dir : $APPIMAGE_DIR"
    echo "Log dir : $LOG_DIR"
    echo "GPU     : $DEFAULT_GPU"
    echo "Display : $([ "$USE_WAYLAND" -eq 1 ] && echo Wayland || echo X11)"
    echo "Terminal: ${TERMINAL:-none}"
    echo "────────────────────────────"
    echo "Type 'help' or 'exit'"

    while true; do
        printf "\nlunaro> "

        if ! IFS= read -r line; then break; fi

        case "$line" in
            "") continue ;;
            exit|quit) break ;;
            help) show_help; continue ;;
            list) list_apps; continue ;;
            aliases) list_aliases; continue ;;
            fav\ *) add_favorite "$(echo "$line" | sed 's/^fav //')"; continue ;;
            unfav\ *) remove_favorite "$(echo "$line" | sed 's/^unfav //')"; continue ;;
            alias\ *)
                rest=$(echo "$line" | sed 's/^alias //')
                alias_name=$(echo "$rest" | awk '{print $1}')
                target=$(echo "$rest" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
                add_alias "$alias_name" "$target"
                continue
                ;;
            unalias\ *) remove_alias "$(echo "$line" | sed 's/^unalias //')"; continue ;;
            eggegg) printf "    🥚\n   🥚\n"; continue ;;
        esac

        use_log=0; use_root=0; use_igpu=0

        app_input=$(printf '%s\n' "$line" | awk '{print $1}')
        flags=$(printf '%s\n' "$line" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')

        app_input=$(resolve_alias "$app_input")

        case " $flags " in *" -igpu "*) use_igpu=1 ;; *" -dgpu "*) use_igpu=0 ;; esac

        if [ -z "$flags" ] || { [ "$use_igpu" -eq 0 ] && ! printf '%s' " $flags " | grep -q " -dgpu "; }; then
            case "$DEFAULT_GPU" in igpu) use_igpu=1 ;; dgpu) use_igpu=0 ;; esac
        fi

        case " $flags " in
            *" -lr "*|*" -rl "*) use_log=1; use_root=1 ;;
            *" -l "*) use_log=1 ;;
            *" -r "*) use_root=1 ;;
        esac

        match=$(find_app "$app_input")

        if [ -z "$match" ]; then
            printf "Not found: %s — try 'list'\n" "$app_input"
            continue
        fi

        launch_app "$match" "$use_igpu" "$use_root" "$use_log"
    done

    printf "Lunaro exited.\n"
}

# ==================== STARTUP ====================

case "$LUNARO_UI" in
    gui)
        gui_mode
        ;;
    cli)
        cli_mode
        ;;
    ask|*)
        yad $YAD_COMMON \
            --title="$YAD_TITLE" \
            --text="<b>Welcome to Lunaro</b>\n\nHow would you like to launch?" \
            --button="  GUI :0" \
            --button="  CLI :1" \
            --button="Quit:2" \
            --width=300 --height=140 2>/dev/null
        ret=$?
        case "$ret" in
            0) gui_mode ;;
            1) cli_mode ;;
            *) exit 0 ;;
        esac
        ;;
esac
