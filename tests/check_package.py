"""Verify final ZIP integrity, packaged bytes, Linux line endings and modes."""
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
with zipfile.ZipFile(ROOT / "dist/550w-moss-grub.zip") as bundle:
    assert bundle.testzip() is None
    for info in bundle.infolist():
        rel = info.filename.removeprefix("550w-moss-grub/")
        assert info.filename.startswith("550w-moss-grub/") and ".." not in Path(rel).parts
        assert not rel.startswith((".tools/", "assets/"))
        content = bundle.read(info)
        assert content == (ROOT / rel).read_bytes(), rel
        if rel.endswith(".sh"):
            assert b"\r\n" not in content, (rel, "CRLF line endings")
            assert (info.external_attr >> 16) & 0o111, (rel, "executable mode")
print("ZIP integrity, packaged bytes, LF scripts and executable modes verified")
