# dmgbuild settings for the Unstick disk image.
# scripts/build-app.sh passes -D app=<path to .app> -D background=<tiff> -D icon=<icns>.
import os.path

app = defines["app"]
app_name = os.path.basename(app)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = [app_name]
icon = defines["icon"]

background = defines["background"]
window_rect = ((200, 140), (660, 430))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 112
text_size = 13
label_pos = "bottom"
# Icon centers, measured from the window's top left; they match the arrow
# in make-dmg-background.swift.
icon_locations = {
    app_name: (165, 130),
    "Applications": (495, 130),
}
