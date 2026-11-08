# Caring for the GPU box: driver and kernel

**Default policy: don't update the NVIDIA driver or the kernel.** A working GPU box is worth more than the newest version. Update only for a real reason (below), deliberately, with a way back.

## Why this is fragile

A common setup, and the reference one, has the NVIDIA driver installed with NVIDIA's **runfile installer**, not from the distribution's packages, and **without DKMS**. Then:

- The kernel module is built for **one** kernel version. Boot any other kernel and no NVIDIA module loads: the GPU disappears and every job fails with exit 3 ("no CUDA device").
- A routine `apt upgrade` installs a new kernel, which is all it takes.
- Holding the driver in apt (`apt-mark hold`) doesn't help: there is no driver package to hold. The protection is to **hold the kernel packages** instead.
- Older GPUs drop out of new driver branches. Pascal cards (Tesla P4, GTX 10xx), for example, are supported up to the 580 branch only. Check NVIDIA's support list before choosing a driver.

If the box is shared with other services that use the GPU, a broken driver breaks those too.

## Protecting a working setup

Record the working state (keep it with your notes):

```bash
nvidia-smi                      # driver and CUDA version
uname -r                        # the kernel the driver was built for
apt-mark showhold
```

Hold the kernel packages, for Debian or Ubuntu (use the exact names `dpkg -l 'linux-image*' 'linux-headers*'` shows on your box):

```bash
sudo apt-mark hold linux-image-amd64 linux-headers-amd64 linux-image-$(uname -r) linux-headers-$(uname -r)
```

Check from time to time; a "dry run" shows what an upgrade would do:

```bash
apt-mark showhold
sudo apt-get -s dist-upgrade | grep -Ei 'linux-image|linux-headers|nvidia'   # any line here = a hold was lost
```

**Side effect:** kernel security fixes aren't applied while held. That's acceptable for a box on a home network; reconsider if it is ever exposed to the internet.

Also: **don't install the distribution's `nvidia-driver` package on top of a runfile install.** The two conflict.

## When you do need to update

Good reasons:
- a new Blender or Godot needs a newer CUDA;
- an important kernel security fix;
- a reinstall.

"It's old" isn't a reason. Have a **console or keyboard and screen** available in case the box doesn't boot cleanly.

1. **Note the state** (above). Keep a copy of the current driver's runfile. Don't remove the old kernel from `/boot`.
2. **Stop GPU work:** no job running (check the lock with `pgrep -x blender`), and stop other GPU services.
3. **Kernel:** unhold, install the new kernel **and its headers**, and **before rebooting** build the driver for it:
   ```bash
   sudo sh NVIDIA-Linux-x86_64-<version>.run --kernel-name=<new kernel release>
   ```
   Better still: install `dkms` first and pass `--dkms`, so future kernels rebuild the module automatically.
4. **Reboot and check:**
   - `nvidia-smi` and `cat /proc/driver/nvidia/version`;
   - from the laptop: `scripts/delegate.sh gen_test_blend` and `scripts/delegate.sh render renders/_gen/test.blend 1 1`;
   - `scripts/delegate.sh encode …` to check NVENC.
5. **Hold again,** for the new kernel packages, and update your notes.
6. **Rollback:** choose the previous kernel in the boot menu (it is still installed). If the driver is the problem, rerun the old runfile.

## Driver-only upgrades

Stay within the branches your GPU supports, and use the same install method as before (runfile, ideally with `--dkms`). Afterwards, check that Blender lists the GPU as a CUDA device, with the smoke test above, and that NVENC still works.

## Rules for scripts and AI agents

Never run any of these on the GPU box without the owner explicitly asking, in the moment:
- `apt upgrade` / `full-upgrade` / `dist-upgrade`, `apt-mark unhold`;
- the NVIDIA installer, `reboot`, `shutdown`.

If a job says "no CUDA device", diagnose (`nvidia-smi`, `uname -r`) and report; don't try to fix the driver. The `.claude/settings.json` in this repo blocks these commands for Claude Code.
