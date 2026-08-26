# Omarchy on Apple Silicon — GPU-accelerated QEMU VM

Run the [Omarchy](https://omarchy.org) desktop (Arch Linux ARM + Hyprland) on
Apple Silicon with **GPU-accelerated compositing**, a **120 Hz virtual
display**, and full scriptability — no bare-metal install, no UTM required.

The compositor renders on the host GPU through a virgl → ANGLE/MoltenVK-style
Metal bridge (`Renderer: virgl (Apple M3 Ultra)` in the guest), while the whole
VM stays a contained, scriptable QEMU process.

## What you get

- Omarchy 4 (quattro) aarch64, HVF-accelerated (native CPU speed, no emulation)
- Hyprland composited on the Apple GPU (virgl → Metal)
- 120 Hz EDID mode advertised to the guest (patched into QEMU)
- SSH into the guest, QMP control socket, serial console — agent/automation ready
- Native cocoa window for humans

## Requirements

- macOS on Apple Silicon (tested on M3 Ultra / macOS Tahoe)
- Homebrew
- The Omarchy ARM image: either build it with
  [ggalancs/omarchy-arm-utm](https://github.com/ggalancs/omarchy-arm-utm) or
  download the prebuilt `omarchy-arm-utm-v2.zip` from the
  [Internet Archive](https://archive.org/details/omarchy-arm-utm)
  (the `.utm` bundle contains the `qcow2` + EFI vars this repo reuses)
- Third-party Homebrew taps by `startergo` (virglrenderer/ANGLE/libepoxy builds
  for macOS):

```sh
brew tap startergo/virglrenderer && brew trust startergo/virglrenderer
brew tap startergo/libepoxy     && brew trust startergo/libepoxy
brew tap startergo/angle        && brew trust startergo/angle
brew install startergo/virglrenderer/virglrenderer startergo/libepoxy/libepoxy startergo/angle/angle
brew install meson ninja pkg-config glib pixman dtc gnutls jpeg-turbo libpng \
             libssh libusb lzo ncurses nettle sdl2 snappy spice-protocol gmp \
             zstd gettext libslirp capstone
```

Note: `startergo/libepoxy` currently ships `libepoxy.0.dylib` with a broken
code signature — macOS will kill any binary linking it. Fix once after install:

```sh
codesign --force --sign - /opt/homebrew/Cellar/libepoxy/*/lib/libepoxy.0.dylib
```

## Build QEMU (virgl + slirp + 120 Hz EDID)

Builds QEMU pinned to the 2026-01-13 master commit the patches were written
for (upstream master moves; the patches rot against it), applies the vendored
virgl/texture-borrowing patches plus this repo's 120 Hz EDID patch, and
installs into `~/omarchy-vm/qemu-gpu2` (~20–40 min):

```sh
./build/build-qemu-gpu.sh
```

## Set up the disk

```sh
mkdir -p ~/omarchy-vm && cd ~/omarchy-vm
# from the omarchy-arm-utm bundle:
cp "Omarchy ARM v5.utm/Data/"*.qcow2 omarchy.qcow2
cp "Omarchy ARM v5.utm/Data/efi_vars.fd" efi_vars_64m.fd
truncate -s 64M efi_vars_64m.fd   # QEMU virt wants 64 MiB pflash vars
```

### Guest-side config (one time, over SSH or serial)

Apply the files in `guest-config/` to the guest:

| repo file | guest destination | purpose |
|---|---|---|
| `guest-config/etc/environment.d/90-vm-graphics.conf` | `/etc/environment.d/` | virgl renderer selection, no LIBGL software forcing |
| `guest-config/uwsm/env.d/20-vm-graphics` | `~/.config/uwsm/env.d/` | same for the uwsm session |
| `guest-config/uwsm/env.d/30-qt-software` | `~/.config/uwsm/env.d/` | Qt/quickshell bar via software raster (virgl dmabuf import for GL clients is still broken — see caveats) |
| `guest-config/hypr/monitors.lua` | `~/.config/hypr/` | `preferred` mode → picks up 120 Hz |

Also fix the boot entry once so the VM auto-boots (from the UEFI shell, with a
USB keyboard attached — `start-vm.sh` provides one):

```
bcfg boot add 0 fs0:\EFI\BOOT\BOOTAA64.EFI "Omarchy"
reset
```

Enable sshd in the guest for the agent/SSH channel:

```sh
sudo systemctl enable --now sshd
```

## Run

```sh
./scripts/start-vm.sh        # boots; native cocoa window opens
./scripts/stop-vm.sh         # graceful ACPI shutdown
```

- SSH: `ssh -p 2222 omarchy@127.0.0.1` (default password `omarchy` — change it)
- QMP socket: `~/omarchy-vm/qmp.sock` (see `scripts/qmp.py`, `scripts/type_keys.py`)
- Serial console: `~/omarchy-vm/serial.sock` (see `scripts/serial-cmd.exp`)
- Screenshots for automation: in-guest `grim` over SSH.
  **Note:** QMP `screendump` is black while the GL renderer is active.

## Caveats / known limitations

- **GPU clients vs the compositor**: the Hyprland compositor itself is
  GPU-accelerated, but GL-native *client* buffers don't reliably composite
  over virgl on macOS hosts yet. Qt apps are forced to software raster
  (`QT_QUICK_BACKEND=software`) — this combination is stable and fast in
  practice; llvmpipe handles app content while the GPU does compositing.
- Venus (Vulkan-over-virtio) currently fails on macOS: virglrenderer's proxy
  renderer needs `SOCK_SEQPACKET`, which XNU lacks. Patch welcome.
- VNC is disabled in the GPU build (VNC + GL context conflict); use the cocoa
  window or in-guest capture.
- Resolution/refresh come from QEMU's EDID; the 120 Hz patch defaults the
  preferred mode to the requested `xres`/`yres` at 120 Hz.
- Software cursor (`WLR_NO_HARDWARE_CURSORS=1`) is on by design.

## Credit / prior art

- [basecamp/omarchy](https://github.com/basecamp/omarchy) — the distro
- [ggalancs/omarchy-arm-utm](https://github.com/ggalancs/omarchy-arm-utm) —
  the ARM image + UTM packaging this boots from
- [startergo/homebrew-qemu-virgl-kosmickrisp](https://github.com/startergo/homebrew-qemu-virgl-kosmickrisp) —
  macOS virgl/ANGLE/KosmicKrisp QEMU packaging; two patches vendored here
- [@akihikodaki](https://gist.github.com/akihikodaki/87df4149e7ca87f18dc56807ec5a1bc5) —
  the original virgl-on-macOS work the patches derive from
- [UTM's Neptune writeup](https://blog.getutm.app/2026/introducing-neptune-direct3d-virtualization-for-qemu/) —
  Venus + MoltenVK on macOS state of the art
