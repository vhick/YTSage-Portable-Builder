"""Checks the portable package layout before GitHub Actions uploads an artifact."""
from __future__ import annotations
import pathlib
import sys
import zipfile

path = pathlib.Path(sys.argv[1])
assert path.exists(), path
with zipfile.ZipFile(path) as z:
    names = set(z.namelist())
    wanted = [
        'YTSagePortable/YTSagePortable.exe',
        'YTSagePortable/App/YTSage/YTSage.exe',
        'YTSagePortable/App/YTSage/ffmpeg.exe',
        'YTSagePortable/App/YTSage/ffprobe.exe',
        'YTSagePortable/App/AppInfo/appinfo.ini',
    ]
    missing = [x for x in wanted if x not in names]
    if missing: raise AssertionError('Missing files: ' + ', '.join(missing))
print(f'ZIP package structure verified: {path.name}, {len(names)} entries')
