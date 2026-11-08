# Using it for a new project

There are two ways to use gpu-render-box for your own game: inside this repo, or copied into a separate (possibly private) repo.

## Option A: work inside a copy of this repo

Best for experiments and public projects.

1. **Copy the repo.** Fork it, or make a new repo from its files.
2. **Add your game** next to the example: `mygame/` holding a Godot project (`project.godot`). Keep the folder at the top level; `build.sh` takes a plain folder name.
3. **Add export presets.** In the Godot editor (Project → Export), add presets named exactly **`Linux`** and **`Windows Desktop`**, and commit `mygame/export_presets.cfg`.
4. **Put art sources** in `art-src/models/`, `art-src/textures/pbr.py` and `art-src/sprites/` (see [art-as-code.md](art-as-code.md)).
5. **Build:** `scripts/delegate.sh build_linux mygame`, or `scripts/release.sh mygame 0.1.0` for both platforms.

You can delete `dodger/` and the example art once you no longer need them.

## Option B: a private game repo that uses the mechanism

Best when the game itself should stay private, while this repo stays public with only the mechanism.

**What to copy into the game repo:**
- `scripts/` (all of it)
- `art-src/models/common.py`, `art-src/textures/pbr.py`, `art-src/sprites/common.py` (only what you use)
- `.gitignore`, `.gitattributes`, `config.local.sh.example`
- optionally `.claude/` and `CLAUDE.md` (see [claude-code.md](claude-code.md))

**What changes in the game repo:**
- **The GPU box gets a separate checkout** of the game repo, for example `~/work/mygame`, cloned with its **own read-only deploy key**. GitHub deploy keys are one per repo, so you need another key and SSH alias (see [setup-gpu-box.md](setup-gpu-box.md), step 4).
- **The laptop points at that checkout** in its `config.local.sh`: `REMOTE_REPO=work/mygame`.
- **One GPU lock for both:** if both checkouts live on the same GPU box, they share `/tmp/gpu.lock`, so their jobs never overlap.

### Keeping the two in step

The game repo's copy of `scripts/` will drift. When you improve the mechanism in one place, carry the change over by hand:

```bash
# from the game repo: what changed in the mechanism?
diff -ru ../gpu-render-box/scripts scripts
# bring one improvement over (or the other way), file by file
cp ../gpu-render-box/scripts/remote_run.sh scripts/
```

**Before copying anything from the private repo into the public one,** check it for what shouldn't be public:
- game names, characters or story in comments and example commands;
- server addresses, user names, key file names, repo names;
- job lists that name private assets (for example a hard-coded list of model names).

`grep -rniE "<your game's words>|<server ip>|<username>" scripts docs` is a quick check. Prefer generic code, such as "build every script in a folder", over lists of names.

### Alternative: a git subtree

To pull updates instead of copying files, add this repo as a subtree in the game repo:

```bash
git subtree add  --prefix=tools/render-box https://github.com/<you>/gpu-render-box.git main --squash
git subtree pull --prefix=tools/render-box https://github.com/<you>/gpu-render-box.git main --squash
```

The scripts find the repo root from their own location (`scripts/..`), so with a subtree you'd either run them from that prefix or adjust `ROOT`. Copying is simpler, and is what the reference setup does.

## Checklist for a new game

- [ ] Godot project folder at the top level, with `Linux` and `Windows Desktop` export presets committed
- [ ] The same Godot version on the laptop and the GPU box
- [ ] Generated folders (`renders/`, `build/`, `.godot/`) in `.gitignore`
- [ ] Large binaries (`.blend`, `.glb`, big textures, release zips) in `.gitattributes` for LFS. GitHub's free LFS quota is small (1 GB of storage, 1 GB of downloads a month), so commit only the assets you use
- [ ] A headless self-test (`godot --headless --path mygame -- --selftest`), like Dodger's, so every build can be checked without a screen
- [ ] Release zips checked by running them: the Linux build on Linux; the Windows build on Windows before sharing it
