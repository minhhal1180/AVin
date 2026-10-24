"""Offline integrity/layout preflight; does not compile or certify iOS."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REQUIRED = (
    "apple/project.yml", "apple/VNAnviaCore/Package.swift",
    "apple/VNAnviaCore/Sources/VNAnviaCore/Resources/metadata.json",
    "dist/safari-extension/manifest.json", "dist/safari-extension/panel.html",
    "dist/safari-extension/panel.js", "dist/safari-extension/UNICODE-LICENSE.txt",
    "dist/safari-extension/popup.html", "dist/safari-extension/popup.js",
    "dist/safari-extension/background.js", "dist/safari-extension/content.js",
    "dist/safari-extension/ocr/model-manifest.json",
)

def verify(root):
    for name in REQUIRED:
        if not (root / name).is_file():
            raise ValueError("Missing build resource: " + name)
    for folder in ("assets", "icons", "ocr"):
        if not any((root / "dist/safari-extension" / folder).glob("*")):
            raise ValueError("Missing Safari resource directory: " + folder)
    manifest = root / "IOS-KIT-MANIFEST.json"
    if manifest.exists():
        data = json.loads(manifest.read_text("utf-8"))
        for name, expected in data["files"].items():
            path = root / name
            if "\\" in name or Path(name).is_absolute() or ".." in Path(name).parts or not path.resolve().is_relative_to(root.resolve()) or path.is_symlink():
                raise ValueError("Unsafe manifest path")
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise ValueError("Kit file changed/missing: " + name)
        print("KIT_INTEGRITY_OK: " + str(len(data["files"])) + " files; native compilation not verified")
    else:
        print("SOURCE_LAYOUT_OK: no packaged kit manifest; native compilation not verified")
    return True

if __name__ == "__main__":
    verify(ROOT)
