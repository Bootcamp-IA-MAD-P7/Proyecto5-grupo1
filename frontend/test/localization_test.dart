import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentilife/l10n/generated/app_localizations.dart';
import 'package:sentilife/screens/home_screen.dart';

void main() {
  testWidgets('cambia los textos de español a inglés', (tester) async {
    await tester.pumpWidget(const _LocaleTestApp());

    expect(find.text('Probador del detector de caídas'), findsOneWidget);
    expect(find.text('Iniciar monitoreo'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inglés'));
    await tester.pumpAndSettle();

    expect(find.text('Fall detector tester'), findsOneWidget);
    expect(find.text('Start monitoring'), findsOneWidget);
  });
}

class _LocaleTestApp extends StatefulWidget {
  const _LocaleTestApp();

  @override
  State<_LocaleTestApp> createState() => _LocaleTestAppState();
}

class _LocaleTestAppState extends State<_LocaleTestApp> {
  Locale _locale = const Locale('es');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(
        onLocaleChanged: (locale) => setState(() => _locale = locale),
      ),
    );
  }
}
