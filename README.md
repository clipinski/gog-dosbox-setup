# gog-dosbox-setup

A simple script to extract GOG DOS games and set them up for your local DOSBox installation. Supports both **Linux** (`.sh`) and **Windows** (`.exe`) installers.

## Why?

GOG installers come with their own bundled DOSBox and GUI installers. This script skips all that and just extracts the game files into a **portable, self-contained directory** that works with your existing DOSBox installation.

- **No installer GUI** — just run the script and play
- **Portable** — the game folder has everything it needs, copy it anywhere
- **Uses your DOSBox** — no need for GOG's bundled version
- **Clean directories** — sensible folder names like `FantasyGeneral` instead of long paths
- **Works with both Linux and Windows GOG installers**

## What it does

- Extracts game files from GOG installers (`.sh` or `.exe`)
- Preserves GOG's original DOSBox settings (cycles, sound, memory, etc.)
- Copies game-specific config files (sound settings, etc.)
- Fixes CD audio so music works properly
- Adds sharp pixel scaling (no blurry upscaling)
- Creates a simple `play.sh` launcher for each game
- Cleans up temp files and installer artifacts

## Requirements

- **Linux** (tested on Ubuntu)
- **DOSBox** installed locally
- **unzip** (for Linux `.sh` installers)
- **innoextract** (for Windows `.exe` installers)

### Installing Dependencies

**Ubuntu/Debian:**
```bash
sudo apt install dosbox unzip innoextract
```

**Fedora:**
```bash
sudo dnf install dosbox unzip innoextract
```

**Arch:**
```bash
sudo pacman -S dosbox unzip innoextract
```

## Supported Installer Types

This script works with both **Linux** and **Windows** GOG installers:

| Type | Extension | Extraction Tool |
|------|-----------|-----------------|
| Linux | `.sh` | unzip |
| Windows | `.exe` | innoextract |

**Not supported:**
- macOS installers (`.dmg`, `.pkg`)
- GOG Galaxy download stubs (must download offline installer)

Example installer filenames:
```
fantasy_general_1_0_20211006_50653.sh          # Linux
setup_ultima_vii_-_the_black_gate_1.0_(22308).exe  # Windows
```

## Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/gog-dosbox-setup/main/gog-dosbox-setup.sh

# Make it executable
chmod +x gog-dosbox-setup.sh

# Optionally move to your PATH
sudo mv gog-dosbox-setup.sh /usr/local/bin/gog-dosbox-setup
```

## Usage

### Extract a game (Linux installer)

```bash
./gog-dosbox-setup.sh ~/Downloads/fantasy_general_1_0_20211006_50653.sh
```

### Extract a game (Windows installer)

```bash
./gog-dosbox-setup.sh ~/Downloads/setup_ultima_vii_-_the_black_gate_1.0_\(22308\).exe
```

This creates a folder with the game name:
```
~/Downloads/UltimaVii-TheBlackGate/
├── dosbox_settings.conf   # GOG's original settings
├── dosbox_autoexec.conf   # Startup commands
├── display.conf           # Your display preferences
├── play.sh                # Launcher script
├── U7.CFG                 # Game-specific config (sound, etc.)
└── [game files...]
```

### Play the game

```bash
cd ~/Downloads/UltimaVii-TheBlackGate
./play.sh
```

### Specify output directory

```bash
./gog-dosbox-setup.sh ~/Downloads/gog_dungeon_hack_2.1.0.4.sh ~/Games/DungeonHack
```

## Customizing Display Settings

Each game has a `display.conf` file you can edit:

```ini
[sdl]
fullscreen=false
windowresolution=1280x960
output=openglnb

[render]
scaler=normal2x
aspect=true
```

### Common tweaks

**Fullscreen:**
```ini
fullscreen=true
```

**Larger window (3x scaling):**
```ini
windowresolution=1920x1440
scaler=normal3x
```

**Smaller window (original size):**
```ini
windowresolution=original
scaler=none
```

**Softer/smoother graphics (bilinear filtering):**
```ini
output=opengl
```

By default, this script uses `output=openglnb` (OpenGL **N**o **B**ilinear) which gives you sharp, crisp pixels — faithful to how DOS games looked on a CRT. 

If you prefer a softer, smoother look (some people find sharp pixels too harsh on modern displays), change it back to `output=opengl`. This enables bilinear filtering which smooths the pixels when scaling up:

| Setting | Look | Best for |
|---------|------|----------|
| `output=openglnb` | Sharp, crisp pixels | Authenticity, pixel art fans |
| `output=opengl` | Soft, smoothed pixels | Easier on the eyes, larger displays |

## Tested Games

| Game | Installer Type | Status |
|------|----------------|--------|
| Fantasy General | Linux (.sh) | ✅ Works (with CD music) |
| Dungeon Hack | Linux (.sh) | ✅ Works |
| Epic Pinball: The Complete Collection | Linux (.sh) | ✅ Works |
| Eye of the Beholder | Linux (.sh) | ✅ Works |
| Ultima VII: The Black Gate | Windows (.exe) | ✅ Works |
| Ultima VII: Serpent Isle | Windows (.exe) | ✅ Works |

## How it works

**Linux installers (`.sh`)** are self-extracting archives containing a MojoSetup GUI and embedded ZIP with game files. The script uses `unzip` to extract the game data directly.

**Windows installers (`.exe`)** are Inno Setup packages. The script uses `innoextract` to extract game files and configs from `__support/app/`.

For both types, the script:
1. Extracts game files to a clean directory
2. Finds and copies GOG's DOSBox configs
3. Copies game-specific config files (sound settings, etc.)
4. Fixes mount paths for the flattened directory structure
5. Fixes CD audio mounting (`game.ins` instead of `game.gog`)
6. Adds a `display.conf` with sharp scaling settings
7. Creates a `play.sh` launcher that uses your local DOSBox
8. Cleans up temp files and installer artifacts

## Troubleshooting

### "DOSBox not found"
Install DOSBox: `sudo apt install dosbox`

### "innoextract is required for Windows installers"
Install innoextract: `sudo apt install innoextract`

### Game window is too small
Edit `display.conf` and change `windowresolution=1280x960` to a larger value like `1920x1440`

### No music in game
The script should fix this automatically. If music still doesn't work, check that `game.ins` exists in the game folder and that `dosbox_autoexec.conf` contains `imgmount d "./game.ins"`.

### No sound in game
For Windows installers, game-specific config files (like `U7.CFG`) contain sound settings. These should be copied automatically. Check that the `.CFG` file exists in your game folder.

### Game runs too fast/slow
Edit `dosbox_settings.conf` and adjust the `cycles=` value in the `[cpu]` section.

### Game crashes immediately
Check `dosbox_autoexec.conf` and make sure the mount path is `mount C "."` (current directory), not `mount C ".."` (parent directory).

## License

MIT License - do whatever you want with it.

## Contributing

Issues and pull requests welcome!

