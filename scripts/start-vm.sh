#!/bin/bash
# GPU-accelerated Omarchy VM: pinned QEMU build (virgl->ANGLE->Metal) with
# full networking. cocoa window for viewing; SSH+QMP for the agent.
set -euo pipefail

DIR="$HOME/omarchy-vm"
QEMU="$DIR/qemu-gpu2/bin/qemu-system-aarch64"
EDK2="$DIR/qemu-gpu2/share/qemu/edk2-aarch64-code.fd"

if [ -f "$DIR/qemu.pid" ] && kill -0 "$(cat "$DIR/qemu.pid")" 2>/dev/null; then
  echo "VM already running (pid $(cat "$DIR/qemu.pid"))"
  exit 0
fi

# cocoa display needs a GUI session -> no -daemonize; run via nohup.
exec "$QEMU" \
  -name "omarchy-arm" \
  -machine virt,accel=hvf,highmem=on \
  -cpu host \
  -smp 12 \
  -m 32768 \
  -drive if=pflash,format=raw,readonly=on,file="$EDK2" \
  -drive if=pflash,format=raw,file="$DIR/efi_vars_64m.fd" \
  -drive file="$DIR/omarchy.qcow2",if=virtio,format=qcow2,cache=writeback \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-gpu-gl-pci,xres=1920,yres=1200 \
  -device virtio-tablet-pci \
  -device virtio-keyboard-pci \
  -device qemu-xhci \
  -device usb-kbd \
  -device virtio-rng-pci \
  -display cocoa,gl=core \
  -qmp unix:"$DIR/qmp.sock",server=on,wait=off \
  -serial unix:"$DIR/serial.sock",server=on,wait=off \
  -pidfile "$DIR/qemu.pid"
