"""Offline device-IPA checks before local signing; does not certify a signature or installation."""

import argparse
import hashlib
import json
import plistlib
import re
import stat
import struct
import sys
import zipfile
from pathlib import Path

APP = "Payload/VNAnviaApp.app"
BUNDLES = (
    (APP, "vn.vnanvia.demo", None),
    (APP + "/PlugIns/ActionExtension.appex", "vn.vnanvia.demo.action", "com.apple.ui-services"),
    (
        APP + "/PlugIns/SafariWebExtension.appex",
        "vn.vnanvia.demo.safari",
        "com.apple.Safari.web-extension",
    ),
)
MAX_ARCHIVE_BYTES = 512 * 1024 * 1024
MAX_MEMBER_BYTES = 128 * 1024 * 1024
MAX_PLIST_BYTES = 1024 * 1024
MAX_MEMBERS = 50_000


class IPAValidationError(ValueError):
    """An archive does not meet this project's physical-device build contract."""


def _members(archive):
    members = {}
    folded = set()
    total = 0
    entries = archive.infolist()
    if not entries or len(entries) > MAX_MEMBERS:
        raise IPAValidationError("Empty archive or too many ZIP entries")
    for entry in entries:
        name = entry.filename
        clean = name[:-1] if name.endswith("/") else name
        parts = clean.split("/")
        if (
            entry.orig_filename != name
            or "\\" in name
            or ":" in name
            or any(ord(char) < 32 or ord(char) == 127 for char in name)
            or any(part in ("", ".", "..") for part in parts)
            or parts[0] != "Payload"
            or (len(parts) > 1 and parts[1] != "VNAnviaApp.app")
        ):
            raise IPAValidationError("Unsafe path or unexpected top-level item in IPA")
        if clean.casefold() in folded:
            raise IPAValidationError("Duplicate or case-colliding ZIP entry")
        folded.add(clean.casefold())
        mode = entry.external_attr >> 16
        kind = stat.S_IFMT(mode)
        if kind not in (0, stat.S_IFREG, stat.S_IFDIR):
            raise IPAValidationError("Symlink or special file is not allowed in IPA")
        if (kind == stat.S_IFDIR and not entry.is_dir()) or (kind == stat.S_IFREG and entry.is_dir()):
            raise IPAValidationError("ZIP file type disagrees with its path")
        if entry.flag_bits & 1 or entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
            raise IPAValidationError("Encrypted or unsupported ZIP member")
        total += entry.file_size
        if entry.file_size > MAX_MEMBER_BYTES or total > MAX_ARCHIVE_BYTES:
            raise IPAValidationError("IPA exceeds the validation resource limit")
        if parts[-1].casefold() == "embedded.mobileprovision":
            raise IPAValidationError("Provisioned IPA is not an unsigned build for local signing")
        if any(part.endswith(".xctest") for part in parts):
            raise IPAValidationError("Test bundle must not be included in the device IPA")
        members[name] = entry
    # A file must never also be an ancestor directory of a different entry.
    files = {name for name, entry in members.items() if not entry.is_dir()}
    for name in members:
        parts = name.rstrip("/").split("/")
        if any("/".join(parts[:end]) in files for end in range(1, len(parts))):
            raise IPAValidationError("ZIP file and directory paths overlap")
    plugins = {
        "/".join(name.rstrip("/").split("/")[:4])
        for name in members
        if name.startswith(APP + "/PlugIns/") and len(name.rstrip("/").split("/")) >= 4
    }
    if plugins != {bundle[0] for bundle in BUNDLES[1:]}:
        raise IPAValidationError("IPA must include exactly the Action and Safari extensions")
    if any(
        part.endswith((".app", ".appex")) and "/".join(name.split("/")[:index + 1])
        not in {bundle[0] for bundle in BUNDLES}
        for name in members
        for index, part in enumerate(name.rstrip("/").split("/"))
    ):
        raise IPAValidationError("Unexpected nested application or extension bundle")
    return members


def _read(archive, members, name, maximum):
    entry = members.get(name)
    if entry is None or entry.is_dir() or entry.file_size > maximum:
        raise IPAValidationError("Required bundle file is missing or exceeds its size limit")
    return archive.read(entry)


def _version(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){0,2}", value):
        raise IPAValidationError("Invalid MinimumOSVersion")
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * (3 - len(parts))


