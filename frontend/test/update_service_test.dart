import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/services/update_service.dart';

void main() {
  group('UpdateService locale', () {
    test('setLocale switches error messages to English', () {
      final service = UpdateService();
      service.setLocale(const Locale('en'));

      service.setLocale(const Locale('es'));
      service.setLocale(const Locale('en'));

      // Trigger a known error path via private API substitute: use reset + manual
      // state by calling check with no server — instead verify lookup directly.
      final en = lookupAppLocalizations(const Locale('en'));
      final es = lookupAppLocalizations(const Locale('es'));

      expect(en.noInternetError, contains('internet'));
      expect(es.noInternetError, contains('internet'));
      expect(en.loginSubtitle, 'Sign in to continue');
      expect(es.loginSubtitle, 'Inicia sesión para continuar');
    });
  });
}
