#!/usr/bin/env bash
# Settings shared by the laptop and server scripts. Sourced, never run.
# Override any of them per machine in config.local.sh at the repo root (gitignored), or in the environment.
# Expects ROOT (the repo root) to be set by the caller.

[[ -f "$ROOT/config.local.sh" ]] && source "$ROOT/config.local.sh"

# laptop side
: "${REMOTE:=gpubox}"                      # SSH host alias of the GPU server (defined in ~/.ssh/config)
: "${REMOTE_REPO:=work/gpu-render-box}"    # the server's checkout of this repo, relative to its home directory

# server side
: "${BLENDER:=/opt/blender/blender}"       # absolute paths: ~/bin is not on the PATH of non-interactive SSH
: "${GODOT:=/opt/godot/godot}"
: "${LOG_DIR:=$HOME/work/logs}"            # one log per job; logs older than 14 days are pruned
: "${GPU_LOCK:=/tmp/gpu.lock}"             # one GPU job at a time
: "${MAX_TEMP:=80}"                        # refuse to start a job above this GPU temperature (C)
: "${TIMEOUT:=2h}"                         # kill a job that runs longer than this
