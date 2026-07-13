import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';

void main() {
  test('las traducciones cargan es/en con las claves correctas', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(es.startMonitoring, 'Iniciar monitoreo');
    expect(en.startMonitoring, 'Start monitoring');

    expect(es.fallDetectorTester, 'Probador del detector de caídas');
    expect(en.fallDetectorTester, 'Fall detector tester');

    expect(es.revokeConsent, 'Revocar consentimiento');
    expect(en.revokeConsent, 'Revoke consent');

    expect(es.userActive, 'Activo');
    expect(en.userActive, 'Active');
  });
}
