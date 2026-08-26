#!/bin/bash
# Build QEMU (pinned to 2026-01-13 master) with startergo's virgl/ANGLE patches
# + slirp networking. Install prefix: ~/omarchy-vm/qemu-gpu2
set -euo pipefail

SHA=d03c3e522eb0696dcfc9c2cf643431eaaf51ca0f
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$HOME/omarchy-vm/build-qemu"
PREFIX="$HOME/omarchy-vm/qemu-gpu2"

mkdir -p "$WORK" && cd "$WORK"

echo "== download qemu @ $SHA"
[ -f qemu.tar.gz ] || curl -sL -o qemu.tar.gz "https://gitlab.com/qemu-project/qemu/-/archive/$SHA/qemu-$SHA.tar.gz"
[ -d "qemu-$SHA" ] || tar xzf qemu.tar.gz
cd "qemu-$SHA"

echo "== apply patches"
patch -p1 --batch --forward -r /dev/null < "$REPO/patches/vendor/qemu-texture-borrowing.patch" || true
patch -p1 --batch --forward -r /dev/null < "$REPO/patches/vendor/gpu-spike-resolution-fix.patch" || true

echo "== configure"
export PKG_CONFIG_PATH="/opt/homebrew/opt/virglrenderer/lib/pkgconfig:/opt/homebrew/opt/libepoxy/lib/pkgconfig:/opt/homebrew/opt/angle/lib/pkgconfig:/opt/homebrew/lib/pkgconfig"
export CFLAGS="-I/opt/homebrew/opt/angle/include ${CFLAGS:-}"
export OBJCFLAGS="-I/opt/homebrew/opt/angle/include ${OBJCFLAGS:-}"
export CPPFLAGS="-I/opt/homebrew/opt/angle/include ${CPPFLAGS:-}"
export LDFLAGS="-L/opt/homebrew/opt/angle/lib ${LDFLAGS:-}"
rm -rf build && mkdir build && cd build
../configure \
  --prefix="$PREFIX" \
  --enable-virglrenderer \
  --enable-opengl \
  --enable-cocoa \
  --enable-slirp \
  --disable-gtk \
  --disable-guest-agent \
  --disable-guest-agent-msi \
  --target-list=aarch64-softmmu

echo "== build"
make -j"$(sysctl -n hw.ncpu)"

echo "== install"
make install

echo "== codesign (adhoc + hypervisor entitlement)"
cat > /tmp/hvf-ent.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.hypervisor</key><true/>
</dict></plist>
EOF
for f in "$PREFIX"/bin/*; do codesign --force --sign - --entitlements /tmp/hvf-ent.plist "$f"; done

echo "== copy venus runtime (KosmicKrisp ICD) from previous build"
mkdir -p "$PREFIX/share/vulkan/icd.d"
cp "$HOME/omarchy-vm/qemu-gpu/share/vulkan/icd.d/libkosmickrisp_icd.json" "$PREFIX/share/vulkan/icd.d/" 2>/dev/null || true
cp "$HOME/omarchy-vm/qemu-gpu/lib/libvulkan_kosmickrisp.dylib" "$PREFIX/lib/" 2>/dev/null || true
cp "$HOME/omarchy-vm/qemu-gpu/lib/"libvulkan*.dylib "$PREFIX/lib/" 2>/dev/null || true

echo "== verify"
"$PREFIX/bin/qemu-system-aarch64" --version | head -1
"$PREFIX/bin/qemu-system-aarch64" -machine virt -netdev help 2>&1 | grep -x user && echo "SLIRP OK"
"$PREFIX/bin/qemu-system-aarch64" -machine virt -device virtio-gpu-gl-pci,help 2>&1 | grep -E "venus|blob" && echo "GPU DEVICES OK"
echo "ALL_DONE"
