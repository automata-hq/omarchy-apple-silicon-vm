-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Modos disponibles:  hyprctl monitors all
--
-- VM en UTM/QEMU con virtio-gpu. Dos ajustes respecto a los valores de Omarchy:
--
--  1. Escala 1 (Omarchy asume pantallas retina 2x; en la VM deja todo gigante).
--  2. Resolucion fija 1920x1200 en vez de "preferred", que da 1280x800.
--
-- IMPORTANTE: cambiar el modo EN CALIENTE (hyprctl / recarga de config) rompe
-- el renderizado bajo virgl: el escritorio se queda en blanco hasta reiniciar.
-- Aplicado desde el arranque funciona bien. Si tocas esto, reinicia la VM.
--
-- Para que la resolucion siga al tamano de la ventana de UTM:
--   hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.env("GDK_SCALE", "1")
hl.monitor({ output = "Virtual-1", mode = "preferred", position = "0x0", scale = 1 })
