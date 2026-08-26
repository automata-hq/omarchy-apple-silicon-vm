-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Available modes:  hyprctl monitors all
--
-- QEMU/UTM VM with virtio-gpu. Two changes vs stock Omarchy:
--
--  1. Scale 1 (Omarchy assumes 2x retina displays; in the VM everything looks huge).
--  2. "preferred" mode picks up the 120 Hz EDID mode from the patched QEMU.
--
-- IMPORTANT: changing the mode LIVE (hyprctl / config reload) breaks rendering
-- under virgl: the desktop goes blank until reboot. Applied from boot it works
-- fine. If you touch this, reboot the VM.
hl.env("GDK_SCALE", "1")
hl.monitor({ output = "Virtual-1", mode = "preferred", position = "0x0", scale = 1 })
