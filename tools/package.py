"""Build the sh_pauseMenu installation package. Uses Python's standard library."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
RESOURCE = "sh_pauseMenu"
DOCUMENTS = ("LICENSE", "README.md", "CHANGELOG.md", "TESTING.md", "THIRD_PARTY.md")


def package(output):
    manifest = (ROOT / "fxmanifest.lua").read_text(encoding="utf-8")
    version = re.search(r"^version\s+'([^']+)'", manifest, re.MULTILINE).group(1)
    files = [ROOT / name for name in ("fxmanifest.lua", "config.lua", *DOCUMENTS)]
    for directory in ("client", "server", "html"):
        files.extend(path for path in (ROOT / directory).rglob("*") if path.is_file())
    files.sort(key=lambda path: path.relative_to(ROOT).as_posix())
    checksums = "".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT).as_posix()}\n"
        for path in files
    )
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"{RESOURCE}-{version}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in files:
            bundle.write(path, f"{RESOURCE}/{path.relative_to(ROOT).as_posix()}")
        bundle.writestr(f"{RESOURCE}/SHA256SUMS.txt", checksums)
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None, "Package integrity check failed"
        for line in checksums.splitlines():
            expected, relative = line.split("  ", 1)
            assert hashlib.sha256(bundle.read(f"{RESOURCE}/{relative}")).hexdigest() == expected
        assert all(
            name.startswith(f"{RESOURCE}/")
            and not any(part in {".git", "node_modules", "__pycache__", "tests", "tools"}
                        for part in Path(name).parts)
            for name in bundle.namelist()
        ), "Unexpected development files in installation package"
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(".zip.sha256").write_text(
        f"{digest}  {archive.name}\n", encoding="utf-8", newline="\n"
    )
    print(json.dumps({"version": version, "archive": str(archive), "files": len(files) + 1,
                      "sha256": digest}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist")
    package(parser.parse_args().output.resolve())
