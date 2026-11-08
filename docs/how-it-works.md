# How it works

## The idea

Two machines, one source of truth:

- **Laptop:** where you edit, commit and test. It is the only place that writes to branches.
- **GitHub:** the hand-over point. The GPU box only ever runs a commit that has been pushed, so every result can be traced to an exact commit.
- **GPU box:** a disposable checkout plus Blender, Godot and ffmpeg. It reads the repo (with a read-only key), runs one job, and leaves the results for the laptop to collect.

## One job, step by step

`scripts/delegate.sh [--detach] <job> [args…]` on the laptop:

1. **Checks.** Refuses to run when you are:
   - on detached HEAD;
   - on `main`;
   - holding uncommitted changes (`git status --porcelain`).

   Exit 2 in each case.
2. **Push.** `git push -u origin <branch>`.
3. **Sync the GPU box.** Over SSH, in `~/$REMOTE_REPO`:
   - refuse if tracked files there were changed by hand;
   - `git fetch origin <branch>` and `git checkout --detach FETCH_HEAD`.

   This happens before calling `remote_run.sh`, so a branch that adds or changes `remote_run.sh` itself runs its new version.
4. **Run.** `ssh gpubox "TIMEOUT=… ~/$REMOTE_REPO/scripts/remote_run.sh <branch> <job> <args>"`.
5. **Pull.** If the exit code is 0, `pull.sh` rsyncs `renders/` and `build/` from the GPU box and opens the newest image or video. On failure nothing is pulled, and you get the log path.

`scripts/remote_run.sh` on the GPU box:

1. **Stage 1, update.** Refuses if the checkout is dirty (exit 3), fetches and checks out the commit, then **re-runs itself** from that commit, so the job always runs the scripts of the commit you pushed.
2. **Log header.** Writes the job, branch, full commit hash, Blender and Godot versions, GPU temperature and memory, and the processes using the GPU into `~/work/logs/<job>-<short sha>-<YYYYmmdd-HHMMSS>.log`. Logs older than 14 days are deleted.
3. **Heat check.** If the GPU is above `MAX_TEMP` (80 °C), it writes `EXIT=4` and stops.
4. **Lock and timeout.** `flock -n /tmp/gpu.lock`. If another job holds it, exit 75 at once (no queueing). Then `timeout $TIMEOUT scripts/<job>.sh …`.
5. **Footer.** `EXIT=<code>` is the log's last line, and the script exits with that code.

### Detached jobs

With `--detach`, `remote_run.sh` starts the same job inside a `tmux` session on the GPU box and returns at once with `LOG=<path>`. `delegate.sh` then checks the log every 15 seconds and shows its last line, until an `EXIT=` line appears. It then prints the last 40 lines and pulls the results as usual. Use it for anything that may take more than a minute or two: the job survives a dropped connection or a closed laptop. If the laptop does lose track, `scripts/pull.sh` fetches the results later.

## Where things live

| What | Where | In git? |
|---|---|---|
| Scripts, art sources, game code | repo | yes |
| Job results | `renders/`, `build/` on both machines | no (ignored) |
| Imported assets used by a game | `<project>/assets/…`, copied from `build/` on the laptop | yes (large ones via LFS) |
| Release zips | `releases/` on the laptop | yes, via LFS (the GPU box skips them) |
| Logs | `~/work/logs` on the GPU box | no |
| Per-machine settings | `config.local.sh` on each machine | no (ignored) |

Results are never written into tracked folders on the GPU box, so its checkout stays clean and the next `git checkout` never collides with them.

## Settings

`scripts/config.sh` holds every setting with a default. Both machines load it, after `config.local.sh` if that file exists. A value in `config.local.sh` beats everything. For a one-off change of a setting it doesn't set, use an environment variable, e.g. `TIMEOUT=4h scripts/delegate.sh …`.

| Setting | Default | Used on | Meaning |
|---|---|---|---|
| `REMOTE` | `gpubox` | laptop | SSH alias of the GPU box |
| `REMOTE_REPO` | `work/gpu-render-box` | laptop | the GPU box's checkout, relative to its home |
| `TIMEOUT` | `2h` | both | maximum job time (the laptop passes its value along) |
| `BLENDER` | `/opt/blender/blender` | GPU box | Blender binary (absolute path) |
| `GODOT` | `/opt/godot/godot` | GPU box | Godot binary (absolute path) |
| `LOG_DIR` | `~/work/logs` | GPU box | job logs |
| `GPU_LOCK` | `/tmp/gpu.lock` | GPU box | the one-job-at-a-time lock |
| `MAX_TEMP` | `80` | GPU box | refuse to start above this temperature (°C) |

Other environment variables:
- `NO_OPEN=1` (laptop) stops `pull.sh` opening the result;
- `BLENDER_THREADS` (GPU box, default 8) sets the CPU threads for render and sprite jobs;
- `FPS` (GPU box, default 30) sets the frame rate for `encode`.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done; results were pulled |
| 2 | Usage error, missing file, or the laptop's checks failed (main, dirty, detached) |
| 3 | GPU box checkout has hand-made changes, **or** Cycles found no CUDA device |
| 4 | GPU too hot to start |
| 75 | Another GPU job is running (the lock is held) |
| 124 | The job hit `TIMEOUT` |
| other | The job's own error: read the log |

## Why it is built this way

- **Push, then run the exact commit.** You never wonder which version of a script made a result: the log names the commit.
- **Disposable checkout.** If the GPU box ever differs from GitHub, that's a bug, so the scripts refuse instead of "fixing" it.
- **One job at a time, no queue.** A second render would only fight the first for GPU memory, so it fails fast with 75 and you decide.
- **No silent CPU fallback** for renders. A "GPU render" that quietly took an hour on the CPU is worse than an error. Model previews can opt in with `--cpu`.
- **Absolute binary paths.** Non-interactive SSH has a minimal PATH, so `blender` alone wouldn't be found.
- **ffmpeg always with `-nostdin`.** Inside tmux, ffmpeg otherwise waits for keyboard input and gets stopped.
