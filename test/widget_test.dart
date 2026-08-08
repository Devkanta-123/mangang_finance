// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/main.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';

import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';

void main() {
  testWidgets('MainPage renders correctly with drawer and role title',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LoaneeProvider()),
          ChangeNotifierProvider(create: (_) => RoProvider()),
          ChangeNotifierProvider(create: (_) => CollectionSheetProvider()),
        ],
        child: const MaterialApp(
          home: MainPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify main page title
    expect(find.text('Mangang Finance'), findsWidgets);

    // Verify menu button exists
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
  });
}
