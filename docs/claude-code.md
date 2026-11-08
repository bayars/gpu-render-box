# Using it with an AI coding agent (Claude Code)

The mechanism works well with an agent: the agent edits code and art scripts on the laptop, runs `scripts/delegate.sh`, looks at the preview images that come back, and iterates. It never needs a shell on the GPU box beyond reading logs. This repo includes what makes that safe.

## What's included

| File | Purpose |
|---|---|
| `.claude/skills/gpu-server-delegation/SKILL.md` | A **skill**: when to delegate, the one command, the job table, the rules and how to handle failures. Claude Code loads it when a task needs the GPU |
| `.claude/settings.json` | **Permissions.** It allows `delegate.sh`, `pull.sh` and read-only `ssh gpubox` diagnostics without asking each time. It **denies** `sudo`, `apt`, `reboot`, the NVIDIA installer, `rm -rf` and `pkill -f` on the GPU box, plus pushing to `main` and force-pushing |
| `CLAUDE.md` | Repo instructions: what the repo is, versions, rules and where things are |

If your SSH alias isn't `gpubox`, update it in `.claude/settings.json` too. The allow and deny rules match on the command text.

## Rules worth keeping in your own CLAUDE.md

These came from real mistakes:
- **Feature branches only;** never push to `main`. The human merges.
- **Never edit files on the GPU box.** Fix on the laptop, push, rerun.
- **Never touch the NVIDIA driver, the kernel or apt holds** on the GPU box, and never run `apt upgrade` there.
- **Don't commit renders or builds.** Large binaries go through Git LFS.
- **Stop and summarize after two identical failures,** instead of looping.
- **Never `pkill -f` over SSH** (it kills the session); use `pkill -x`.
- **Don't stop other services that share the GPU;** use `--cpu` for previews instead.
- **Look at every preview image** before using an asset. A model that exports fine can still look wrong.
- **Test headless first.** Each game should have a `--selftest` that prints `SELFTEST_OK`, run after every change.
- **Parse-check scripts** (`godot --headless --check-only -s <script>`) after editing GDScript. A parse error can make a headless test hang silently instead of failing.

## Screenshots of the game on the laptop's screen

An agent that opens a game window on the laptop while you're typing can receive your keystrokes. To capture screenshots safely, create a gitignored `override.cfg` in the Godot project with:

```ini
[display]

window/size/no_focus=true
```

The window then never takes keyboard focus. A virtual display (xvfb) works for 2D, but renders 3D on the CPU, far too slowly.
