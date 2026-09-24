# Bigscreen Beyond on Arch Linux — Setup Guide

Instructions for setting up the Bigscreen Beyond (BSB) for VR on Arch Linux,
distilled from the working setup done in June 2026 (later removed in favor of
VR on Windows). Follow the upstream wiki alongside this — details change:
<https://vronlinux.org/docs/hardware/bigscreen-beyond/>

**Hardware context this was tested on:** RTX 3090 (NVIDIA-only — iGPU disabled
in BIOS), MSI MEG Z690I UNIFY, ext4 root, systemd-boot with UKIs, Hyprland
(Wayland), SteamVR 2.0 base stations.

> **Why it was removed:** stability issues are inherent to the BSB-on-Linux
> stack (headset standby/keepalive loops, SteamVR Linux compositor bugs,
> firmware updates require Windows anyway). Judge whether the state of the
> ecosystem has improved before re-attempting.

---

## 0. Safety net first (do this before anything)

Custom kernel + NVIDIA + bootloader changes can leave the system unbootable.

```sh
paru -S timeshift timeshift-autosnap   # autosnap hooks every pacman/paru transaction
sudo timeshift --create --comments "pre-bsb-nvidia baseline" --tags O
```

- On ext4, Timeshift uses RSYNC mode (config: `/etc/timeshift/timeshift.json`,
  device UUID + scheduling off + retention ~5).
- Also back up boot-critical files before editing:
  `/etc/mkinitcpio.conf`, `/etc/mkinitcpio.d/*.preset`, `/etc/kernel/cmdline`.
- The stock `linux` kernel + its UKI is the guaranteed fallback boot entry —
  **never remove it**.

## 1. Patched kernel: `linux-bsb` (AUR)

The BSB display needs kernel patches (DSC timing fixes; NVIDIA needs driver
580+ **open** kernel modules). The `linux-bsb` AUR package bundles them.

```sh
MAKEFLAGS="--jobs=$(nproc)" paru -S linux-bsb linux-bsb-headers
```

### NVIDIA: must switch to the DKMS driver

Precompiled `nvidia-open` only ships modules for the stock `linux` kernel —
the `linux-bsb` initramfs build will fail with `module not found: 'nvidia'`.
Fix by switching to DKMS, which builds for every installed kernel with headers:

```sh
paru -S dkms nvidia-open-dkms    # accept replacing nvidia-open
dkms status                      # expect nvidia built for BOTH kernels
```

### UKI boot entry (systemd-boot)

This machine boots via Unified Kernel Images auto-discovered from
`/boot/EFI/Linux/` (no `loader/entries/*.conf` — ignore the wiki's loader-entry
method). Edit `/etc/mkinitcpio.d/linux-bsb.preset` to mirror `linux.preset`:

- comment out `default_image="/boot/initramfs-linux-bsb.img"`
- set `default_uki="/boot/EFI/Linux/arch-linux-bsb.efi"` (ESP is mounted at
  `/boot`, not `/efi` — fix the path the package ships)
- add `default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"`

```sh
sudo mkinitcpio -P linux-bsb          # must finish with NO nvidia errors
sudo rm -f /boot/initramfs-linux-bsb.img   # stray plain initramfs, unused
bootctl list                          # both arch-linux.efi + arch-linux-bsb.efi
```

### Test-boot safely, then set default

```sh
sudo bootctl set-oneshot arch-linux-bsb.efi   # one boot only; auto-reverts if it fails
reboot
# after reboot:
uname -r        # expect *-bsb
nvidia-smi      # GPU listed, no errors
# only after it works:
sudo bootctl set-default arch-linux-bsb.efi
# revert anytime: sudo bootctl set-default arch-linux.efi
```

### Update discipline (AUR kernel footguns)

- **Always update with `paru -Syu`** (the `uu` alias handles this) — plain
  `pacman -Syu` skips the AUR kernel and causes partial-upgrade skew.
- Reboot after kernel updates (DKMS + UKI hooks handle rebuilds automatically).
- `linux-bsb` recompiles from source on every update (slow) and can lag behind
  Arch's kernel; version mismatch between `linux` and `linux-bsb` is normal.
- Hyprland warning: repo Hyprland updates break hyprpm plugins (hy3 etc.) —
  plugin ABI is version-locked. After a Hyprland bump, `hyprpm update` from a
  TTY if login crashes; hy3 often lags Hyprland releases by days.

## 2. GPU routing: NVIDIA-only

Wiki recommendation for desktops with mixed-brand iGPU+dGPU: **disable the
iGPU in BIOS** so NVIDIA drives everything (avoids Vulkan device-selection and
DRM-lease issues).

- MSI Click BIOS 5: `Del` at boot → `F7` Advanced Mode → Settings → Advanced →
  Integrated Graphics Configuration → Integrated Graphics = **Disabled** → F10.
- BSB DisplayPort must be plugged into the **GPU**, not the motherboard.
- Verify Vulkan ICDs are clean: only `nvidia_icd.json` under
  `/usr/share/vulkan/icd.d/`.
- Side effect seen here: NVIDIA-only made login-time DRM init slower/noisier,
  exposing wallpaper-daemon races (see dotfiles `theme-switch.sh` retry loop +
  single-owner `awww-daemon` — those fixes are kept in the dotfiles).

## 3. udev rules

Write `/etc/udev/rules.d/99-bigscreen-beyond.rules` (script from the wiki;
grants hidraw access to VID `35bd` PIDs `0101/4004/1001/0202/0282` — headset,
firmware mode, error mode, Bigeye, Bigeye DFU):

