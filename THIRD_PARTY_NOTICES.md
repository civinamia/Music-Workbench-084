# Runtime and asset notices

This folder contains a portable Python/PyQt5 application built with PyInstaller.
The original license texts shipped with the installed runtime packages are copied
to `docs/licenses/`. The `_internal` directory contains dynamically loaded runtime
libraries and must remain with the executable.

- Python: Python Software Foundation license.
- PyQt5 and PyQt5-sip: Riverbank Computing, GPL v3 (or a separate commercial license).
- Qt 5: The Qt Company and contributors; consult the Qt package license texts.
- NumPy, Pillow, Requests, urllib3, certifi, charset-normalizer, idna,
  cryptography, cffi and setuptools: their respective license texts in `docs/licenses/`.
- PyInstaller: GPL with the bootloader exception; see https://pyinstaller.org/en/stable/license.html.

The 大肥鱼 application icon is an original illustration drawn for this project.
It is shipped as `ui_assets/dafeiyu.png` with a seven-size `dafeiyu.ico`, and is
used by the EXE resource, the window title bar and the system tray. No
third-party illustration is copied or redistributed.
