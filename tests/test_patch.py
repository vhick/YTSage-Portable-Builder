"""Minimal offline patch tests using exact known upstream source anchors."""
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory

spec = importlib.util.spec_from_file_location('patch', Path(__file__).parents[1] / 'portable-kit' / 'patch_upstream.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

with TemporaryDirectory() as tmp:
    root=Path(tmp)
    a=root/'ytsage'/'utils'/'ytsage_constants.py'
    b=root/'ytsage'/'core'/'ytsage_ffmpeg.py'
    a.parent.mkdir(parents=True)
    b.parent.mkdir(parents=True)
    a.write_text('if OS_NAME == "Windows":\n    APP_DIR: Path = Path(os.environ.get("LOCALAPPDATA", USER_HOME_DIR / "AppData" / "Local")) / "YTSage"\n', encoding='utf-8')
    b.write_text('''def get_ffmpeg_install_path():
    if OS_NAME == "Windows":
        ffmpeg_base = Path(os.getenv("LOCALAPPDATA")) / "ffmpeg"  # type: ignore

def install_ffmpeg_windows(progress_callback=None) -> bool:
    """Install FFmpeg on Windows using essentials build with 7z method primarily, with zip as fallback."""
    subprocess.run(["setx", "PATH", new_path])
''',encoding='utf-8')
    mod.apply(root)
    patched=a.read_text()+b.read_text()
    assert 'YTSAGE_PORTABLE_MODE' in patched
    assert 'return check_ffmpeg_installed()' in patched
    compile(a.read_text(),str(a),'exec')
    compile(b.read_text(),str(b),'exec')
    try:
        mod.apply(root)
        raise AssertionError('Patch erroneously allowed duplicate application')
    except RuntimeError as exc:
        assert 'Upstream has changed' in str(exc)
print('Offline safety patch tests passed')
