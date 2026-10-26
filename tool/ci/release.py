from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

PLATFORMS = {"android", "windows", "macos", "ios"}


def validate(directory: Path, number: int, commit: str):
    manifests = [json.loads(path.read_text()) for path in sorted(directory.glob("manifest-*.json"))]
    if len(manifests) != 4 or {m["platform"] for m in manifests} != PLATFORMS:
        raise ValueError("A release requires exactly one manifest per platform")
    if len({m["version"] for m in manifests}) != 1:
        raise ValueError("Platform versions differ")
    for manifest in manifests:
        if manifest["build_number"] != number or manifest["commit"] != commit:
            raise ValueError("Artifacts must come from the same build and commit")
        if not manifest["files"]:
            raise ValueError("Platform has no artifacts")
        for artifact in manifest["files"]:
            name = artifact["name"]
            if Path(name).name != name or "\\" in name:
                raise ValueError("Artifact names must be basenames")
            file = directory / name
            if not file.is_file(): raise ValueError(f"Missing artifact: {name}")
            with file.open("rb") as source:
                actual = hashlib.file_digest(source, "sha256").hexdigest()
            if actual != artifact["sha256"]:
                raise ValueError(f"Checksum mismatch: {name}")
    return manifests


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--number", type=int, required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    manifests = validate(args.directory, args.number, args.commit)
    tag = f'v{manifests[0]["version"]}-build.{args.number}'
    notes = [f"# Паутина {tag}", "", f"Commit: `{args.commit}`", "", "Первая версия читалки. Комиксы добавляются пользователем.", "", "| Платформа | Подпись / формат |", "|---|---|"]
    for manifest in manifests:
        notes.append(f'| {manifest["platform"]} | {manifest["signing"]} |')
    notes += ["", "Без секретов подписи iOS собирается как **неподписанный .app.zip**: его нельзя установить на iPhone. После подключения сертификата и provisioning profile публикуется IPA; способ установки определяется типом профиля.", "", "Android без upload key — устанавливаемый preview с отладочной подписью; ключ между CI-запусками не сохраняется. Для обновлений и магазина настройте постоянный upload key. macOS пока без Developer ID/notarization; Windows — portable ZIP без Authenticode.", "", "Метаданные, коллекции, порядок, прогресс и свои обложки синхронизируются только в сборках с настроенным Supabase. Исходные файлы комиксов остаются локальными.", "", "Подробности: `docs/ci-cd.md`, `docs/architecture.md`."]
    (args.directory / "RELEASE-NOTES.md").write_text("\n".join(notes) + "\n", encoding="utf-8")
    (args.directory / "release.json").write_text(json.dumps({"tag": tag, "commit": args.commit, "platforms": manifests}, indent=2) + "\n")
    lines = []
    for file in sorted(args.directory.iterdir()):
        if file.is_file() and file.name != "SHA256SUMS.txt":
            with file.open("rb") as source:
                lines.append(f'{hashlib.file_digest(source, "sha256").hexdigest()}  {file.name}')
    (args.directory / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n")
    print(tag)


if __name__ == "__main__": main()
