import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';

/// Pings `GET /health` on [url]. Returns null when reachable, else a reason.
/// Overridable in tests.
final serverHealthCheckProvider = Provider<Future<String?> Function(String)>(
  (_) => (url) async {
    try {
      final res = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      ).get<Map<String, dynamic>>('$url/health');
      return res.data?['status'] == 'ok' ? null : 'Not a StockFlow server';
    } on DioException catch (e) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          'Cannot reach the server. Same Wi-Fi? Firewall open on port 3000?',
        _ => 'Not a StockFlow server (HTTP ${e.response?.statusCode ?? '?'})',
      };
    }
  },
);

/// Small "Server: …" link on the login screen.
class ServerSettingsButton extends ConsumerWidget {
  const ServerSettingsButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(serverUrlProvider);
    final host = Uri.tryParse(url)?.authority ?? url;
    return TextButton.icon(
      key: const Key('server_settings'),
      onPressed: enabled
          ? () => showDialog<void>(
              context: context,
              builder: (_) => const _ServerDialog(),
            )
          : null,
      icon: const Icon(Icons.dns_outlined, size: 18),
      label: Text('Server: $host'),
    );
  }
}

class _ServerDialog extends ConsumerStatefulWidget {
  const _ServerDialog();

  @override
  ConsumerState<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends ConsumerState<_ServerDialog> {
  late final _url = TextEditingController(text: ref.read(serverUrlProvider));
  final _formKey = GlobalKey<FormState>();
  bool _checking = false;
  String? _result; // null = not tested yet
  bool _ok = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _checking = true;
      _result = null;
    });
    final error = await ref.read(serverHealthCheckProvider)(
      normalizeServerUrl(_url.text),
    );
    if (!mounted) return;
    setState(() {
      _checking = false;
      _ok = error == null;
      _result = error ?? 'Connected';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(serverUrlProvider.notifier).set(_url.text);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _reset() async {
    await ref.read(serverUrlProvider.notifier).reset();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Server'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Address of the StockFlow API. On a phone, use your '
              'computer’s Wi-Fi IP.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('server_url'),
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'API URL',
                hintText: 'http://192.168.1.10:3000',
              ),
              validator: (v) => validateServerUrl(v ?? ''),
              onChanged: (_) => setState(() => _result = null),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('server_test'),
                  onPressed: _checking ? null : _test,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: const Text('Test connection'),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _ok ? Icons.check_circle_outline : Icons.error_outline,
                    size: 18,
                    color: _ok ? scheme.primary : scheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _result!,
                      key: const Key('server_result'),
                      style: TextStyle(color: _ok ? null : scheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _reset,
          child: Text('Default (${Uri.parse(defaultApiBaseUrl).authority})'),
        ),
        FilledButton(
          key: const Key('server_save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
