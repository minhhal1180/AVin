#!/bin/bash
# Build for physical iPhone; signing is performed later by Sideloadly or Xcode.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
if [ "$(uname -s)" != Darwin ]; then
  echo 'This script requires macOS with full Xcode. Use Codemagic or a GitHub macOS runner.' >&2
  exit 2
fi
for tool in xcodebuild xcodegen swift python3 ditto; do
  command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 2; }
done
OUTPUT="${VNANVIA_DEVICE_OUTPUT:-$ROOT/build/ios-device/$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$OUTPUT")"
if [ -e "$OUTPUT" ]; then
  echo 'Output already exists; choose a fresh VNANVIA_DEVICE_OUTPUT directory.' >&2
  exit 2
fi
mkdir -p "$OUTPUT/logs"
python3 apple/ci/verify-kit.py | tee "$OUTPUT/logs/preflight.log"
python3 - "$OUTPUT" <<'PY'
import hashlib, json, platform, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path
root, out = Path.cwd(), Path(sys.argv[1])
def version(*cmd):
    return subprocess.check_output(cmd, text=True).strip()
manifest = root / 'IOS-KIT-MANIFEST.json'
record = dict(at=datetime.now(timezone.utc).isoformat(), platform=platform.platform(),
              architecture=platform.machine(), xcode=version('xcodebuild', '-version'),
              swift=version('swift', '--version'), xcodegen=version('xcodegen', '--version'),
              source_commit=version('git', 'rev-parse', 'HEAD') if (root / '.git').exists() else None,
              kit_manifest_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest() if manifest.exists() else None,
              configuration='Release', sdk='iphoneos', destination='generic/platform=iOS',
              signing='DISABLED; local signing still required', status='STARTED',
              physical_iphone_tested=False, signed_ipa=False)
(out / 'build-info.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
PY
swift test --package-path apple/VNAnviaCore --scratch-path "$OUTPUT/CoreBuild" 2>&1 | tee "$OUTPUT/logs/swift-core-tests.log"
(cd apple && xcodegen generate) 2>&1 | tee "$OUTPUT/logs/xcodegen.log"
xcodebuild -project apple/VNAnvia.xcodeproj -scheme VNAnvia \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$OUTPUT/DerivedData" \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY='' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  build 2>&1 | tee "$OUTPUT/logs/xcode-build.log"
APP="$OUTPUT/DerivedData/Build/Products/Release-iphoneos/VNAnviaApp.app"
test -d "$APP/PlugIns/ActionExtension.appex"
test -d "$APP/PlugIns/SafariWebExtension.appex"
mkdir "$OUTPUT/Payload"
ditto --norsrc --noextattr "$APP" "$OUTPUT/Payload/VNAnviaApp.app"
ditto -c -k --norsrc --noextattr --keepParent "$OUTPUT/Payload" "$OUTPUT/VNAnvia-device-unsigned.ipa"
python3 apple/ci/verify-device-ipa.py "$OUTPUT/VNAnvia-device-unsigned.ipa" --project-spec apple/project.yml | tee "$OUTPUT/ipa-validation.json"
python3 - "$OUTPUT" <<'PY'
import hashlib, json, sys
from pathlib import Path
out = Path(sys.argv[1]); path = out / 'build-info.json'
record = json.loads(path.read_text('utf-8'))
artifact = out / 'VNAnvia-device-unsigned.ipa'
record.update(status='DEVICE_UNSIGNED_BUILD_PASSED',
              artifact_sha256=hashlib.sha256(artifact.read_bytes()).hexdigest(),
              artifact_bytes=artifact.stat().st_size,
              ipa_validation=json.loads((out / 'ipa-validation.json').read_text('utf-8')))
path.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
(out / 'SHA256SUMS.txt').write_text(record['artifact_sha256'] + '  ' + artifact.name + '\n', encoding='utf-8')
PY
echo "iPhone output: $OUTPUT/VNAnvia-device-unsigned.ipa"
echo 'Not signed or installed. Use Sideloadly on Windows; see docs/engineering/IOS_FREE_INSTALL.md.'
