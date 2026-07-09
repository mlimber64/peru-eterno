import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/app.dart';
import 'package:provider/provider.dart';
import 'package:peru_eterno/providers/language_provider.dart';
import 'package:peru_eterno/providers/premium_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final languageProvider = LanguageProvider();
    await languageProvider.initialize();
    final premiumProvider = PremiumProvider();
    await premiumProvider.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: languageProvider),
          ChangeNotifierProvider.value(value: premiumProvider),
        ],
        child: const PeruEternoApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
