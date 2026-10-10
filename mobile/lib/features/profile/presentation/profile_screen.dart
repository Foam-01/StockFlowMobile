import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../../core/l10n.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navProfile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              child: Text(
                user.name.characters.first.toUpperCase(),
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Chip(label: Text(user.role.tr(context.l10n)))),
          const SizedBox(height: 24),
          const _LanguagePicker(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('sign_out'),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: Text(context.l10n.signOut),
          ),
        ],
      ),
    );
  }
}

/// English, Thai, or whatever the device uses.
class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider)?.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.language,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: const Key('language'),
          segments: [
            ButtonSegment(value: '', label: Text(context.l10n.languageSystem)),
            const ButtonSegment(value: 'en', label: Text('English')),
            const ButtonSegment(value: 'th', label: Text('ไทย')),
          ],
          selected: {current ?? ''},
          showSelectedIcon: false,
          onSelectionChanged: (v) => ref
              .read(localeProvider.notifier)
              .set(v.first.isEmpty ? null : Locale(v.first)),
        ),
      ],
    );
  }
}
