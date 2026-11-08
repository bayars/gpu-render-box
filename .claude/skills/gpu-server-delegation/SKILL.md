---
name: gpu-server-delegation
description: Use when a step needs a GPU or heavy compute (Blender renders, model/texture/sprite builds, glTF export, Godot exports, ffmpeg encoding). Runs the job on the remote GPU box with scripts/delegate.sh and brings the results back. Keep light work (code, scripts, git, quick Godot tests) on the laptop.
---

# GPU box delegation

## Setup

- The GPU box is reached by the SSH alias in `scripts/config.sh` (`REMOTE`, default `gpubox`). Its checkout of this repo is `~/$REMOTE_REPO` (default `~/work/gpu-render-box`), a **disposable** clone with a read-only key. Logs: `~/work/logs`.
- Blender and Godot run there by absolute path (`BLENDER`, `GODOT` in `scripts/config.sh`). The laptop's Godot must be the same version.
- The laptop may have no GPU and an older Blender: never render on the laptop, and never save `.blend` files with the laptop's Blender.
- The GPU may be shared with other services. Never stop or unload them; use `--cpu` for model previews when GPU memory is full.

## Local vs. GPU box

- **Local:** editing code, scripts and docs; git; headless Godot tests; looking at results.
- **GPU box:** Cycles renders and bakes, model, texture and sprite builds, glTF export, Godot exports, ffmpeg encodes, and anything over ~30 s or needing CUDA.

## Procedure (one command)

From a **clean, committed feature branch**:

```
scripts/delegate.sh [--detach] <job> [args]
```

It pushes the branch, moves the GPU box's checkout to that exact commit, runs the job under a lock, a timeout and a temperature check, then pulls `renders/` and `build/` back.

| Job | Command | Output (laptop, not in git) |
|---|---|---|
| render | `scripts/delegate.sh render art-src/x.blend <start> <end> [--samples N] [--res-percent N]` | `renders/x/frame_####.png` |
| export_gltf | `scripts/delegate.sh export_gltf art-src/x.blend [out.glb]` | `build/gltf/x.glb` |
| models | `scripts/delegate.sh models [--cpu] [name…\|all]` | `build/models/<name>.glb` + `<name>_preview.png` (look at it) |
| textures | `scripts/delegate.sh textures [name…]` | `build/textures/<name>_{albedo,normal,rough}.png` + sheets |
| sprites | `scripts/delegate.sh sprites [name\|all] [size]` | `build/sprites/<name>_sheet.png` |
| build_linux / build_windows | `scripts/delegate.sh build_linux <project_dir>` | `build/<name>-<platform>.zip` |
| encode | `scripts/delegate.sh encode renders/x/frame_%04d.png renders/x.mp4` | NVENC, libx264 fallback |
| gen_test_blend | `scripts/delegate.sh gen_test_blend` | `renders/_gen/test.blend` (smoke test) |

- Paths in job arguments are relative to the repo root.
- Use `--detach` for anything that may take more than a minute or two.
- Don't wrap it in your own `ssh`, `tmux`, `rsync` or `flock`; the scripts already do that. Hand-run `ssh` commands are for read-only diagnosis only (logs, `nvidia-smi`).

**Report back:** the job, branch and commit, the output path (open the image and look at it), and any warnings from the log (path printed as `LOG=`).

**Releases:** `scripts/release.sh <project_dir> <version>` → `releases/` (Git LFS; the GPU box never downloads them).

**Assets** (`.glb`, textures, sprites) are copied into the game project on the laptop and committed there. The GPU box never pushes.

## Rules

- **The checkout is disposable.** Never hand-edit files on the GPU box. Fix locally, push, rerun.
- **One GPU job at a time.** Exit 75 means another job is running: wait. Don't delete the lock.
- **Cycles uses CUDA only.** Exit 3 = no CUDA device: stop and report the device list from the log; never fall back to the CPU silently.
- **Exit 4 = too hot.** Stop and tell the user; don't raise `MAX_TEMP`.
- **Never touch the driver or the system.** No NVIDIA drivers, kernel, apt holds or system settings on the GPU box: no `apt upgrade`, no `apt-mark unhold`, no reboot. See `docs/gpu-box-care.md`.
- **Delete nothing on the GPU box** outside its checkout and the logs folder. Ask before deleting results.
- **No renders or builds in git.** Large binaries go through Git LFS; check `git lfs ls-files` before adding assets.
- **Keep Blender, Godot and driver versions as configured.** Ask the user if a task needs others.
- **Never use `pkill -f` on the GPU box.** It kills your own SSH session; use `pkill -x <name>`.

## When something fails

1. Read the last 40–100 lines of the log (`ssh <REMOTE> "tail -n 80 <LOG path>"`), not just the exit code.
2. Classify it with `docs/troubleshooting.md`:
   - 2: usage error or missing file;
   - 3: no CUDA device, or a dirty checkout when it comes from the sync step;
   - 4: too hot;
   - 75: busy;
   - 124: timeout;
   - anything else: the job's own error.

   Also consider out of GPU memory and out of RAM.
3. **Script bug:** fix it locally, commit, rerun. **Environment problem:** report the exact error and stop; don't improvise system changes.
4. **After two failures with the same error,** stop and summarize instead of looping.
