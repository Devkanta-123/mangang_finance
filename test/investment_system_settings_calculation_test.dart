// test/investment_system_settings_calculation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mangang_finance/models/investment_model.dart';
import 'package:mangang_finance/models/user_model.dart';
import 'package:mangang_finance/providers/auth_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/screens/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Investment & System Settings Model & Business Logic Tests', () {
    test('InvestmentSettingsModel initializes with defaults matching requirements', () {
      const model = InvestmentSettingsModel();
      expect(model.baseAmount, equals(10000.0));
      expect(model.interestAmount, equals(1500.0));
      expect(model.interestRate, equals(15.0));
    });

    test('InvestmentSettingsModel json serialization and deserialization', () {
      final json = {
        'investment_base_amount': 10000,
        'investment_interest_amount': 1500,
        'investment_interest_rate': 15,
        'updated_at': '2026-08-20T12:00:00.000Z',
      };

      final model = InvestmentSettingsModel.fromJson(json);
      expect(model.baseAmount, equals(10000.0));
      expect(model.interestAmount, equals(1500.0));
      expect(model.interestRate, equals(15.0));
      expect(model.updatedAt, isNotNull);

      final outJson = model.toJson();
      expect(outJson['investment_base_amount'], equals(10000.0));
      expect(outJson['investment_interest_amount'], equals(1500.0));
      expect(outJson['investment_interest_rate'], equals(15.0));
    });

    test('Business rule verification: ₹10,000 -> ₹1,500 interest -> ₹11,500 total', () {
      const settings = InvestmentSettingsModel(
        baseAmount: 10000.0,
        interestAmount: 1500.0,
        interestRate: 15.0,
      );

      final result = InvestmentCalculationResult.calculate(
        amount: 10000.0,
        settings: settings,
        dailyTenureDays: 100,
        weeklyTenureWeeks: 17.5,
      );

      expect(result.investmentAmount, equals(10000.0));
      expect(result.interestRate, equals(15.0));
      expect(result.interestAmount, equals(1500.0));
      expect(result.totalAmount, equals(11500.0));
      expect(result.dailyPlan.totalPayable, equals(11500.0));
      expect(result.dailyPlan.dailyInstallment, equals(115.0)); // 11,500 / 100
      expect(result.weeklyPlan.totalPayable, equals(11500.0));
      expect(result.weeklyPlan.weeklyInstallment, closeTo(657.14, 0.01)); // 11,500 / 17.5
    });

    test('Business rule verification: ₹50,000 -> ₹7,500 interest -> ₹57,500 total', () {
      const settings = InvestmentSettingsModel(
        baseAmount: 10000.0,
        interestAmount: 1500.0,
        interestRate: 15.0,
      );

      final result = InvestmentCalculationResult.calculate(
        amount: 50000.0,
        settings: settings,
        dailyTenureDays: 100,
        weeklyTenureWeeks: 17.5,
      );

      expect(result.investmentAmount, equals(50000.0));
      expect(result.interestRate, equals(15.0));
      expect(result.interestAmount, equals(7500.0));
      expect(result.totalAmount, equals(57500.0));
      expect(result.dailyPlan.dailyInstallment, equals(575.0)); // 57,500 / 100
      expect(result.weeklyPlan.weeklyInstallment, closeTo(3285.71, 0.01)); // 57,500 / 17.5
    });

    test('Business rule verification: ₹1,00,000 -> ₹15,000 interest -> ₹1,15,000 total', () {
      const settings = InvestmentSettingsModel(
        baseAmount: 10000.0,
        interestAmount: 1500.0,
        interestRate: 15.0,
      );

      final result = InvestmentCalculationResult.calculate(
        amount: 100000.0,
        settings: settings,
        dailyTenureDays: 100,
        weeklyTenureWeeks: 17.5,
      );

      expect(result.investmentAmount, equals(100000.0));
      expect(result.interestRate, equals(15.0));
      expect(result.interestAmount, equals(15000.0));
      expect(result.totalAmount, equals(115000.0));
      expect(result.dailyPlan.dailyInstallment, equals(1150.0)); // 115,000 / 100
      expect(result.weeklyPlan.weeklyInstallment, closeTo(6571.43, 0.01)); // 115,000 / 17.5
    });

    test('Dynamic calculation works for ANY custom amount and configured rate in system_settings', () {
      const settingsCustom = InvestmentSettingsModel(
        baseAmount: 20000.0,
        interestAmount: 4000.0,
        interestRate: 20.0, // 20%
      );

      final result = InvestmentCalculationResult.calculate(
        amount: 25000.0,
        settings: settingsCustom,
        dailyTenureDays: 100,
        weeklyTenureWeeks: 17.5,
      );

      expect(result.investmentAmount, equals(25000.0));
      expect(result.interestRate, equals(20.0));
      expect(result.interestAmount, equals(5000.0)); // 25000 * 20% = 5000
      expect(result.totalAmount, equals(30000.0));
      expect(result.dailyPlan.dailyInstallment, equals(300.0)); // 30,000 / 100
    });
  });

  group('SettingsProvider & UI Integration Tests', () {
    test('SettingsProvider calculates investment plan dynamically', () {
      final provider = SettingsProvider();
      final calc10k = provider.calculateInvestmentPlan(10000.0);
      expect(calc10k.interestAmount, equals(1500.0));
      expect(calc10k.totalAmount, equals(11500.0));

      final calc50k = provider.calculateInvestmentPlan(50000.0);
      expect(calc50k.interestAmount, equals(7500.0));
      expect(calc50k.totalAmount, equals(57500.0));

      final calc100k = provider.calculateInvestmentPlan(100000.0);
      expect(calc100k.interestAmount, equals(15000.0));
      expect(calc100k.totalAmount, equals(115000.0));
    });

    testWidgets('SettingsPage renders investment calculation rules and examples', (tester) async {
      final authProvider = AuthProvider();
      authProvider.switchRole(UserType.admin);
      final settingsProvider = SettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Section Header & system_settings DB badge
      expect(find.text('Investment & Interest Rate Rules'), findsOneWidget);
      expect(find.text('system_settings DB'), findsOneWidget);

      // Verify Formula Banner
      expect(find.textContaining('Interest = Investment Amount × 15%'), findsOneWidget);
      expect(find.textContaining('Total = Investment Amount + Interest'), findsOneWidget);

      // Verify Examples
      expect(find.text('₹10,000'), findsWidgets);
      expect(find.text('₹1,500 interest'), findsOneWidget);
      expect(find.text('₹11,500 total'), findsOneWidget);

      expect(find.text('₹50,000'), findsOneWidget);
      expect(find.text('₹7,500 interest'), findsOneWidget);
      expect(find.text('₹57,500 total'), findsOneWidget);

      expect(find.text('₹100,000'), findsOneWidget);
      expect(find.text('₹15,000 interest'), findsOneWidget);
      expect(find.text('₹115,000 total'), findsOneWidget);

      // Verify Live Calculator Simulator
      expect(find.text('Live Any-Amount Investment Calculator'), findsOneWidget);
      expect(find.text('Save Investment Settings to Database'), findsOneWidget);
    });
  });
}
