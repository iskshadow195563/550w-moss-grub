"""Package only distributable theme files, never temporary tools or source image."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
DIST.mkdir(exist_ok=True)
files = [ROOT / p for p in ("README.md", "install.sh", "uninstall.sh", "check.sh")]
for folder in ("theme", "licenses", "scripts"):
    files.extend(path for path in (ROOT / folder).rglob("*") if path.is_file() and "__pycache__" not in path.parts)
files.extend(ROOT / "docs" / name for name in ("validation.md", "image-edit-prompt.txt", "preview-1080p-ubuntu.png", "preview-1080p-windows.png"))
archive = DIST / "550w-moss-grub.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
    for path in sorted(set(files)):
        assert path.is_file(), path
        rel = path.relative_to(ROOT).as_posix()
        info = zipfile.ZipInfo("550w-moss-grub/" + rel)
        info.create_system = 3
        info.external_attr = (0o100755 if path.suffix == ".sh" else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        bundle.writestr(info, path.read_bytes(), compresslevel=9)
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(DIST / "550w-moss-grub.zip.sha256").write_text(f"{digest}  550w-moss-grub.zip\n", encoding="ascii")
print(f"{archive}\n{archive.stat().st_size / 1024 / 1024:.2f} MiB\nSHA256 {digest}")
