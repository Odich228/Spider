import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../reader/book_page.dart';
import 'update_settings.dart';
import 'cloud_configuration.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? message;
  Future<void> authenticate({bool register = false}) async {
    if (email.text.trim().isEmpty || password.text.length < 8) {
      setState(
        () => message = 'Введите email и пароль длиной не менее 8 символов.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = ref.read(cloudProvider)!.auth;
      if (register) {
        await auth.signUp(email: email.text.trim(), password: password.text);
        if (mounted) {
          setState(
            () => message =
                'Проверьте почту, если включено подтверждение адреса.',
          );
        }
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      password.clear();
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Не удалось подключиться. Проверьте интернет.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(cloudProvider);
    final user = ref.watch(sessionProvider).value;
    final sync = ref.watch(syncStateProvider).value;
    final library = ref.watch(libraryProvider).value;
    final read =
        library?.issues
            .where((issue) => library.progress[issue.id]?.finished ?? false)
            .length ??
        0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Профиль',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: spiderRed,
                        child: Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.email ?? 'Локальный профиль',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sync?.message ?? 'Локальная библиотека',
                              style: const TextStyle(color: secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Прочитано $read из ${library?.issues.length ?? 0} выпусков',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 30),
              const AppearanceSettings(),
              const UpdateSettings(),
              if (client == null) const CloudConfiguration(),
              if (client == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Облако ещё не подключено',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Комиксы, коллекции и прогресс сохраняются на этом устройстве. Аккаунты и синхронизация появятся в сборке с подключённым сервером.',
                          style: TextStyle(color: secondaryText, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                )
              else if (user == null) ...[
                const Text(
                  'Войти и синхронизировать',
                  style: TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 14),
                const Text(
                  'При входе откроется библиотека аккаунта. Локальная библиотека останется отдельно на этом устройстве.',
                  style: TextStyle(color: secondaryText, height: 1.6),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Пароль'),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: busy ? null : authenticate,
                      child: Text(busy ? 'Подключение…' : 'Войти'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => authenticate(register: true),
                      child: const Text('Создать аккаунт'),
                    ),
                  ],
                ),
              ] else ...[
                const Text('Синхронизируются', style: TextStyle(fontSize: 21)),
                const SizedBox(height: 12),
                const ListTile(
                  leading: Icon(Icons.cloud_done_outlined),
                  title: Text('Прогресс, серии и коллекции'),
                  subtitle: Text('Включая порядок чтения и свои обложки'),
                ),
                const ListTile(
                  leading: Icon(Icons.devices_outlined),
                  title: Text('Файлы комиксов хранятся на устройстве'),
                  subtitle: Text(
                    'Тот же файл можно добавить на другом устройстве',
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: sync?.busy == true
                          ? null
                          : () => ref.read(syncServiceProvider)?.sync(),
                      icon: const Icon(Icons.sync),
                      label: const Text('Синхронизировать'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await client.auth.signOut(scope: SignOutScope.local);
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => message =
                                  'Не удалось выйти. Повторите попытку.',
                            );
                          }
                        }
                      },
                      child: const Text('Выйти'),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            final count = await ref
                                .read(repositoryProvider)
                                .copyGuestLibrary();
                            if (mounted) {
                              setState(
                                () => message =
                                    'Из локальной библиотеки добавлено записей: $count. Уже существующие данные аккаунта сохранены.',
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => message = 'Не удалось перенести библиотеку. Повторите попытку.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('Добавить локальную библиотеку в аккаунт'),
                ),
                ...?sync?.conflicts.map(
                  (conflict) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(conflict.title),
                          const SizedBox(height: 8),
                          const Text(
                            'Изменено на двух устройствах. Какую версию сохранить?',
                            style: TextStyle(color: secondaryText),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => ref
                                    .read(syncServiceProvider)
                                    ?.resolve(conflict, keepLocal: true),
                                child: const Text('С этого устройства'),
                              ),
                              OutlinedButton(
                                onPressed: () => ref
                                    .read(syncServiceProvider)
                                    ?.resolve(conflict, keepLocal: false),
                                child: const Text('Из облака'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    message!,
                    style: const TextStyle(color: Color(0xFFFFA0AA)),
                  ),
                ),
              const SizedBox(height: 42),
              const Text(
                'ПАУТИНА · 0.2.0',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