def _macho(data):
    if len(data) < 32 or data[:4] != b"\xcf\xfa\xed\xfe":
        raise IPAValidationError("Executable must be a thin little-endian 64-bit Mach-O")
    _, cpu, subtype, filetype, ncmds, sizeofcmds, _, _ = struct.unpack_from("<IiiIIIII", data)
    if cpu != 0x0100000C or subtype & 0x00FFFFFF:
        raise IPAValidationError("Executable architecture must be arm64")
    if filetype != 2:
        raise IPAValidationError("Bundle executable must be MH_EXECUTE")
    end = 32 + sizeofcmds
    if not 0 < ncmds <= 10_000 or ncmds > sizeofcmds // 8 or end > len(data):
        raise IPAValidationError("Invalid Mach-O load-command table")
    offset = 32
    build_version = None
    signature_present = False
    for _ in range(ncmds):
        if offset + 8 > end:
            raise IPAValidationError("Truncated Mach-O load command")
        command, size = struct.unpack_from("<II", data, offset)
        if size < 8 or size % 8 or offset + size > end:
            raise IPAValidationError("Invalid Mach-O load-command size")
        if command == 0x32:  # LC_BUILD_VERSION distinguishes iOS from arm64 iOS Simulator.
            if build_version is not None or size < 24:
                raise IPAValidationError("Missing or duplicate Mach-O build-version metadata")
            platform, minimum, _, tools = struct.unpack_from("<IIII", data, offset + 8)
            if size != 24 + tools * 8:
                raise IPAValidationError("Invalid Mach-O build-version tool table")
            if platform != 2:
                raise IPAValidationError("Mach-O platform must be iOS, not Simulator or another platform")
            build_version = (minimum >> 16, (minimum >> 8) & 255, minimum & 255)
            if build_version < (17, 0, 0):
                raise IPAValidationError("Mach-O deployment target must be iOS 17 or later")
        if command == 0x1D:  # LC_CODE_SIGNATURE is metadata, not proof of a valid identity/signature.
            if signature_present or size != 16:
                raise IPAValidationError("Invalid or duplicate Mach-O code-signature command")
            signature_present = True
            data_offset, data_size = struct.unpack_from("<II", data, offset + 8)
            if data_size and (data_offset < end or data_offset + data_size > len(data)):
                raise IPAValidationError("Mach-O code-signature data is outside the executable")
        offset += size
    if offset != end or build_version is None:
        raise IPAValidationError("Mach-O requires an exact load-command table and LC_BUILD_VERSION")
    return build_version, signature_present


def validate(path):
    """Validate bytes without extracting; report structure, not signing/installability."""
    path = Path(path)
    try:
        with path.open("rb") as stream, zipfile.ZipFile(stream) as archive:
            members = _members(archive)
            # Read every resource too, so a damaged OCR/model asset cannot pass on metadata alone.
            if archive.testzip() is not None:
                raise IPAValidationError("ZIP member integrity check failed")
            bundles = []
            for bundle, identifier, extension_point in BUNDLES:
                try:
                    info = plistlib.loads(_read(archive, members, bundle + "/Info.plist", MAX_PLIST_BYTES))
                except IPAValidationError:
                    raise
                except Exception as error:
                    raise IPAValidationError("Bundle Info.plist is invalid") from error
                if not isinstance(info, dict) or info.get("CFBundleIdentifier") != identifier:
                    raise IPAValidationError("Bundle identifier does not match the VNAnvia device build")
                if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
                    raise IPAValidationError("Bundle platform must be iPhoneOS")
                minimum_os = info.get("MinimumOSVersion")
                if _version(minimum_os) < (17, 0, 0):
                    raise IPAValidationError("Bundle deployment target must be iOS 17 or later")
                expected_kind = "XPC!" if extension_point else "APPL"
                if info.get("CFBundlePackageType") != expected_kind:
                    raise IPAValidationError("Invalid application or extension package type")
                if extension_point:
                    extension = info.get("NSExtension")
                    if not isinstance(extension, dict) or extension.get("NSExtensionPointIdentifier") != extension_point:
                        raise IPAValidationError("Extension point does not match the required VNAnvia extension")
                executable = info.get("CFBundleExecutable")
                if (
                    not isinstance(executable, str)
                    or not executable
                    or executable in (".", "..")
                    or any(char in executable for char in "/\\:")
                    or any(ord(char) < 32 or ord(char) == 127 for char in executable)
                ):
                    raise IPAValidationError("Unsafe or missing bundle executable name")
                binary = _read(archive, members, bundle + "/" + executable, MAX_MEMBER_BYTES)
                binary_minimum, signature_present = _macho(binary)
                if binary_minimum != _version(minimum_os):
                    raise IPAValidationError("Info.plist and Mach-O deployment targets disagree")
                bundles.append({
                    "path": bundle,
                    "bundle_identifier": identifier,
                    "minimum_os_version": minimum_os,
                    "executable": executable,
                    "platform": "iOS",
                    "architecture": "arm64",
                    "code_signature_load_command_present": signature_present,
                    "code_signature_resources_present": any(
                        name.startswith(bundle + "/_CodeSignature/") for name in members
                    ),
                })
            stream.seek(0)
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
    except IPAValidationError:
        raise
    except (OSError, zipfile.BadZipFile, RuntimeError, EOFError, NotImplementedError) as error:
        raise IPAValidationError("Unreadable or corrupt IPA ZIP archive") from error
    return {
        "validation": "passed",
        "file": path.name,
        "sha256": digest,
        "artifact_kind": "device-ipa-for-local-signing",
        "platform": "iOS",
        "architecture": "arm64",
        "provisioning_profiles_present": False,
        "signing_status": "not_verified",
        "installation_tested": False,
        "bundles": bundles,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    args = parser.parse_args()
    try:
        result = validate(args.ipa)
    except IPAValidationError as error:
        print("Device IPA rejected: " + str(error), file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
