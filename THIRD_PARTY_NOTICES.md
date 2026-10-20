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

The 大肥鱼 application icon is an original AI-generated fan-inspired image made
with the built-in image_gen tool for this project. The prompt and textual research
reference are in `ui_assets/dafeiyu.prompt.md`; no third-party character illustration
was downloaded or copied. It is used by the EXE, window and system tray.
