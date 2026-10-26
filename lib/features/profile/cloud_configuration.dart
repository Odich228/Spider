import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';

class CloudConfiguration extends ConsumerWidget {
  const CloudConfiguration({super.key});
  Future<void> configure(BuildContext context, WidgetRef ref) async {
    final url = TextEditingController();
    final key = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Подключить Supabase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Используйте URL проекта и публичный publishable / anon key. Секретный service_role key сюда вводить нельзя. Сначала примените миграции из репозитория.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'URL проекта'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: key,
                  decoration: const InputDecoration(
                    labelText: 'Публичный ключ',
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final uri = Uri.tryParse(url.text.trim());
                if (uri == null ||
                    uri.scheme != 'https' ||
                    uri.host.isEmpty ||
                    uri.userInfo.isNotEmpty ||
                    key.text.trim().isEmpty ||
                    key.text.trim().startsWith('sb_secret_')) {
                  refresh(() => error = 'Введите HTTPS URL и публичный ключ.');
                  return;
                }
                final parts = key.text.trim().split('.');
                if (parts.length == 3) {
                  try {
                    final payload = jsonDecode(
                      utf8.decode(
                        base64Url.decode(base64Url.normalize(parts[1])),
                      ),
                    );
                    if (payload['role'] == 'service_role') {
                      refresh(
                        () => error =
                            'Нужен публичный anon key, а не service_role.',
                      );
                      return;
                    }
                  } catch (_) {
                    refresh(() => error = 'Некорректный публичный ключ.');
                    return;
                  }
                }
                Navigator.pop(dialog, true);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      final config = File(
        p.join(p.dirname(ref.read(directoryProvider).path), 'cloud.json'),
      );
      await config.writeAsString(
        jsonEncode({'url': url.text.trim(), 'key': key.text.trim()}),
        flush: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Настройки сохранены. Перезапустите приложение, чтобы войти в аккаунт.',
            ),
          ),
        );
      }
    }
    Future<void>.delayed(const Duration(seconds: 1), () {
      url.dispose();
      key.dispose();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    onPressed: () => configure(context, ref),
    icon: const Icon(Icons.cloud_outlined),
    label: const Text('Подключить облако'),
  );
}
