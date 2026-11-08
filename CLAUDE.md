# gpu-render-box

Run Blender renders and Blender/Godot builds on a remote GPU box from a laptop without a GPU. The laptop is the control plane; heavy work goes through `scripts/delegate.sh` (see the `gpu-server-delegation` skill in `.claude/skills/`). Docs: `README.md`, `docs/`.

## Versions

Set on each machine in `scripts/config.sh` / `config.local.sh`. Godot must be the same version on the laptop and the GPU box. Don't change Blender, Godot or the GPU box's driver/kernel without asking.

## Layout

- `scripts/`: the mechanism (`delegate.sh`, `remote_run.sh`, `pull.sh`, `config.sh`) and one script per job.
- `art-src/`: model, texture and sprite sources as Blender Python scripts.
- `dodger/`: the example Godot game.
- `docs/`: setup, how it works, jobs, art as code, troubleshooting, GPU box care.
- `renders/`, `build/`: results pulled from the GPU box (gitignored).
- `releases/`: release zips (Git LFS).

## Rules

- Work on feature branches; never push to `main`; the human reviews and merges.
- Never edit files on the GPU box. Fix locally, push, rerun.
- GPU or heavy jobs go through `scripts/delegate.sh`. Never touch NVIDIA drivers, the kernel or apt holds, and never run `apt upgrade` on the GPU box (`docs/gpu-box-care.md`).
- Don't commit renders or builds; Git LFS for large binaries (`.gitattributes`).
- Look at every preview image a job returns before using the asset.
- Stop and summarize after two identical failures.

## Checks

- Dodger: `godot --headless --path dodger -- --selftest` prints `SELFTEST_OK`.
- Shell scripts: `bash -n scripts/*.sh`.
- End to end: `scripts/delegate.sh gen_test_blend`, then `scripts/delegate.sh render renders/_gen/test.blend 1 1`.
