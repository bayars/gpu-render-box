# gpu-render-box

Run Blender renders and Blender/Godot builds on a remote GPU machine, from a laptop that has no GPU, with **one command**.

```bash
scripts/delegate.sh models lamp
```

That one line:
1. checks your work is committed and pushes the branch;
2. moves the GPU machine's copy of the repo to that exact commit;
3. runs the job there with a lock, a time limit and a temperature check, and logs everything;
4. copies the results back to `build/` or `renders/` on your laptop and opens the newest image.

You keep coding, using git and running quick tests on the laptop. The GPU box only ever runs the code you pushed.

```
laptop (code, git, quick tests)              GPU box (a disposable checkout of this repo)
──────────────────────────────               ─────────────────────────────────────────────
scripts/delegate.sh <job> [args]
  ├─ clean tree? feature branch? ─ git push ─▶ GitHub
  ├─ ssh ──────────────────────────────────▶  scripts/remote_run.sh <branch> <job> [args]
  │                                             ├─ fetch + check out the pushed commit
  │                                             ├─ GPU over 80 °C? refuse
  │                                             ├─ flock (one GPU job at a time) + timeout
  │                                             ├─ run scripts/<job>.sh (Blender / Godot / ffmpeg)
  │                                             └─ log: ~/work/logs/<job>-<sha>-<time>.log, ends with EXIT=<code>
  └─ scripts/pull.sh ◀──────── rsync ───────  renders/  build/
```

## What it can do

| Job | Command | Result on the laptop |
|---|---|---|
| Render a `.blend` with Cycles (CUDA) | `delegate.sh render art-src/scene.blend 1 24 [--samples N] [--res-percent N]` | `renders/scene/frame_0001.png` … |
| Export a `.blend` to glTF for Godot | `delegate.sh export_gltf art-src/scene.blend` | `build/gltf/scene.glb` |
| Build 3D models from Python scripts | `delegate.sh models [--cpu] [name… \| all]` | `build/models/<name>.glb` + `<name>_preview.png` |
| Bake seamless PBR textures | `delegate.sh textures [name…]` | `build/textures/<name>_{albedo,normal,rough}.png` + contact sheets |
| Render 2D sprite sheets | `delegate.sh sprites [name \| all] [size]` | `build/sprites/<name>_sheet.png` |
| Export a Godot game | `delegate.sh build_linux <project>` / `build_windows <project>` | `build/<game>-<platform>.zip` |
| Both platforms, versioned | `scripts/release.sh <project> <version>` | `releases/<game>-<version>-<platform>.zip` |
| Encode a video (NVENC, falls back to x264) | `delegate.sh encode renders/x/frame_%04d.png renders/x.mp4` | `renders/x.mp4` |
| Smoke test | `delegate.sh gen_test_blend`, then `delegate.sh render renders/_gen/test.blend 1 1` | a rendered cube |

Add `--detach` before the job name for long jobs (`delegate.sh --detach models all`). The job then runs in tmux on the GPU box, and the laptop follows the log until it ends, so a dropped SSH connection doesn't kill it.

## Art as code

There are no hand-made binary art files to keep in sync. Models, textures and sprites are **Python scripts that Blender runs on the GPU box**, and the GPU box sends back a preview image so you can judge each one:

```python
# art-src/models/lamp.py
from common import *
reset()
iron = mat("Iron", "#23262B", metallic=0.7, roughness=0.45)
root = empty("Lamp")
cyl("Pole", 0.05, 1.9, (0, 0, 1.05), iron, root)
...
finish(out_path())          # -> build/models/lamp.glb + lamp_preview.png
```

The repo includes:
- **Model helpers** (`art-src/models/common.py`): materials, primitives, joints as empties, glTF export and a Cycles preview. There are three small example models.
- **A PBR texture baker** (`art-src/textures/pbr.py`): nine recipes, made seamless by sampling the noise on a 4D torus.
- **Sprite scripts** (`art-src/sprites/`) for the example game.

## The example game: Dodger

`dodger/` is a small, complete Godot 4 game that shows the whole loop:
1. sprite scripts in `art-src/sprites/` are rendered on the GPU box;
2. the sheets go into `dodger/assets/sprites/`;
3. a headless self-test checks the game;
4. a release build comes out for Linux and Windows.

