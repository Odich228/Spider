"""Build one native release target and produce a machine-readable manifest.

No repository-writing credentials are available to this script. Distribution
certificates are optional; unsigned previews are named and documented as such.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shutil
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]


def run(args, *, env=None, capture=False, sensitive=False):
    result = subprocess.run(args, cwd=ROOT, env=env, capture_output=capture or sensitive,
                            text=True, shell=os.name == "nt" and str(args[0]).endswith(".bat"))
    if result.returncode:
        # Never include command arguments: they may contain signing passwords.
        raise RuntimeError(f"{Path(args[0]).name} failed (exit {result.returncode})")
    return result.stdout if capture else None


def app_version():
    match = re.search(r"^version:\s*['\"]?(\d+\.\d+\.\d+)(?:\+\d+)?['\"]?\s*$", (ROOT / "pubspec.yaml").read_text(), re.M)
    if not match:
        raise ValueError("pubspec.yaml must declare a numeric x.y.z+build version")
    return match.group(1)


def zip_tree(source: Path, target: Path):
    files = [file for file in sorted(source.rglob("*")) if file.is_file()]
    if not source.is_dir() or not files:
        raise ValueError("Native bundle is missing or empty")
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in files:
            archive.write(file, file.relative_to(source))


def property_escape(value: str) -> str:
    result = []
    for unit in (int.from_bytes(value.encode("utf-16-be")[i:i+2], "big") for i in range(0, len(value.encode("utf-16-be")), 2)):
        char = chr(unit)
        if char in "\\ :=#!": result.append("\\" + char)
        elif char == "\n": result.append("\\n")
        elif char == "\r": result.append("\\r")
        elif unit < 32 or unit > 126: result.append(f"\\u{unit:04x}")
        else: result.append(char)
    return "".join(result)


def android(flutter, common, dist):
    names = ["ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD"]
    present = [bool(os.getenv(name)) for name in names]
    if any(present) and not all(present):
        raise ValueError("Configure all four ANDROID_* signing secrets, or none for a preview")
    key = ROOT / "android/app/ci-upload.jks"
    properties = ROOT / "android/key.properties"
    if key.exists() or properties.exists():
        raise ValueError("Refusing to overwrite a local Android signing configuration")
    try:
        signed = all(present)
        if signed:
            key.write_bytes(base64.b64decode(os.environ[names[0]], validate=True))
            properties.write_text("\n".join(f"{k}={property_escape(v)}" for k, v in {
                "storeFile": "ci-upload.jks", "storePassword": os.environ[names[1]],
                "keyAlias": os.environ[names[2]], "keyPassword": os.environ[names[3]],
            }.items()), encoding="ascii")
        run([flutter, "build", "apk", *common])
        suffix = "signed" if signed else "debug-key-preview"
        apk = dist / f"Pautina-android-{suffix}.apk"
        shutil.copy2(ROOT / "build/app/outputs/flutter-apk/app-release.apk", apk)
        files = [apk]
        if signed:
            run([flutter, "build", "appbundle", *common])
            bundle = dist / "Pautina-android-signed.aab"
            shutil.copy2(ROOT / "build/app/outputs/bundle/release/app-release.aab", bundle)
            files.append(bundle)
        return files, "upload-key" if signed else "debug-key-preview"
    finally:
        if all(present):
            key.unlink(missing_ok=True)
            properties.unlink(missing_ok=True)


def ios(flutter, common, dist):
    cert = os.getenv("IOS_CERTIFICATE_BASE64", "")
    profile = os.getenv("IOS_PROVISION_PROFILE_BASE64", "")
    if bool(cert) != bool(profile):
        raise ValueError("Both IOS_CERTIFICATE_BASE64 and IOS_PROVISION_PROFILE_BASE64 are required")
    if not cert:
        run([flutter, "build", "ios", *common, "--no-codesign"])
        target = dist / "Pautina-ios-UNSIGNED.app.zip"
        run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(ROOT / "build/ios/iphoneos/Runner.app"), str(target)])
        return [target], "unsigned-not-installable"

    scratch = Path(tempfile.mkdtemp(prefix="pautina-ios-", dir=os.environ.get("RUNNER_TEMP")))
    cert_file = scratch / "distribution.p12"
    source_profile = scratch / "profile.mobileprovision"
    keychain = scratch / "signing.keychain-db"
    release_config = ROOT / "ios/Flutter/Release.xcconfig"
    signing_config = ROOT / "ios/Flutter/CI-Signing.xcconfig"
    previous_config = release_config.read_bytes()
    installed_profile = None
    profile_created = False
    config_created = False
    previous_keychains = None
    try:
        if signing_config.exists():
            raise ValueError("Refusing to overwrite an existing CI signing configuration")
        cert_file.write_bytes(base64.b64decode(cert, validate=True))
        source_profile.write_bytes(base64.b64decode(profile, validate=True))
        data = plistlib.loads(run(["security", "cms", "-D", "-i", str(source_profile)], capture=True).encode())
        team = data["TeamIdentifier"][0]
        identifier = data["Entitlements"]["application-identifier"].split(".", 1)[1]
        if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', identifier):
            raise ValueError("Use an explicit app identifier in the provisioning profile")
        if not re.fullmatch(r'[A-Fa-f0-9-]{36}', data['UUID']) or not re.fullmatch(r'[A-Z0-9]+', team):
            raise ValueError("Invalid provisioning profile identity")
        installed_profile = Path.home() / "Library/MobileDevice/Provisioning Profiles" / f"{data['UUID']}.mobileprovision"
        if installed_profile.exists():
            raise ValueError("Refusing to replace an existing provisioning profile")
        installed_profile.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_profile, installed_profile)
        profile_created = True
        keychain_password = secrets.token_urlsafe(30)
        run(["security", "create-keychain", "-p", keychain_password, str(keychain)], sensitive=True)
        run(["security", "set-keychain-settings", "-lut", "21600", str(keychain)])
        run(["security", "unlock-keychain", "-p", keychain_password, str(keychain)], sensitive=True)
        run(["security", "import", str(cert_file), "-P", os.getenv("IOS_CERTIFICATE_PASSWORD", ""), "-A", "-t", "cert", "-f", "pkcs12", "-k", str(keychain)], sensitive=True)
        run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-k", keychain_password, str(keychain)], sensitive=True)
        import shlex
        previous_keychains = shlex.split(run(["security", "list-keychains", "-d", "user"], capture=True))
        run(["security", "list-keychains", "-d", "user", "-s", str(keychain), *previous_keychains])
        signing_config.write_text(f'DEVELOPMENT_TEAM={team}\nPRODUCT_BUNDLE_IDENTIFIER={identifier}\nCODE_SIGN_STYLE=Manual\nCODE_SIGN_IDENTITY=Apple Distribution\nPROVISIONING_PROFILE_SPECIFIER={data["UUID"]}\n')
        config_created = True
        release_config.write_bytes(previous_config + b'\n#include "CI-Signing.xcconfig"\n')
        method = os.getenv("IOS_EXPORT_METHOD") or ("enterprise" if data.get("ProvisionsAllDevices") else "release-testing" if data.get("ProvisionedDevices") else "app-store-connect")
        if method not in {"release-testing", "app-store-connect", "enterprise", "debugging"}:
            raise ValueError("Unsupported IOS_EXPORT_METHOD")
        export = scratch / "ExportOptions.plist"
        export.write_bytes(plistlib.dumps({"method": method, "teamID": team, "signingStyle": "manual", "signingCertificate": "Apple Distribution", "provisioningProfiles": {identifier: data["UUID"]}}))
        run([flutter, "build", "ipa", *common, f"--export-options-plist={export}"])
        artifacts = list((ROOT / "build/ios/ipa").glob("*.ipa"))
        if len(artifacts) != 1:
            raise ValueError("Expected exactly one exported IPA")
        target = dist / "Pautina-ios-signed.ipa"
        shutil.copy2(artifacts[0], target)
        return [target], f"apple-distribution-{method}"
    finally:
        release_config.write_bytes(previous_config)
        if config_created:
            signing_config.unlink(missing_ok=True)
        if previous_keychains is not None:
            run(["security", "list-keychains", "-d", "user", "-s", *previous_keychains])
        if keychain.exists():
            run(["security", "delete-keychain", str(keychain)], sensitive=True)
        if profile_created and installed_profile and installed_profile.exists():
            installed_profile.unlink()
        # This branch runs only on macOS; the directory was created here.
        shutil.rmtree(scratch)


def main():
    from signing import sign_windows, package_macos
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=["android", "windows", "macos", "ios"], required=True)
    parser.add_argument("--build-number", type=int, required=True)
    args = parser.parse_args()
    if args.build_number < 1: raise ValueError("Build number must be positive")
    flutter = shutil.which("flutter")
    if not flutter: raise ValueError("Flutter is not installed")
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    common = ["--release", f"--build-number={args.build_number}"]
    for key in ("SUPABASE_URL", "SUPABASE_ANON_KEY"):
        if os.getenv(key): common.append(f"--dart-define={key}={os.environ[key]}")
    if bool(os.getenv("SUPABASE_URL")) != bool(os.getenv("SUPABASE_ANON_KEY")):
        raise ValueError("Configure both SUPABASE variables or neither")
    if args.platform == "android": files, signing = android(flutter, common, dist)
    elif args.platform == "ios": files, signing = ios(flutter, common, dist)
    elif args.platform == "windows":
        run([flutter, "build", "windows", *common])
        target = dist / "Pautina-windows-x64.zip"
        signing = sign_windows(ROOT / "build/windows/x64/runner/Release")
        zip_tree(ROOT / "build/windows/x64/runner/Release", target)
        files = [target]
    else:
        run([flutter, "build", "macos", *common])
        apps = list((ROOT / "build/macos/Build/Products/Release").glob("*.app"))
        if len(apps) != 1: raise ValueError("Expected exactly one macOS app")
        target = dist / "Pautina-macos.app.zip"
        signing = package_macos(apps[0], target, ROOT)
        files = [target]
    manifest = {"platform": args.platform, "version": app_version(), "build_number": args.build_number,
                "commit": os.getenv("GITHUB_SHA", "local"), "signing": signing,
                "files": [{"name": file.name, "sha256": hashlib.file_digest(file.open("rb"), "sha256").hexdigest()} for file in files]}
    (dist / f"manifest-{args.platform}.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Built {args.platform}: {signing}")


if __name__ == "__main__":
    main()
