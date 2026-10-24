#!/bin/bash
# Unsigned simulator build; never exports an IPA or uses signing credentials.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
if [ "$(uname -s)" != Darwin ]; then
  echo 'This script requires macOS with full Xcode. Use Codemagic or a GitHub macOS runner.' >&2
  exit 2
fi
for tool in xcodebuild xcodegen xcrun swift python3 ditto; do
  command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 2; }
done
OUTPUT="${VNANVIA_IOS_OUTPUT:-$ROOT/build/ios-cloud/$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$OUTPUT")"
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
              architecture=platform.machine(), xcode=version('xcodebuild','-version'),
              swift=version('swift','--version'), xcodegen=version('xcodegen','--version'),
              kit_manifest_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest() if manifest.exists() else None,
              signing='DISABLED; simulator only', status='STARTED')
(out/'build-info.json').write_text(json.dumps(record,indent=2)+'\n')
PY
swift test --package-path apple/VNAnviaCore --scratch-path "$OUTPUT/CoreBuild" 2>&1 | tee "$OUTPUT/logs/swift-core-tests.log"
(cd apple && xcodegen generate) 2>&1 | tee "$OUTPUT/logs/xcodegen.log"
xcodebuild -project apple/VNAnvia.xcodeproj -scheme VNAnvia \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$OUTPUT/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build 2>&1 | tee "$OUTPUT/logs/xcode-build.log"
xcrun simctl list devices available --json > "$OUTPUT/simulators.json"
SIMULATOR="$(python3 - "$OUTPUT/simulators.json" <<'PY'
import json, re, sys
data=json.load(open(sys.argv[1]))
choices=[]
for runtime, devices in data['devices'].items():
    match=re.search(r'\.iOS-(\d+)(?:-(\d+))?',runtime)
    if not match or int(match[1]) < 17:
        continue
    for device in devices:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            choices.append(((int(match[1]),int(match[2] or 0)),device['udid']))
if not choices:
    sys.exit('No available iPhone simulator with iOS17+. Install a simulator runtime in Xcode.')
print(sorted(choices,reverse=True)[0][1])
PY
)"
xcodebuild test -project apple/VNAnvia.xcodeproj -scheme VNAnvia \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIMULATOR" \
  -parallel-testing-enabled NO -derivedDataPath "$OUTPUT/DerivedData" \
  -resultBundlePath "$OUTPUT/native-tests.xcresult" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tee "$OUTPUT/logs/native-tests.log"
APP="$OUTPUT/DerivedData/Build/Products/Debug-iphonesimulator/VNAnviaApp.app"
test -d "$APP"
test -d "$APP/PlugIns/ActionExtension.appex"
test -d "$APP/PlugIns/SafariWebExtension.appex"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/VNAnvia-simulator.app.zip"
python3 - "$OUTPUT" <<'PY'
import hashlib,json,sys
from pathlib import Path
out=Path(sys.argv[1]); path=out/'build-info.json'
record=json.loads(path.read_text()); record['status']='SIMULATOR_BUILD_AND_TEST_PASSED'
artifact=out/'VNAnvia-simulator.app.zip'
record['artifact_sha256']=hashlib.sha256(artifact.read_bytes()).hexdigest()
record['physical_iphone_tested']=False
path.write_text(json.dumps(record,indent=2)+'\n')
(out/'SHA256SUMS.txt').write_text(record['artifact_sha256']+'  '+artifact.name+'\n')
PY
echo "Simulator output: $OUTPUT/VNAnvia-simulator.app.zip"
echo 'This simulator app cannot be installed on a physical iPhone. See README_IOS.md for signing.'
