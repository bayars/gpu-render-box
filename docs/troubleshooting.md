# Troubleshooting

**First, read the log, not just the exit code.** `delegate.sh` prints its path as `LOG=…`:

```bash
ssh gpubox "tail -n 80 ~/work/logs/<job>-<sha>-<time>.log"
ssh gpubox "ls -t ~/work/logs | head"          # the latest logs
```

The header shows the commit, the tool versions, and the GPU's temperature and memory at the start of the job.

## By exit code

| Code | What happened | What to do |
|---|---|---|
| 2 | Usage error or missing file, **or** the laptop's checks failed | Read the message: "use a feature branch", "uncommitted changes", "not found: … (path is relative to the repo root)", "is an LFS pointer" (run `git lfs push` from the laptop, or check `.gitattributes`) |
| 3 (at the sync step) | The GPU box's checkout has hand-made changes | Someone edited files on the GPU box. Look (`ssh gpubox "cd ~/work/gpu-render-box && git status && git diff"`), save anything worth keeping **to the laptop**, then `git checkout -- .` there. Never fix code on the GPU box |
| 3 (in a render) | Cycles found no CUDA device | The log line `DEVICES [...]` lists what Blender saw. Check `nvidia-smi` on the GPU box. If it fails, the driver isn't loaded: compare `uname -r` with the kernel the driver was built for (see [gpu-box-care.md](gpu-box-care.md)). Don't install or upgrade anything in a hurry |
| 4 | The GPU is hotter than `MAX_TEMP` | Wait for it to cool and check the airflow. Don't raise the limit to get past it |
| 75 | Another job holds the GPU lock | Wait for it (`ssh gpubox "ls ~/work/logs -t \| head -3"`). **Don't delete `/tmp/gpu.lock`**: the lock is held by a running process, not by the file existing |
| 124 | The job hit `TIMEOUT` | Lower samples or resolution, split the frame range, or raise `TIMEOUT` for that run (`TIMEOUT=4h scripts/delegate.sh …`), and use `--detach` |
| other | The job's own error (Blender, Godot, ffmpeg, Python) | The traceback is in the log. Fix on the laptop, commit, rerun |

## Known pitfalls

**Out of GPU memory (Cycles "out of memory", or CUDA errors partway through).** Another process may be holding GPU memory; the log header lists GPU processes. Lower the samples, resolution, texture size or tile size. For model previews, `models.sh --cpu` renders on the CPU instead. Don't stop the other services from a job.

**Out of system memory (the job is just "Killed").** The GPU box may have little RAM and no swap. Keep scenes small, and lower `BLENDER_THREADS`.

**`pkill -f` over SSH kills your own session.** `pkill -f blender` also matches the SSH command line that contains "blender". Use `pkill -x blender` or `pgrep -x`.

**"command not found: blender/godot" over SSH.** Non-interactive SSH doesn't load your profile, so `~/bin` isn't on the PATH. The scripts use the absolute paths in `scripts/config.sh`; put a different location there or in `config.local.sh`.

**A detached job sits "Stopped" in tmux.** A program read from the terminal: usually ffmpeg without `-nostdin`. Every ffmpeg call in the scripts has `-nostdin`; keep it on any new one. To recover a stuck job, find it with `pgrep -a ffmpeg` and kill only that process (by PID).

**Cycles lists your GPU twice (CUDA and OPTIX).** Older cards such as Pascal show an OptiX entry they can't use. The scripts enable only the CUDA entry; copy `enable_cuda_only()` from `scripts/blender_render.py` into any new Blender job.

**Benchmarks finish suspiciously fast.** Adaptive sampling ends trivial scenes early. Turn it off when measuring heat or speed.

**The Godot export is missing new assets.** `build.sh` runs `--import` before exporting. If an asset still doesn't appear, check that the file was committed (and pushed to LFS) and that the export preset's filters include it.

**Windows build won't start.** It can only be checked structurally on Linux. Test it on a Windows machine.

**A job needs a different Blender or Godot version.** Install it side by side (for example `/opt/blender-4.5/`) and set `BLENDER`/`GODOT` for that project in `config.local.sh`. Keep the laptop's Godot version equal to the GPU box's.

## Two identical failures in a row

Stop and look at the cause instead of retrying. Rerunning the same job against the same problem only uses GPU time and fills the logs.