```sh
export udev_group=$(groups | tr ' ' '\n' | grep -E "$(whoami)"'|wheel|sudo|adm|admin|video|plugdev' | head -n 1)
# ... (tee the rules file per the wiki, then:)
sudo udevadm control --reload && sudo udevadm trigger
```

Valve devices (watchman receivers, trackers) are already covered by Steam's
`60-steam-vr.rules` from `steam-devices`.

## 4. Bigscreen Beyond Utility (Steam + Proton)

1. Install Steam, log in. Install **Proton Experimental**
   (`steam://install/1493710` — store search hides Tools; use the direct URL).
2. Settings → Compatibility → enable Steam Play for all titles.
3. Install **Bigscreen Beyond Utility** (`steam://install/2467050`); force
   Proton Experimental in its Properties → Compatibility.
4. Launch options:
   `PROTON_ENABLE_HIDRAW=0x35BD/0x0101,0x35BD/0x4004,0x35BD/0x1001,0x35BD/0x0202,0x35BD/0x0282 %command%`
5. **Proton caveat:** `PROTON_ENABLE_HIDRAW` regressed in stable Proton 10
   (ValveSoftware/Proton#8672). Experimental worked here; GE-Proton 10-3+ is
   the known-good fallback if HID passthrough fails.
6. The Utility demands a **Windows** SteamVR folder ("SteamVR path"). Download
   one with steamcmd (`paru -S steamcmd`):

   ```sh
   mkdir ~/steamvr_win && steamcmd +@ShutdownOnFailedCommand 1 \
     +@sSteamCmdForcePlatformType windows \
     +force_install_dir $(realpath ~/steamvr_win) \
     +login anonymous +app_update 250820 validate +quit
   ```

   In the Utility set the path as a **Windows path**: `Z:\home\<user>\steamvr_win`
   — then **restart the Utility** (it only validates on restart).
7. "Invalid SteamVR folder - Some settings are unavailable!" afterwards is
   expected/ignorable. Refresh-rate switching (75↔90 Hz) and eyetracking
   firmware updates **only work in Windows**; set the mode there first.

## 5. Runtime, base stations, tracking

Runtime choice: SteamVR (Linux) is the pragmatic primary — best game compat
(Skyrim VR mods etc.); Monado/Envision is smoother for native OpenXR but
OpenVR-translation (xrizer) was immature. SteamVR install is needed either way
(Monado borrows its lighthouse driver via `STEAMVR_LH_ENABLE=true`).

```sh
# steam://install/250820 (Linux SteamVR), then if it nags:
sudo setcap CAP_SYS_NICE=eip ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher
```

Base stations (SteamVR 2.0):

- They are **not paired** — the headset tracks their IR sweeps optically.
  "Not detected" ⇒ the headset isn't seeing sweeps.
- Mount **above head height**, opposite corners, angled down 30–45°, clear
  line of sight; desk-level placement produces `No base stations seen` /
  `SwSyncDetect Restart` loops in `~/.local/share/Steam/logs/vrserver.txt`.
- 2.0 LED: white **or green** = ready; **dim green = standby**.
- Each station needs a unique channel (check `sobChannel` in
  `~/.local/share/Steam/config/lighthouse/lighthousedb.json`).
- Room setup: SteamVR-Monitor ≡ → Settings → Developer (enable Advanced) →
  Room and Tracking → **Quick Calibrate**, headset on floor at play-space
  center. Only works once tracking works.
- **Do NOT update base-station firmware from Linux** — the BLE update path
  crashes/soft-bricks (issues #589/#653/#294). Do it on Windows via USB.
- SteamVR's BLE power management is unreliable on Linux; if stations sit in
  standby at launch, keep them on constant power or manage externally.

## 6. Known issues hit during this setup

| Symptom | Cause / fix |
|---|---|
| Headset detected 1s → black → standby loop, `Triggered keepalive (failed)` | BSB display-keepalive bug (SteamVR-for-Linux #610 family). In our case it correlated with `enableLinuxVulkanAsync: true` — leaving that flag **off** + restart fixed it. Multi-monitor (#866) and X11-vs-Wayland are other levers. |
| Split / cross-eyed stereo in headset | Known BSB stereo-mismatch (#866). Documented fix is `enableLinuxVulkanAsync: true` in the `steamvr` block of `~/.local/share/Steam/config/steamvr.vrsettings` (and `resources/settings/default.vrsettings`, which SteamVR updates overwrite) — but that flag caused the standby loop above on this machine. Unresolved trade-off at time of removal. |
| `Invalid input type click (/user/head/proximity)` in logs | Benign — appears on Windows too; prox sensor handled on-device. |
| `Not enough contiguous samples for a bootstrap pose` | Marginal base-station coverage — fix placement. |
| linux-bsb initramfs `module not found: nvidia` | Precompiled driver has no modules for the AUR kernel — use `nvidia-open-dkms` + headers (section 1). |

## 7. Removal (what undoing this looks like)

Done Aug 2026; order matters — be booted on the stock kernel first
(`bootctl set-default arch-linux.efi`, reboot):

1. `sudo timeshift --create --comments "pre-bsb-removal" --tags O`
2. `sudo pacman -Rns steam steamcmd`; delete `~/.local/share/Steam`,
   `~/.steam`, `~/steamvr_win`
3. `sudo rm /etc/udev/rules.d/99-bigscreen-beyond.rules && sudo udevadm control --reload`
4. `sudo pacman -Rns linux-bsb linux-bsb-headers`; remove leftover
   `/boot/EFI/Linux/arch-linux-bsb.efi` and `/etc/mkinitcpio.d/linux-bsb.preset*`
5. `sudo pacman -S nvidia-open` (replaces the DKMS variant); `sudo pacman -Rns dkms`
6. Reboot; verify `uname -r`, `nvidia-smi`, `bootctl list`
