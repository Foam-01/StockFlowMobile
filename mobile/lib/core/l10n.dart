import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/domain/user.dart';
import '../features/operations/domain/stock_transaction.dart';
import '../features/work_orders/domain/work_order.dart';
import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);
}

/// Strings for code that has no BuildContext (validators, error mapping).
/// Kept in sync with the app's locale by [StockFlowApp]'s builder.
L10n get l10nNow => _current;
L10n _current = lookupL10n(const Locale('en'));
void setCurrentL10n(L10n value) => _current = value;

/// Persists the language chosen in Profile. Thai until the user picks one;
/// choosing "System" (null) follows the device.
class LocaleStore {
  static const _key = 'app_locale';
  static const _system = 'system';
  static const defaultLocale = Locale('th');
  static const _storage = FlutterSecureStorage();

  static Future<Locale?> read() async {
    try {
      final code = await _storage.read(key: _key);
      if (code == null) return defaultLocale;
      return code == _system ? null : Locale(code);
    } catch (_) {
      return defaultLocale;
    }
  }

  static Future<void> write(Locale? locale) async {
    try {
      await _storage.write(key: _key, value: locale?.languageCode ?? _system);
    } catch (_) {
      // Storage unavailable: the choice still applies for this session.
    }
  }
}

/// Language saved on a previous run; loaded in main() before the app starts.
final savedLocaleProvider = Provider<Locale?>((_) => null);

final localeProvider = NotifierProvider<AppLocale, Locale?>(AppLocale.new);

class AppLocale extends Notifier<Locale?> {
  @override
  Locale? build() => ref.watch(savedLocaleProvider);

  Future<void> set(Locale? locale) async {
    state = locale;
    await LocaleStore.write(locale);
  }
}

extension RoleL10n on Role {
  String tr(L10n t) => switch (this) {
    Role.admin => t.roleAdmin,
    Role.staff => t.roleStaff,
    Role.technician => t.roleTechnician,
    Role.supervisor => t.roleSupervisor,
  };
}

extension TxTypeL10n on TxType {
  String tr(L10n t) => switch (this) {
    TxType.receive => t.receive,
    TxType.issue => t.issue,
    TxType.adjust => t.adjust,
  };
}

extension TxStatusL10n on TxStatus {
  String tr(L10n t) => switch (this) {
    TxStatus.draft => t.txDraft,
    TxStatus.confirmed => t.txConfirmed,
    TxStatus.cancelled => t.txCancelled,
  };
}

extension WoStatusL10n on WoStatus {
  String tr(L10n t) => switch (this) {
    WoStatus.open => t.woOpen,
    WoStatus.inProgress => t.woInProgress,
    WoStatus.submitted => t.woSubmitted,
    WoStatus.needsRevision => t.woNeedsRevision,
    WoStatus.approved => t.woApproved,
    WoStatus.cancelled => t.woCancelled,
  };
}

extension WoPriorityL10n on WoPriority {
  String tr(L10n t) => switch (this) {
    WoPriority.low => t.prLow,
    WoPriority.normal => t.prNormal,
    WoPriority.high => t.prHigh,
    WoPriority.urgent => t.prUrgent,
  };
}

extension EvidenceCategoryL10n on EvidenceCategory {
  /// "Before work", "After work", "Other".
  String tr(L10n t) => switch (this) {
    EvidenceCategory.before => t.evBefore,
    EvidenceCategory.after => t.evAfter,
    EvidenceCategory.other => t.evOther,
  };
}

extension WoEventL10n on WoEvent {
  String tr(L10n t) => switch (type) {
    'CREATED' => t.evtCreated,
    'ASSIGNED' => t.evtAssigned,
    'STARTED' => t.evtStarted,
    'CHECKLIST_UPDATED' => t.evtChecklist,
    'EVIDENCE_ADDED' => t.evtPhotoAdded,
    'EVIDENCE_REMOVED' => t.evtPhotoRemoved,
    'SUBMITTED' => t.evtSubmitted,
    'CHANGES_REQUESTED' => t.evtChangesRequested,
    'APPROVED' => t.woApproved,
    'CANCELLED' => t.woCancelled,
    'MATERIAL_ISSUED' => t.evtMaterials,
    _ => type,
  };
}

/// Compact EN / ไทย switch for screens without a Profile (login).
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thai = Localizations.localeOf(context).languageCode == 'th';
    return TextButton.icon(
      key: const Key('language_toggle'),
      icon: const Icon(Icons.translate, size: 18),
      label: Text(thai ? 'English' : 'ภาษาไทย'),
      onPressed: () =>
          ref.read(localeProvider.notifier).set(Locale(thai ? 'en' : 'th')),
    );
  }
}
