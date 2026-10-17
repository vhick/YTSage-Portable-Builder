"""Apply fail-closed, narrowly scoped portability changes to a YTSage checkout.

Only source checked out from the official upstream Git repository should be patched.
If the upstream source changes, refuse to build until the patch is reviewed.
"""
from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(path: Path, original: str, replacement: str) -> None:
    contents = path.read_text(encoding='utf-8')
    count = contents.count(original)
    if count != 1:
        raise RuntimeError(f"Expected exactly one patch anchor in {path}, found {count}. "
                           "Upstream has changed; review the code before rebuilding.")
    path.write_text(contents.replace(original, replacement, 1), encoding='utf-8')
    print(f"Patched: {path}")


def apply(root: Path) -> None:
    constants = root / 'ytsage' / 'utils' / 'ytsage_constants.py'
    ffmpeg = root / 'ytsage' / 'core' / 'ytsage_ffmpeg.py'
    if not constants.is_file() or not ffmpeg.is_file():
        raise FileNotFoundError('Missing expected YTSage source files; check upstream ref')

    replace_once(
        constants,
        '    APP_DIR: Path = Path(os.environ.get("LOCALAPPDATA", USER_HOME_DIR / "AppData" / "Local")) / "YTSage"',
        '    _portable_data_root = (os.environ.get("YTSAGE_DATA_DIR")\n'
        '                           if os.environ.get("YTSAGE_PORTABLE_MODE") == "1" else None)\n'
        '    if os.environ.get("YTSAGE_PORTABLE_MODE") == "1" and not _portable_data_root:\n'
        '        raise RuntimeError("Portable mode requires YTSAGE_DATA_DIR")\n'
        '    APP_DIR: Path = (Path(_portable_data_root) if _portable_data_root else\n'
        '                     Path(os.environ.get("LOCALAPPDATA", USER_HOME_DIR / "AppData" / "Local")) / "YTSage")'
    )

    replace_once(
        ffmpeg,
        '        ffmpeg_base = Path(os.getenv("LOCALAPPDATA")) / "ffmpeg"  # type: ignore',
        '        # Keep all FFmpeg lookups inside the portable app when enabled.\n'
        '        ffmpeg_base = (Path(os.environ["YTSAGE_FFMPEG_DIR"])\n'
        '                       if os.environ.get("YTSAGE_PORTABLE_MODE") == "1"\n'
        '                       else Path(os.getenv("LOCALAPPDATA")) / "ffmpeg")  # type: ignore'
    )

    replace_once(
        ffmpeg,
        'def install_ffmpeg_windows(progress_callback=None) -> bool:\n'
        '    """Install FFmpeg on Windows using essentials build with 7z method primarily, with zip as fallback."""',
        'def install_ffmpeg_windows(progress_callback=None) -> bool:\n'
        '    """Install FFmpeg on Windows; never modify host PATH in portable mode."""\n'
        '    if os.environ.get("YTSAGE_PORTABLE_MODE") == "1":\n'
        '        # Bundled ffmpeg is mandatory for our portable edition.\n'
        '        # Explicitly block upstream installer (which calls setx PATH).\n'
        '        logger.info("Portable build uses bundled FFmpeg; system installation disabled")\n'
        '        if progress_callback:\n'
        '            progress_callback("Portable edition uses bundled FFmpeg")\n'
        '        return check_ffmpeg_installed()'
    )
    # Fail the build if a future upstream revision moves the PATH-changing code.
    source = ffmpeg.read_text(encoding='utf-8')
    if '["setx", "PATH", new_path]' not in source:
        raise RuntimeError('Upstream FFmpeg PATH update changed: manual review required')
    print('Portable changes applied; permanent PATH editing is blocked in portable mode.')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('source', type=Path, help='Directory containing upstream YTSage checkout')
    apply(ap.parse_args().source.resolve())
