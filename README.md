# gog-dosbox-setup

A simple script to extract GOG DOS games (Linux installers) and set them up for your local DOSBox installation.

## Why?

GOG's Linux installers come with their own bundled DOSBox and a MojoSetup GUI installer. This script skips all that and just extracts the game files into a **portable, self-contained directory** that works with your existing DOSBox installation.

- **No installer GUI** — just run the script and play
- **Portable** — the game folder has everything it needs, copy it anywhere
- **Uses your DOSBox** — no need for GOG's bundled version
- **Clean directories** — sensible folder names like `FantasyGeneral` instead of long paths

## What it does

- Extracts game files from GOG Linux installers (`.sh` files)
- Preserves GOG's original DOSBox settings (cycles, sound, memory, etc.)
- Fixes CD audio so music works properly
- Adds sharp pixel scaling (no blurry upscaling)
- Creates a simple `play.sh` launcher for each game

## Requirements

- **Linux** (tested on Ubuntu)
- **DOSBox** installed locally
- **GOG DOS game** downloaded as a Linux installer (`.sh` file)

### Installing DOSBox

**Ubuntu/Debian:**
```bash
sudo apt install dosbox
```

**Fedora:**
```bash
sudo dnf install dosbox
```

**Arch:**
```bash
sudo pacman -S dosbox
```

## Important: Linux Installers Only

This script only works with **GOG Linux installers** (the `.sh` files). It will **not** work with:
- Windows installers (`.exe`)
- macOS installers (`.dmg`, `.pkg`)
- Offline backup installers

When downloading from GOG, make sure to select the **Linux** version.

The installer filename will look like:
```
fantasy_general_1_0_20211006_50653.sh
gog_dungeon_hack_2.1.0.4.sh
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

### Extract a game

```bash
./gog-dosbox-setup.sh ~/Downloads/fantasy_general_1_0_20211006_50653.sh
```

This creates a folder with the game name:
```
~/Downloads/FantasyGeneral/
├── dosbox_settings.conf   # GOG's original settings
├── dosbox_autoexec.conf   # Startup commands
├── display.conf           # Your display preferences
├── play.sh                # Launcher script
└── [game files...]
```

### Play the game

```bash
cd ~/Downloads/FantasyGeneral
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

| Game | Status |
|------|--------|
| Fantasy General | ✅ Works (with CD music) |
| Dungeon Hack | ✅ Works |
| Epic Pinball: The Complete Collection | ✅ Works |
| Eye of the Beholder | ✅ Works |

## How it works

GOG Linux installers are self-extracting archives that contain:
1. A MojoSetup installer (GUI)
2. The actual game files (as an embedded ZIP)
3. DOSBox with bundled libraries
4. Pre-configured DOSBox settings

This script:
1. Extracts the game files using `unzip` (skips the MojoSetup installer)
2. Finds and copies GOG's DOSBox configs
3. Fixes paths for the flattened directory structure
4. Fixes CD audio mounting (`game.ins` instead of `game.gog`)
5. Adds a `display.conf` with sharp scaling settings
6. Creates a `play.sh` launcher that uses your local DOSBox

## Troubleshooting

### "DOSBox not found"
Install DOSBox: `sudo apt install dosbox`

### Game window is too small
Edit `display.conf` and change `windowresolution=1280x960` to a larger value like `1920x1440`

### No music in game
The script should fix this automatically. If music still doesn't work, check that `game.ins` exists in the game folder and that `dosbox_autoexec.conf` contains `imgmount d "./game.ins"`.

### Game runs too fast/slow
Edit `dosbox_settings.conf` and adjust the `cycles=` value in the `[cpu]` section.

## License

MIT License - do whatever you want with it.

## Contributing

Issues and pull requests welcome!

