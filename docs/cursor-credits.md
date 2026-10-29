# Cursor enlargement credits

The native rendering engine is [hypr-dynamic-cursors](https://github.com/VirtCode/hypr-dynamic-cursors), by Virt and contributors, pinned to `5a224284872208b5324759d535d65061043725de` for Hyprland `efb50993780079460b0cbed1363e2166a2de1d9f` (0.56.2). Its MIT license is copied alongside the installed library by the build script.

Upstream explicitly credits [KDE Plasma's shake detector](https://invent.kde.org/plasma/kwin/-/blob/master/src/plugins/shakecursor/shakedetector.cpp). KWin's [shake cursor effect](https://invent.kde.org/plasma/kwin/-/blob/master/src/plugins/shakecursor/shakecursor.cpp) supplies the design reference: enlarge in the rendering path, retain the pointer hotspot, hold briefly, then shrink back. This fork uses the MIT Hyprland implementation rather than embedding KWin's GPL source.

Local integration disables tilt/stretch, uses a 3× base and 4.5× limit, keeps a two-second timeout, respects reduced motion and Game Mode, and resets the magnification before disabling rendering hooks. A separate compositor session was used for the initial ABI/load test. Live captures verify rendered cursor growth and restoration, including client cursor images.
