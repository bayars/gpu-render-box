# Setting up the laptop

The laptop is where you work: code, git, Godot, quick tests. It needs no GPU.

## 1. Tools

- `git`, `git-lfs`, `ssh`, `rsync`
- **Godot**, the same version as on the GPU box (see `setup-gpu-box.md`, step 3), on your PATH as `godot`
- Optional: VS Code with the `code` command. `pull.sh` opens the newest result image or video in it; set `NO_OPEN=1` to stop that.

You don't need Blender on the laptop. If you do have one installed, **don't open and save `.blend` files with an older Blender** than the GPU box's: it can lose data the newer version wrote. Anything that writes `.blend` files runs on the GPU box.

## 2. SSH alias for the GPU box

The scripts reach the GPU box by an SSH alias, `gpubox` by default.

```bash
# ~/.ssh/config on the laptop
Host gpubox
  HostName <gpu box address>
  User <your user on the gpu box>
  IdentityFile ~/.ssh/<your key for the gpu box>
  ServerAliveInterval 30
```

Test it: `ssh gpubox nvidia-smi -L`. Another alias name goes in `REMOTE` (step 4).

## 3. A key that can push

`delegate.sh` pushes your branch before every job. Any key with write access to the repo works. A dedicated key for just this repo keeps it separate from your other GitHub access:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/gpu_render_box_push -C "laptop push"
# GitHub: repo → Settings → Deploy keys → Add, TICK "Allow write access"
git config core.sshCommand "ssh -i ~/.ssh/gpu_render_box_push -o IdentitiesOnly=yes"   # in this repo only
```

## 4. Optional: `config.local.sh`

Only needed if your names differ from the defaults in `scripts/config.sh`. Create it in the repo root (git ignores it):

```bash
# config.local.sh   (on the laptop)
REMOTE=my-gpu-box                 # SSH alias
REMOTE_REPO=work/gpu-render-box   # the checkout on the GPU box, relative to its home
TIMEOUT=4h                        # passed to the GPU box for each job
```

`config.local.sh.example` lists every setting.

## 5. First run

```bash
git switch -c try-it               # never run jobs from main
scripts/delegate.sh gen_test_blend
scripts/delegate.sh render renders/_gen/test.blend 1 1
```

The `== …` lines show each stage: push, sync, run, exit code, pull. The result lands in `renders/test/`.

## Daily use

```bash
# edit art-src/models/chair.py
git commit -am "chair: thinner legs"
scripts/delegate.sh models chair         # -> build/models/chair.glb + chair_preview.png
cp build/models/chair.glb mygame/assets/models/
git add mygame/assets/models/chair.glb && git commit -m "chair model"
```

Jobs need a **clean, committed** tree. Commit first, even something you might throw away; you can squash later.
