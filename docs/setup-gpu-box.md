# Setting up the GPU box

Do this once per GPU machine. Every command runs **on the GPU box** unless it says otherwise. Nothing here touches the NVIDIA driver or the kernel: the driver must already work (`nvidia-smi` prints your GPU). If it doesn't, sort that out first, and read [gpu-box-care.md](gpu-box-care.md) before you do.

## 0. What you need

- Linux (tested on Debian 12) with an NVIDIA GPU that CUDA supports, and a working driver.
- SSH access from the laptop with a key.
- Disk: about 0.5 GB for Blender, 1.5 GB for Godot with export templates, plus room for renders.
- These tools: `git git-lfs tmux rsync ffmpeg flock timeout python3`. Check with:
  ```bash
  for t in git git-lfs tmux rsync ffmpeg flock timeout python3 nvidia-smi; do command -v $t >/dev/null && echo "ok  $t" || echo "MISSING $t"; done
  ```
  Install missing ones with your package manager, but install only those packages. Don't run a full system upgrade on a GPU box (see [gpu-box-care.md](gpu-box-care.md)).

## 1. Check the GPU

```bash
nvidia-smi -L                     # lists the GPU
nvidia-smi --query-gpu=name,driver_version,memory.total,temperature.gpu --format=csv
```

Write down the driver version, the CUDA version (`nvidia-smi` header) and `uname -r`. You'll need them if something breaks later.

## 2. Install Blender (in /opt, by absolute path)

Pick a Blender LTS whose CUDA support covers your GPU. Older cards such as Pascal still work with 4.2 LTS.

```bash
cd ~ && mkdir -p work/dl && cd work/dl
V=4.2.23   # the version you chose
curl -LO https://download.blender.org/release/Blender${V%.*}/blender-$V-linux-x64.tar.xz
curl -LO https://download.blender.org/release/Blender${V%.*}/blender-$V.sha256
grep linux-x64 blender-$V.sha256 | sha256sum -c -
sudo mkdir -p /opt/blender && sudo chown "$USER" /opt/blender
tar -xf blender-$V-linux-x64.tar.xz -C /opt/blender --strip-components=1
/opt/blender/blender --version
```

Scripts call `/opt/blender/blender` by its full path, because `~/bin` and similar aren't on the PATH of a non-interactive SSH command. A different location goes in `config.local.sh` (step 6).

## 3. Install Godot and its export templates

Use **exactly** the version the laptop uses. A project opened in a newer Godot gets rewritten.

```bash
V=4.7.2
cd ~/work/dl
curl -LO https://github.com/godotengine/godot/releases/download/$V-stable/Godot_v$V-stable_linux.x86_64.zip
curl -LO https://github.com/godotengine/godot/releases/download/$V-stable/Godot_v$V-stable_export_templates.tpz
curl -LO https://github.com/godotengine/godot/releases/download/$V-stable/SHA512-SUMS.txt
grep -E "linux.x86_64.zip|export_templates.tpz" SHA512-SUMS.txt | sha512sum -c -
sudo mkdir -p /opt/godot && sudo chown "$USER" /opt/godot
unzip -o Godot_v$V-stable_linux.x86_64.zip -d /opt/godot && mv /opt/godot/Godot_v$V-stable_linux.x86_64 /opt/godot/godot
mkdir -p ~/.local/share/godot/export_templates/$V.stable
unzip -o Godot_v$V-stable_export_templates.tpz -d /tmp/tpl && mv /tmp/tpl/templates/* ~/.local/share/godot/export_templates/$V.stable/
/opt/godot/godot --headless --version
```

The export templates are what `build_linux` and `build_windows` need. You can delete `~/work/dl` afterwards.

## 4. A read-only deploy key and the checkout

The GPU box only **reads** the repo, so give it a key that can't push.

```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/gpu_render_box_deploy -C "gpu box read-only"
cat ~/.ssh/gpu_render_box_deploy.pub
```

On GitHub: **repo → Settings → Deploy keys → Add deploy key**. Paste the key and leave **"Allow write access" unticked**. Then add an SSH alias so git uses that key:

```bash
cat >> ~/.ssh/config <<'EOF'
Host github-render-box
  HostName github.com
  User git
  IdentityFile ~/.ssh/gpu_render_box_deploy
  IdentitiesOnly yes
EOF
mkdir -p ~/work/logs
git clone github-render-box:<you>/<your-repo>.git ~/work/gpu-render-box
cd ~/work/gpu-render-box && git lfs install --local && git config lfs.fetchexclude 'releases/*'
```

- **The checkout is disposable.** Nobody edits files in it. Each job checks out the exact pushed commit, and a job refuses to start if tracked files were changed by hand.
- **Release zips stay on the laptop.** `lfs.fetchexclude 'releases/*'` stops the GPU box downloading them.
- **A different checkout path** goes in `REMOTE_REPO` (step 6 and the laptop's `config.local.sh`).

## 5. Check that Blender sees CUDA

From the **laptop**, once [setup-laptop.md](setup-laptop.md) is done:

```bash
git switch -c try-it
scripts/delegate.sh gen_test_blend
scripts/delegate.sh render renders/_gen/test.blend 1 1
```

The log should show `DEVICES [...('<your GPU>', 'CUDA')...]` and `RENDER device=<your GPU>`, and the laptop receives `renders/test/frame_0001.png`.

Exit code 3 from the render means Cycles saw no CUDA device. The job deliberately never falls back to the CPU silently; see [troubleshooting.md](troubleshooting.md).

## 6. Optional: per-machine settings

Paths, the lock file, the temperature limit and the timeout default to the values in `scripts/config.sh`. To change them on one machine only, create `config.local.sh` in the checkout's root (git ignores it, and an untracked file doesn't count as "changed by hand"):

```bash
# ~/work/gpu-render-box/config.local.sh   (on the GPU box)
BLENDER=/opt/blender-4.2/blender
MAX_TEMP=75
TIMEOUT=4h
```

## 7. A heat check (recommended for passively cooled cards)

Data-centre cards such as the Tesla P4 have no fan. They rely on the case airflow. Before trusting long jobs, watch one:

```bash
# on the GPU box, in a second terminal while a long render runs
nvidia-smi --query-gpu=temperature.gpu,power.draw,clocks.sm --format=csv -l 5
```

It should level off well under 80 °C. If it climbs past that, improve the airflow before running long jobs. Don't raise `MAX_TEMP`.

## 8. If the GPU is shared

When other software also uses the GPU (an LLM server, for example), its memory may be taken when a job starts:
- `nvidia-smi` in each job's log shows who uses how much;
- `models.sh --cpu` renders the model previews on the CPU when the GPU memory is full;
- keep scenes, textures and sample counts modest.

Don't stop or unload the other services from these scripts.