```bash
godot --path dodger                          # play: WASD/arrows, collect coins, dodge the red squares
godot --headless --path dodger -- --selftest # prints SELFTEST_OK
scripts/delegate.sh sprites all 96           # re-render its sprites on the GPU box
scripts/release.sh dodger 0.1.0              # Linux + Windows zips in releases/
```

Details: [docs/example-dodger.md](docs/example-dodger.md).

## Getting started

You need:
- a **laptop** (Linux or macOS) with git, git-lfs, ssh, rsync and Godot;
- a **GPU box**: Linux with an NVIDIA GPU (CUDA), reachable over SSH;
- a **GitHub repo**: your copy of this one, so both machines can see the pushed commits.

1. **Set up the GPU box** (once): install Blender and Godot, clone the repo with a read-only deploy key, and check CUDA. → [docs/setup-gpu-box.md](docs/setup-gpu-box.md)
2. **Set up the laptop** (once): SSH alias, push key, the same Godot version, and optionally `config.local.sh`. → [docs/setup-laptop.md](docs/setup-laptop.md)
3. **Smoke test:**
   ```bash
   git switch -c try-it
   scripts/delegate.sh gen_test_blend
   scripts/delegate.sh render renders/_gen/test.blend 1 1
   ```
   You should get `renders/test/frame_0001.png`: a cube, rendered on the GPU.

## Documentation

| Doc | Read it when |
|---|---|
| [setup-gpu-box.md](docs/setup-gpu-box.md) | Setting up a new GPU machine |
| [setup-laptop.md](docs/setup-laptop.md) | Setting up a new laptop or workstation |
| [how-it-works.md](docs/how-it-works.md) | You want to know exactly what happens during a job, or why it is built this way |
| [jobs.md](docs/jobs.md) | Every job and its arguments, and **how to add a new job** |
| [art-as-code.md](docs/art-as-code.md) | Writing model, texture and sprite scripts |
| [new-project.md](docs/new-project.md) | Starting a new game with this, or using it inside a **private** project |
| [troubleshooting.md](docs/troubleshooting.md) | A job failed: exit codes and known pitfalls |
| [gpu-box-care.md](docs/gpu-box-care.md) | Before touching the GPU box's NVIDIA driver or kernel (mostly: don't) |
| [claude-code.md](docs/claude-code.md) | Letting an AI coding agent (Claude Code) run the jobs for you, safely |
| [example-dodger.md](docs/example-dodger.md) | The example game |

## Repository layout

```
scripts/        the mechanism: delegate.sh, remote_run.sh, pull.sh, config.sh, one script per job, release.sh
art-src/        Python sources for models (models/), textures (textures/) and sprites (sprites/)
dodger/         the example Godot game
docs/           the documentation above
.claude/        an agent skill and permission settings for Claude Code (optional)
CLAUDE.md       instructions for an AI agent working in this repo (also a short reference)
renders/ build/ job results pulled from the GPU box (not in git)
releases/       versioned game builds (Git LFS)
```

## Ground rules

These keep the GPU box safe and predictable:

- **Work on feature branches.** `delegate.sh` refuses to run from `main` or with uncommitted changes, because the GPU box only sees what is pushed.
- **The GPU box's checkout is disposable.** Never edit files there; fix on the laptop, push, rerun. It refuses to run if its checkout has tracked changes.
- **One GPU job at a time**, with a timeout and a temperature limit (80 °C by default).
- **Leave the GPU box's NVIDIA driver and kernel alone.** See [gpu-box-care.md](docs/gpu-box-care.md).
- **No renders or builds in git**, apart from release zips. Large binaries go through Git LFS.

## Reference setup

This was built and tested with:

| | |
|---|---|
| GPU box | Debian 12, NVIDIA Tesla P4 (8 GB, Pascal, passive cooling), driver 550.163.01, shared with other services |
| Blender | 4.2 LTS on the GPU box (CUDA; the P4 has no OptiX) |
| Godot | 4.7.2-stable, the same version on both machines |
| Laptop | Linux, Intel graphics, no CUDA |

Other NVIDIA GPUs and versions should work. Change the paths in `scripts/config.sh` or `config.local.sh`.

## License

[MIT](LICENSE)
