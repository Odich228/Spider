import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';

class AppUpdate {
  const AppUpdate(this.tag, this.url, this.download, this.sha256, this.build);
  final String tag, url, download, sha256;
  final int build;
}

bool isNewerRelease(
  String version,
  int build,
  String installedVersion,
  int installedBuild,
) {
  final remote = version.split('.').map(int.tryParse).toList();
  final installed = installedVersion.split('.').map(int.tryParse).toList();
  if (remote.length != 3 ||
      installed.length != 3 ||
      remote.contains(null) ||
      installed.contains(null)) {
    return false;
  }
  for (var i = 0; i < 3; i++) {
    if (remote[i] != installed[i]) return remote[i]! > installed[i]!;
  }
  return build > installedBuild;
}

final appUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  if (!Platform.isWindows && !Platform.isMacOS) return null;
  final info = await PackageInfo.fromPlatform();
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final releases = jsonDecode(
      utf8.decode(
        await fetchBytes(
          client,
          Uri.parse(
            'https://api.github.com/repos/Odich228/Spider/releases?per_page=20',
          ),
          maxBytes: 2 * 1024 * 1024,
        ),
      ),
    ) as List;
    for (final release in releases.whereType<Map<String, dynamic>>()) {
      if (release['draft'] == true) continue;
      final assets = (release['assets'] as List).cast<Map<String, dynamic>>();
      final manifest = assets
          .where((a) => a['name'] == 'release.json')
          .firstOrNull;
      if (manifest == null) continue;
      final data = jsonDecode(
        utf8.decode(
          await fetchBytes(
            client,
            Uri.parse(manifest['browser_download_url'] as String),
            maxBytes: 1024 * 1024,
          ),
        ),
      ) as Map<String, dynamic>;
      final platform = (data['platforms'] as List)
          .cast<Map<String, dynamic>>()
          .where(
            (m) => m['platform'] == (Platform.isWindows ? 'windows' : 'macos'),
          )
          .firstOrNull;
      if (platform == null) continue;
      final build = platform['build_number'] as int;
      if (!isNewerRelease(
        platform['version'] as String,
        build,
        info.version,
        int.tryParse(info.buildNumber) ?? 0,
      )) {
        continue;
      }
      final file = (platform['files'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => (f['name'] as String).endsWith('.zip'));
      final asset = assets.firstWhere((a) => a['name'] == file['name']);
      return AppUpdate(
        release['tag_name'] as String,
        release['html_url'] as String,
        asset['browser_download_url'] as String,
        file['sha256'] as String,
        build,
      );
    }
    return null;
  } finally {
    client.close(force: true);
  }
});

Future<List<int>> fetchBytes(
  HttpClient client,
  Uri uri, {
  required int maxBytes,
}) async {
  final response = await openResponse(client, uri);
  final bytes = <int>[];
  await for (final chunk in response.timeout(const Duration(seconds: 30))) {
    if (bytes.length + chunk.length > maxBytes) {
      throw const FormatException('Ответ сервера слишком большой.');
    }
    bytes.addAll(chunk);
  }
  return bytes;
}

Future<HttpClientResponse> openResponse(HttpClient client, Uri uri) async {
  for (var redirects = 0; redirects < 6; redirects++) {
    if (uri.scheme != 'https') {
      throw const FormatException('Обновления требуют HTTPS.');
    }
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set('User-Agent', 'Pautina-update-check');
    final response = await request.close().timeout(const Duration(seconds: 30));
    if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
      final location = response.headers.value('location');
      await response.drain<void>();
      if (location == null) throw const FormatException('Нет адреса загрузки.');
      uri = uri.resolve(location);
      continue;
    }
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    return response;
  }
  throw const FormatException('Слишком много перенаправлений.');
}

