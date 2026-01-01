#!/bin/bash
# gog-dosbox-setup
# Extracts GOG DOS game installers and sets up a minimal DOSBox directory
#
# Features:
#   - Extracts game files from GOG .sh (Linux) or .exe (Windows) installers
#   - Uses GOG's original DOSBox configs (preserves game-specific settings)
#   - Fixes CD audio (mounts game.ins instead of game.gog)
#   - Adds sharp pixel scaling (openglnb, normal2x)
#   - Creates easy play.sh launcher

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <gog_installer.sh|.exe> [output_directory]"
    echo ""
    echo "Extracts a GOG DOS game and creates a minimal directory."
    echo "Copies the original GOG DOSBox config and patches it for:"
    echo "  - Sharp pixels (output=openglnb)"
    echo "  - Working CD audio (mounts game.ins, not game.gog)"
    echo ""
    echo "Supported installer types:"
    echo "  - Linux (.sh) - uses unzip"
    echo "  - Windows (.exe) - uses innoextract"
    echo ""
    echo "Examples:"
    echo "  $0 fantasy_general_1_0_20211006_50653.sh"
    echo "  $0 setup_ultima_vii_1.0.exe ~/Games/Ultima7"
    exit 1
}

[[ $# -lt 1 ]] && usage

INSTALLER="$(realpath "$1")"
[[ ! -f "$INSTALLER" ]] && echo -e "${RED}Error: File not found: $1${NC}" && exit 1

# Detect installer type
INSTALLER_TYPE=""
if [[ "$INSTALLER" == *.sh ]]; then
    INSTALLER_TYPE="linux"
elif [[ "$INSTALLER" == *.exe ]]; then
    INSTALLER_TYPE="windows"
    # Check for innoextract
    if ! command -v innoextract &> /dev/null; then
        echo -e "${RED}Error: innoextract is required for Windows installers${NC}"
        echo "Install with: sudo apt install innoextract"
        exit 1
    fi
else
    echo -e "${RED}Error: Unsupported installer type. Use .sh or .exe${NC}"
    exit 1
fi

# Determine output directory
if [[ -n "$2" ]]; then
    OUTPUT_DIR="$(realpath -m "$2")"
else
    # Remove extension (.sh or .exe)
    BASENAME=$(basename "$INSTALLER")
    BASENAME="${BASENAME%.sh}"
    BASENAME="${BASENAME%.exe}"
    # Clean up the game name:
    # 1. Remove gog_, setup_, etc. prefixes
    # 2. Remove version patterns: _1_0_12345 or _2.1.0.4 or 1.0_(22308)
    # 3. Remove language codes: _en, _de, _fr, etc.
    # 4. Convert to Title Case
    GAME_NAME=$(echo "$BASENAME" | sed -E '
        s/^(gog_|setup_)//i;
        s/_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$//;
        s/_[0-9]+_[0-9]+_[0-9]+.*//;
        s/_[0-9]+\.[0-9]+_\([0-9]+\)$//;
        s/_(en|de|fr|es|it|pl|ru|pt|br|jp|ko|cn|zh)(_|$)/_/gi;
        s/_+$//;
        s/_/ /g;
        s/\b\w/\u&/g;
        s/ //g
    ')
    OUTPUT_DIR="$(dirname "$INSTALLER")/$GAME_NAME"
fi

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo -e "${GREEN}=== GOG DOS Game Extractor ===${NC}"
echo "Installer: $INSTALLER"
echo "Output:    $OUTPUT_DIR"
echo ""

# Step 1: Extract game files
echo -e "${YELLOW}[1/7] Extracting game files...${NC}"

if [[ "$INSTALLER_TYPE" == "linux" ]]; then
    chmod +x "$INSTALLER"
    # Use unzip to extract game data (ZIP is appended to the installer)
    # unzip returns 1 for warnings (like "extra bytes") which is OK
    set +e
    unzip -o "$INSTALLER" -d "$TEMP_DIR/extracted" > "$TEMP_DIR/extract.log" 2>&1
    EXTRACT_STATUS=$?
    set -e

    if [[ $EXTRACT_STATUS -le 1 ]]; then
        echo "  Extracted game data via unzip"
    else
        echo -e "${RED}Error: unzip failed with status $EXTRACT_STATUS${NC}"
        cat "$TEMP_DIR/extract.log"
        exit 1
    fi
else
    # Windows installer - use innoextract
    set +e
    innoextract -s "$INSTALLER" -d "$TEMP_DIR/extracted" > "$TEMP_DIR/extract.log" 2>&1
    EXTRACT_STATUS=$?
    set -e

    if [[ $EXTRACT_STATUS -eq 0 ]]; then
        echo "  Extracted game data via innoextract"
    else
        echo -e "${RED}Error: innoextract failed with status $EXTRACT_STATUS${NC}"
        cat "$TEMP_DIR/extract.log"
        exit 1
    fi
fi

# Step 2: Find game data directory (GOG uses varying structures)
GAME_DATA=""
CONFIG_ROOT=""

if [[ "$INSTALLER_TYPE" == "linux" ]]; then
    # Linux installers: game data in data/noarch/game/data or similar
    for path in "$TEMP_DIR/extracted/data/noarch/game/data" \
                "$TEMP_DIR/extracted/data/noarch/data" \
                "$TEMP_DIR/extracted/data/noarch/game" \
                "$TEMP_DIR/extracted/game/data" \
                "$TEMP_DIR/extracted/game"; do
        if [[ -d "$path" ]]; then
            GAME_DATA="$path"
            CONFIG_ROOT="$TEMP_DIR/extracted/data/noarch"
            [[ ! -d "$CONFIG_ROOT" ]] && CONFIG_ROOT=$(dirname "$path")
            break
        fi
    done
else
    # Windows installers: game files at root, configs in __support/app/
    GAME_DATA="$TEMP_DIR/extracted"
    CONFIG_ROOT="$TEMP_DIR/extracted/__support/app"
    
    # Verify the structure exists
    if [[ ! -d "$CONFIG_ROOT" ]]; then
        echo -e "${RED}Error: Expected __support/app/ not found${NC}"
        echo "Extracted contents:"
        find "$TEMP_DIR/extracted" -maxdepth 3 -type d | head -30
        exit 1
    fi
fi

if [[ -z "$GAME_DATA" ]] || [[ ! -d "$GAME_DATA" ]]; then
    echo -e "${RED}Error: Could not find game data${NC}"
    echo "Extracted contents:"
    find "$TEMP_DIR" -maxdepth 5 -type d | head -30
    exit 1
fi

echo "Found game data: $GAME_DATA"
echo "Config root: $CONFIG_ROOT"

# Step 3: Find the original DOSBox configs
# GOG often uses multiple configs: a full one (with [sdl], [render], etc.) and an autoexec one
echo -e "${YELLOW}[2/7] Locating DOSBox configs...${NC}"

FULL_CONF=""      # Config with [sdl] section (display/audio settings)
AUTOEXEC_CONF=""  # Config with non-empty [autoexec] (launch commands)

for conf in "$CONFIG_ROOT"/dosbox*.conf "$CONFIG_ROOT"/*.conf; do
    [[ ! -f "$conf" ]] && continue
    
    # Check if this config has [sdl] section (full config with display settings)
    if grep -q "\[sdl\]" "$conf" 2>/dev/null; then
        FULL_CONF="$conf"
    fi
    
    # Check if this config has non-empty [autoexec] with actual commands
    # Extract everything after [autoexec], filter out comments/blanks, check if anything remains
    # Use grep -a to handle files with ANSI codes that look like binary
    AUTOEXEC_CONTENT=$(awk '/\[autoexec\]/,0' "$conf" 2>/dev/null | tail -n +2 | grep -av '^#' | grep -av '^[[:space:]]*$' | head -1)
    if [[ -n "$AUTOEXEC_CONTENT" ]]; then
        # Prefer _single configs for autoexec (they're meant for launching)
        if [[ "$conf" == *"single"* ]] || [[ -z "$AUTOEXEC_CONF" ]]; then
            AUTOEXEC_CONF="$conf"
        fi
    fi
done

# Fallback: if no autoexec found, use any config with [autoexec] section
if [[ -z "$AUTOEXEC_CONF" ]]; then
    for conf in "$CONFIG_ROOT"/dosbox*.conf "$CONFIG_ROOT"/*.conf; do
        if [[ -f "$conf" ]] && grep -q "\[autoexec\]" "$conf" 2>/dev/null; then
            AUTOEXEC_CONF="$conf"
            break
        fi
    done
fi

if [[ -z "$AUTOEXEC_CONF" ]]; then
    echo -e "${RED}Error: No DOSBox config with autoexec found${NC}"
    echo "Looked in: $CONFIG_ROOT"
    ls -la "$CONFIG_ROOT"
    exit 1
fi

echo "Found configs:"
[[ -n "$FULL_CONF" ]] && echo "  - Full settings: $(basename "$FULL_CONF")"
echo "  - Autoexec: $(basename "$AUTOEXEC_CONF")"

# Step 4: Copy game files
echo -e "${YELLOW}[3/7] Copying game files...${NC}"
mkdir -p "$OUTPUT_DIR"

if [[ "$INSTALLER_TYPE" == "linux" ]]; then
    cp -r "$GAME_DATA"/* "$OUTPUT_DIR/"
else
    # For Windows installers, copy game files but exclude installer artifacts
    for item in "$GAME_DATA"/*; do
        basename_item=$(basename "$item")
        # Skip installer directories and files
        case "$basename_item" in
            __support|__redist|DOSBOX|app|commonappdata|tmp|goggame-*|*.bin)
                continue
                ;;
            *)
                cp -r "$item" "$OUTPUT_DIR/"
                ;;
        esac
    done
fi

# Step 5: Copy and patch the DOSBox configs
echo -e "${YELLOW}[4/7] Copying DOSBox configs...${NC}"

# Copy full config if it exists (has all the settings)
if [[ -n "$FULL_CONF" ]]; then
    cp "$FULL_CONF" "$OUTPUT_DIR/dosbox_settings.conf"
    echo "  - Copied settings config: dosbox_settings.conf"
    
    # Patch: Change output=opengl to output=openglnb for sharp pixels
    if grep -q "^output=opengl$" "$OUTPUT_DIR/dosbox_settings.conf"; then
        sed -i 's/^output=opengl$/output=openglnb/' "$OUTPUT_DIR/dosbox_settings.conf"
        echo "  - Changed output=opengl to output=openglnb (sharp pixels)"
    fi
fi

# Copy autoexec config
cp "$AUTOEXEC_CONF" "$OUTPUT_DIR/dosbox_autoexec.conf"
echo "  - Copied autoexec config: dosbox_autoexec.conf"

# Patch the autoexec config for path fixes
# Fix imgmount to use game.ins instead of game.gog (for CD audio)
if grep -q "game\.gog" "$OUTPUT_DIR/dosbox_autoexec.conf" && [[ -f "$OUTPUT_DIR/game.ins" ]]; then
    sed -i 's/game\.gog/game.ins/g' "$OUTPUT_DIR/dosbox_autoexec.conf"
    echo "  - Changed game.gog to game.ins (CD audio fix)"
fi

# Fix mount paths (GOG uses various subdirs, we flatten it)
sed -i 's|mount [cC] "data"|mount C "."|g' "$OUTPUT_DIR/dosbox_autoexec.conf"
sed -i 's|mount [cC] "\.\."|mount C "."|g' "$OUTPUT_DIR/dosbox_autoexec.conf"
sed -i 's|"data/|"./|g' "$OUTPUT_DIR/dosbox_autoexec.conf"
echo "  - Fixed mount paths for flattened directory"

# Step 6: Copy game-specific config files (Windows installers)
# These are config files like U7.CFG, SERPENT.CFG that contain sound settings
if [[ "$INSTALLER_TYPE" == "windows" ]]; then
    echo -e "${YELLOW}[5/7] Copying game config files...${NC}"
    CFG_COPIED=0
    for cfg in "$CONFIG_ROOT"/*.CFG "$CONFIG_ROOT"/*.cfg; do
        if [[ -f "$cfg" ]]; then
            # Skip if it's a DOSBox config
            if [[ "$(basename "$cfg")" != dosbox* ]]; then
                cp "$cfg" "$OUTPUT_DIR/"
                echo "  - Copied $(basename "$cfg")"
                ((CFG_COPIED++)) || true
            fi
        fi
    done
    if [[ $CFG_COPIED -eq 0 ]]; then
        echo "  - No game-specific config files found"
    fi
else
    echo -e "${YELLOW}[5/7] Checking for game config files...${NC}"
    echo "  - (Linux installers include configs in game data)"
fi

# Step 8: Create display.conf with our display preferences
# This is loaded AFTER dosbox.conf so it overrides display settings
echo -e "${YELLOW}[6/7] Creating display config...${NC}"

cat > "$OUTPUT_DIR/display.conf" << 'DISPLAYCONF'
# Display settings - loaded after game config to override display options
# Edit this file to change window size, scaling, fullscreen, etc.

[sdl]
fullscreen=false
windowresolution=1280x960
# openglnb = OpenGL with no bilinear filtering = sharp pixels
output=openglnb

[render]
# normal2x = simple pixel doubling (sharp, no effects)
# Other options: normal3x, hq2x, hq3x, none
scaler=normal2x
aspect=true
DISPLAYCONF

echo "  - Created display.conf (window size, sharp scaling)"

# Step 9: Create launch script
echo -e "${YELLOW}[7/7] Creating launcher...${NC}"

# Build the config loading command based on what configs we have
if [[ -n "$FULL_CONF" ]]; then
    # We have separate settings and autoexec configs
    cat > "$OUTPUT_DIR/play.sh" << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if command -v dosbox-staging &> /dev/null; then
    DOSBOX="dosbox-staging"
elif command -v dosbox &> /dev/null; then
    DOSBOX="dosbox"
else
    echo "Error: DOSBox not found. Install dosbox or dosbox-staging."
    exit 1
fi

echo "Starting game with $DOSBOX..."
# Load configs in order: settings, autoexec, then display overrides
exec $DOSBOX -conf "$SCRIPT_DIR/dosbox_settings.conf" \
             -conf "$SCRIPT_DIR/dosbox_autoexec.conf" \
             -conf "$SCRIPT_DIR/display.conf"
LAUNCHER
else
    # Only have a single config (autoexec), use display.conf for settings
    cat > "$OUTPUT_DIR/play.sh" << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if command -v dosbox-staging &> /dev/null; then
    DOSBOX="dosbox-staging"
elif command -v dosbox &> /dev/null; then
    DOSBOX="dosbox"
else
    echo "Error: DOSBox not found. Install dosbox or dosbox-staging."
    exit 1
fi

echo "Starting game with $DOSBOX..."
# Load autoexec config, then display settings
exec $DOSBOX -conf "$SCRIPT_DIR/dosbox_autoexec.conf" \
             -conf "$SCRIPT_DIR/display.conf"
LAUNCHER
fi

chmod +x "$OUTPUT_DIR/play.sh"

# Cleanup: Remove unnecessary files
echo ""
echo "Cleaning up..."
CLEANUP_COUNT=0

# Remove temp files and batch launchers
for pattern in "TEMP*.\$\$\$" "XMMHAND.DAT" "*.BAT" "*.bat"; do
    for file in "$OUTPUT_DIR"/$pattern; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            echo "  - Removed $(basename "$file")"
            ((CLEANUP_COUNT++)) || true
        fi
    done
done

# Remove installer artifacts (Windows)
for dir in "__support" "__redist" "DOSBOX" "app" "commonappdata" "tmp"; do
    if [[ -d "$OUTPUT_DIR/$dir" ]]; then
        rm -rf "$OUTPUT_DIR/$dir"
        echo "  - Removed $dir/"
        ((CLEANUP_COUNT++)) || true
    fi
done

# Remove GOG installer files
for file in "$OUTPUT_DIR"/goggame-*; do
    if [[ -f "$file" ]]; then
        rm -f "$file"
        echo "  - Removed $(basename "$file")"
        ((CLEANUP_COUNT++)) || true
    fi
done

if [[ $CLEANUP_COUNT -eq 0 ]]; then
    echo "  - No cleanup needed"
fi

# Summary
echo ""
echo -e "${GREEN}=== Done! ===${NC}"
du -sh "$OUTPUT_DIR" | awk '{print "Size: "$1}'
echo ""
echo "To play:"
echo "  cd \"$OUTPUT_DIR\" && ./play.sh"
