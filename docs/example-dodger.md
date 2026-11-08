# Example game: Dodger

A small, complete 2D arcade game in Godot 4. It exists to show every part of the mechanism in one place:
1. art scripts rendered on the GPU box;
2. assets copied into a game;
3. a headless test;
4. Linux and Windows release builds.

## Play

```bash
godot --path dodger
```

- Space or Enter starts. Move the blue square with WASD or the arrow keys.
- Collect yellow coins (+10) and avoid the red squares.
- You have 3 lives, with 1 second of invulnerability after a hit.
- Score = 10 per coin + seconds survived. The best score is saved to `user://highscore.cfg`.
- Space or Enter restarts after a game over.

## Test

```bash
godot --headless --path dodger -- --selftest         # plays itself, prints SELFTEST_OK
```

The self-test never writes the high score. `-- --autostart` skips the start screen (handy for screenshots). Screenshots without a window, for this 2D game:

```bash
xvfb-run -a -s "-screen 0 960x540x24" godot --path dodger --rendering-driver opengl3 \
  --write-movie /tmp/dodger.png --fixed-fps 30 --quit-after 240 -- --autostart
```

## Its art

The sprites are Blender scripts in `art-src/sprites/`, one per sprite (`player`, `hazard`, `coin`, `background`) plus the shared `common.py`.

```bash
scripts/delegate.sh sprites all 96                      # final sheets (96 px frames)
scripts/delegate.sh sprites coin 256                    # a bigger preview of one sprite
cp build/sprites/*_sheet.png build/sprites/background.png dodger/assets/sprites/
```

Each animated sprite is an 8-frame strip, shown in the game at scale 0.5.

## Release

```bash
scripts/release.sh dodger 0.1.0     # releases/dodger-0.1.0-linux.zip and -windows.zip
```

## Layout

```
dodger/
  project.godot, export_presets.cfg     (presets "Linux" and "Windows Desktop")
  scenes/main.tscn, faller.tscn
  scripts/main.gd (game loop, score, self-test), player.gd, faller.gd
  assets/sprites/                       (sheets rendered by the GPU box)
```

Input uses direct key checks, with no input map.