Future<String> unpackWindowsUpdate(Map<String, String> job) async {
  final input = InputFileStream(job['zip']!);
  final archive = ZipDecoder().decodeStream(input, verify: true);
  final root = p.absolute(job['target']!);
  try {
    var size = 0;
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final path = p.normalize(p.join(root, entry.name));
      if (!p.isWithin(root, path) || entry.isSymbolicLink) {
        throw const FormatException('Недопустимый путь обновления.');
      }
      size += entry.size;
      if (size > 1024 * 1024 * 1024) {
        throw const FormatException('Обновление слишком большое.');
      }
      await Directory(p.dirname(path)).create(recursive: true);
      final output = OutputFileStream(path);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
    }
    if (!File(p.join(root, 'pautina.exe')).existsSync() ||
        !File(p.join(root, 'flutter_windows.dll')).existsSync()) {
      throw const FormatException('Неполная сборка обновления.');
    }
    return root;
  } finally {
    archive.clearSync();
    input.closeSync();
  }
}

class UpdateSettings extends ConsumerStatefulWidget {
  const UpdateSettings({super.key});
  @override
  ConsumerState<UpdateSettings> createState() => _UpdateSettingsState();
}

class _UpdateSettingsState extends ConsumerState<UpdateSettings> {
  bool busy = false;
  String? message;
  Future<void> download(AppUpdate update) async {
    setState(() {
      busy = true;
      message = 'Загрузка обновления…';
    });
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final directory = Directory(
        p.join(
          p.dirname(ref.read(directoryProvider).path),
          'updates',
          'build-${update.build}',
        ),
      );
      await directory.create(recursive: true);
      final zip = File(p.join(directory.path, 'update.zip'));
      final response = await openResponse(client, Uri.parse(update.download));
      final sink = zip.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          received += chunk.length;
          if (received > 512 * 1024 * 1024) {
            throw const FormatException('Обновление превышает 512 МБ.');
          }
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      final digest = (await sha256.bind(zip.openRead()).first).toString();
      if (digest != update.sha256) {
        await zip.delete();
        throw const FormatException(
          'Контрольная сумма обновления не совпадает.',
        );
      }
      if (!mounted) return;
      if (Platform.isMacOS) {
        final stage = Directory(p.join(directory.path, 'macos'));
        await stage.create(recursive: true);
        final extracted = await Process.run('/usr/bin/ditto', [
          '-x',
          '-k',
          zip.path,
          stage.path,
        ]);
        if (extracted.exitCode != 0) {
          throw const FormatException('Не удалось распаковать обновление.');
        }
        final apps = await stage
            .list()
            .where((e) => e is Directory && e.path.endsWith('.app'))
            .toList();
        if (apps.length != 1) {
          throw const FormatException('Неполная сборка macOS.');
        }
        final verification = await Process.run('/usr/bin/codesign', [
          '--verify',
          '--deep',
          '--strict',
          apps.single.path,
        ]);
        if (verification.exitCode != 0) {
          throw const FormatException('Подпись приложения повреждена.');
        }
        final installed = p.dirname(
          p.dirname(p.dirname(Platform.resolvedExecutable)),
        );
        if (!installed.endsWith('.app')) {
          throw const FormatException(
            'Запустите установленный пакет приложения.',
          );
        }
        if (!mounted) return;
        final install = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('Установить ${update.tag}?'),
            content: const Text(
              'Приложение перезапустится после обновления. Предыдущая версия сохранится рядом для восстановления.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Позже'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Установить'),
              ),
            ],
          ),
        );
        if (install != true) return;
        final script = File(p.join(directory.path, 'install.sh'));
        await script.writeAsString(r'''#!/bin/sh
set -eu
process_id="$1"
source_app="$2"
target_app="$3"
while kill -0 "$process_id" 2>/dev/null; do sleep 1; done
incoming="${target_app}.incoming-${process_id}.app"
backup="${target_app}.previous-${process_id}.app"
if /usr/bin/ditto "$source_app" "$incoming"; then
  if /bin/mv "$target_app" "$backup"; then
    if /bin/mv "$incoming" "$target_app"; then
      /usr/bin/open "$target_app"
      exit 0
    fi
    /bin/mv "$backup" "$target_app"
  fi
fi
/usr/bin/open "$source_app"
''');
        await Process.start('/bin/sh', [
          script.path,
          '$pid',
          apps.single.path,
          installed,
        ], mode: ProcessStartMode.detached);
        exit(0);
      } else {
        final stage = await compute(unpackWindowsUpdate, {
          'zip': zip.path,
          'target': p.join(directory.path, 'app'),
        });
        if (!mounted) return;
        final install = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('Установить ${update.tag}?'),
            content: const Text(
              'Приложение закроется, обновит файлы и откроется снова. Библиотека хранится отдельно.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Позже'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Установить'),
              ),
            ],
          ),
        );
        if (install != true) {
          if (mounted) {
            setState(() => message = 'Обновление загружено и проверено.');
          }
          return;
        }
        final config = File(p.join(directory.path, 'install.json'));
        await config.writeAsString(
          jsonEncode({
            'processId': pid,
            'source': stage,
            'target': p.dirname(Platform.resolvedExecutable),
            'executable': p.basename(Platform.resolvedExecutable),
          }),
        );
        final script = File(p.join(directory.path, 'install.ps1'));
        await script.writeAsString(r'''
param([string]$ConfigPath)
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
Wait-Process -Id $config.processId -ErrorAction SilentlyContinue
$source = [IO.Path]::GetFullPath($config.source)
$target = [IO.Path]::GetFullPath($config.target)
$backup = Join-Path (Split-Path $ConfigPath) 'previous'
$changed = @()
try {
  if (!(Test-Path -LiteralPath (Join-Path $source 'pautina.exe'))) { throw 'Missing update executable' }
  if (!(Test-Path -LiteralPath (Join-Path $target $config.executable))) { throw 'Missing installed executable' }
  New-Item -ItemType Directory -Path $backup -Force | Out-Null
  Get-ChildItem -LiteralPath $source | ForEach-Object {
    $installed = Join-Path $target $_.Name
    if (Test-Path -LiteralPath $installed) { Copy-Item -LiteralPath $installed -Destination $backup -Recurse -Force }
    $changed += $_.Name
    Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
  }
  Start-Process -FilePath (Join-Path $target $config.executable) -WorkingDirectory $target
} catch {
  $_ | Out-File -LiteralPath (Join-Path (Split-Path $ConfigPath) 'install-error.txt')
  foreach ($name in $changed) {
    $saved = Join-Path $backup $name
    if (Test-Path -LiteralPath $saved) { Copy-Item -LiteralPath $saved -Destination $target -Recurse -Force -ErrorAction SilentlyContinue }
  }
  Start-Process -FilePath (Join-Path $source 'pautina.exe') -WorkingDirectory $source
}
''');
        await Process.start('powershell.exe', [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
          '-ConfigPath',
          config.path,
        ], mode: ProcessStartMode.detached);
        exit(0);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message = error is FormatException ? error.message.toString() : 'Не удалось обновить приложение. Повторите попытку или скачайте релиз с GitHub.',
        );
      }
    } finally {
      client.close(force: true);
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isMacOS) return const SizedBox();
    final settings = ref.watch(libraryProvider).value?.settings ?? {};
    final update = ref.watch(appUpdateProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Обновления', style: TextStyle(fontSize: 22)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Проверять при запуске'),
          value: settings['autoUpdateChecks'] != false,
          onChanged: (value) => ref.read(repositoryProvider).settings({
            'autoUpdateChecks': value,
          }),
        ),
        update.when(
          data: (value) => Text(
            value == null
                ? 'Установлена актуальная сборка.'
                : 'Доступна ${value.tag}',
          ),
          error: (_, _) => const Text('Не удалось проверить обновления.'),
          loading: () => const Text('Проверка обновлений…'),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => ref.invalidate(appUpdateProvider),
              child: const Text('Проверить'),
            ),
            if (update.value != null)
              FilledButton(
                onPressed: busy ? null : () => download(update.value!),
                child: Text(busy ? 'Загрузка…' : 'Скачать и обновить'),
              ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/Odich228/Spider/releases'),
              ),
              child: const Text('Все релизы'),
            ),
          ],
        ),
        if (message != null) Text(message!),
        const SizedBox(height: 28),
      ],
    );
  }
}
