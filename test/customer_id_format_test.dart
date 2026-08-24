// test/customer_id_format_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/ro_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/ro_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/screens/create_loanee_page.dart';
import 'package:mangang_finance/screens/create_ro_page.dart';
import 'package:mangang_finance/services/customer_id_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomerIdService Format & Sequence Tests', () {
    test('1. First, Second, and Third Loanee Customer IDs follow CUST + YEAR + L + 6-digit sequence', () {
      final now2026 = DateTime(2026, 8, 24);

      // First Loanee -> CUST2026L000001
      final id1 = CustomerIdService.generateLoaneeCustomerId(
        existingLoanees: [],
        now: now2026,
      );
      expect(id1, equals('CUST2026L000001'));

      // Second Loanee -> CUST2026L000002
      final id2 = CustomerIdService.generateLoaneeCustomerId(
        existingIds: [id1],
        now: now2026,
      );
      expect(id2, equals('CUST2026L000002'));

      // Third Loanee -> CUST2026L000003
      final id3 = CustomerIdService.generateLoaneeCustomerId(
        existingIds: [id1, id2],
        now: now2026,
      );
      expect(id3, equals('CUST2026L000003'));
    });

    test('2. First, Second, and Third RO Customer IDs follow CUST + YEAR + RO + 3-digit sequence', () {
      final now2026 = DateTime(2026, 8, 24);

      // First RO -> CUST2026RO001
      final id1 = CustomerIdService.generateRoCustomerId(
        existingRos: [],
        now: now2026,
      );
      expect(id1, equals('CUST2026RO001'));

      // Second RO -> CUST2026RO002
      final id2 = CustomerIdService.generateRoCustomerId(
        existingIds: [id1],
        now: now2026,
      );
      expect(id2, equals('CUST2026RO002'));

      // Third RO -> CUST2026RO003
      final id3 = CustomerIdService.generateRoCustomerId(
        existingIds: [id1, id2],
        now: now2026,
      );
      expect(id3, equals('CUST2026RO003'));
    });

    test('3. Exact zero-padding verification (6 digits for Loanee, 3 digits for RO)', () {
      final now2026 = DateTime(2026, 8, 24);

      // Loanee padding to 6 digits
      final loanee10 = CustomerIdService.formatId(
        isRo: false,
        sequence: 10,
        now: now2026,
      );
      expect(loanee10, equals('CUST2026L000010'));

      final loanee999 = CustomerIdService.formatId(
        isRo: false,
        sequence: 999,
        now: now2026,
      );
      expect(loanee999, equals('CUST2026L000999'));

      final loanee999999 = CustomerIdService.formatId(
        isRo: false,
        sequence: 999999,
        now: now2026,
      );
      expect(loanee999999, equals('CUST2026L999999'));

      // RO padding to 3 digits
      final ro5 = CustomerIdService.formatId(
        isRo: true,
        sequence: 5,
        now: now2026,
      );
      expect(ro5, equals('CUST2026RO005'));

      final ro99 = CustomerIdService.formatId(
        isRo: true,
        sequence: 99,
        now: now2026,
      );
      expect(ro99, equals('CUST2026RO099'));

      final ro999 = CustomerIdService.formatId(
        isRo: true,
        sequence: 999,
        now: now2026,
      );
      expect(ro999, equals('CUST2026RO999'));
    });

    test('4. Dynamic Year handling across year changes (not hardcoded to 2026)', () {
      final now2027 = DateTime(2027, 1, 1);
      final loanee2027 = CustomerIdService.generateLoaneeCustomerId(
        existingLoanees: [],
        now: now2027,
      );
      expect(loanee2027, equals('CUST2027L000001'));

      final ro2027 = CustomerIdService.generateRoCustomerId(
        existingRos: [],
        now: now2027,
      );
      expect(ro2027, equals('CUST2027RO001'));

      final now2030 = DateTime(2030, 6, 15);
      final loanee2030 = CustomerIdService.generateLoaneeCustomerId(
        existingLoanees: [],
        now: now2030,
      );
      expect(loanee2030, equals('CUST2030L000001'));

      final ro2030 = CustomerIdService.generateRoCustomerId(
        existingRos: [],
        now: now2030,
      );
      expect(ro2030, equals('CUST2030RO001'));
    });

    test('5. Separate sequences for Loanee and RO accounts', () {
      final now2026 = DateTime(2026, 8, 24);

      final existingLoanees = [
        LoaneeAccount(
          customerid: 'CUST2026L000001',
          accountnumber: 'ACC-1',
          loaneename: 'Loanee 1',
          guardianname: 'N/A',
          address: 'Imphal',
          businesstype: 'Retail',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000001',
          aadharno: '111122223333',
        ),
        LoaneeAccount(
          customerid: 'CUST2026L000002',
          accountnumber: 'ACC-2',
          loaneename: 'Loanee 2',
          guardianname: 'N/A',
          address: 'Imphal',
          businesstype: 'Retail',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000002',
          aadharno: '111122223334',
        ),
      ];

      final existingRos = [
        RoAccount(
          customerid: 'CUST2026RO001',
          accountnumber: 'RO-ACC-1',
          roname: 'RO 1',
          guardianname: 'N/A',
          address: 'Imphal',
          designation: 'Recovery Officer',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000010',
          aadharno: '222233334444',
        ),
      ];

      final nextLoaneeId = CustomerIdService.generateLoaneeCustomerId(
        existingLoanees: existingLoanees,
        now: now2026,
      );
      final nextRoId = CustomerIdService.generateRoCustomerId(
        existingRos: existingRos,
        now: now2026,
      );

      // Loanee sequence advances to 000003, RO sequence advances to 002
      expect(nextLoaneeId, equals('CUST2026L000003'));
      expect(nextRoId, equals('CUST2026RO002'));
    });

    test('6. Existing legacy Customer IDs are preserved without affecting new format generation', () {
      final now2026 = DateTime(2026, 8, 24);

      final legacyLoanees = [
        LoaneeAccount(
          customerid: 'CUST-1001',
          accountnumber: 'ACC-88239101',
          loaneename: 'Legacy Loanee 1',
          guardianname: 'N/A',
          address: 'Imphal',
          businesstype: 'Retail',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000001',
          aadharno: '111122223333',
        ),
        LoaneeAccount(
          customerid: 'CUST-1002',
          accountnumber: 'ACC-88239102',
          loaneename: 'Legacy Loanee 2',
          guardianname: 'N/A',
          address: 'Imphal',
          businesstype: 'Retail',
          postoffice: 'Imphal',
          policestation: 'Imphal',
          district: 'Imphal West',
          pincode: '795001',
          mobileno: '9862000002',
          aadharno: '111122223334',
        ),
      ];

      // Legacy records stay unchanged
      expect(legacyLoanees[0].customerId, equals('CUST-1001'));
      expect(legacyLoanees[1].customerId, equals('CUST-1002'));

      // New generated ID adopts the new format CUST2026L000001
      final newId = CustomerIdService.generateLoaneeCustomerId(
        existingLoanees: legacyLoanees,
        now: now2026,
      );
      expect(newId, equals('CUST2026L000001'));
    });

    test('7. Sequence progression across gaps and duplicate prevention', () {
      final now2026 = DateTime(2026, 8, 24);
      final existingIds = ['CUST2026L000001', 'CUST2026L000005', 'CUST2026L000010'];

      final nextId = CustomerIdService.generateLoaneeCustomerId(
        existingIds: existingIds,
        now: now2026,
      );
      expect(nextId, equals('CUST2026L000011'));
    });

    test('8. Batch and concurrent ID generation with reserved IDs guarantees zero collisions', () {
      final now2026 = DateTime(2026, 8, 24);

      final batch = CustomerIdService.generateLoaneeCustomerIdsBatch(
        5,
        now: now2026,
      );

      expect(batch, equals([
        'CUST2026L000001',
        'CUST2026L000002',
        'CUST2026L000003',
        'CUST2026L000004',
        'CUST2026L000005',
      ]));

      // If CUST2026L000006 is reserved in-flight, next generated ID is CUST2026L000007
      final nextWithReserved = CustomerIdService.generateLoaneeCustomerId(
        existingIds: batch,
        reservedIds: {'CUST2026L000006'},
        now: now2026,
      );
      expect(nextWithReserved, equals('CUST2026L000007'));
    });

    test('9. Validation functions recognize new, variant, and legacy formats', () {
      expect(CustomerIdService.isValidLoaneeCustomerId('CUST2026L000001'), isTrue);
      expect(CustomerIdService.isValidLoaneeCustomerId('CUST2027L000099'), isTrue);
      expect(CustomerIdService.isValidLoaneeCustomerId('CUSTL202600001'), isTrue);
      expect(CustomerIdService.isValidLoaneeCustomerId('CUST-1001'), isTrue);
      expect(CustomerIdService.isValidLoaneeCustomerId('INVALID-ID'), isFalse);

      expect(CustomerIdService.isValidRoCustomerId('CUST2026RO001'), isTrue);
      expect(CustomerIdService.isValidRoCustomerId('CUST2027RO099'), isTrue);
      expect(CustomerIdService.isValidRoCustomerId('CUSTRO202600001'), isTrue);
      expect(CustomerIdService.isValidRoCustomerId('RO-CUST-5001'), isTrue);
      expect(CustomerIdService.isValidRoCustomerId('INVALID-ID'), isFalse);
    });
  });

  group('Provider & UI Integration Tests for Customer ID Format', () {
    test('10. LoaneeProvider and RoProvider generate new Customer ID formats', () {
      final loaneeProvider = LoaneeProvider();
      final roProvider = RoProvider();

      final currentYear = DateTime.now().year;

      final loaneeId = loaneeProvider.generateNextCustomerId();
      expect(loaneeId, startsWith('CUST${currentYear}L'));
      expect(loaneeId.length, equals(15)); // CUST (4) + 2026 (4) + L (1) + 000001 (6) = 15

      final roId = roProvider.generateNextCustomerId();
      expect(roId, startsWith('CUST${currentYear}RO'));
      expect(roId.length, equals(13)); // CUST (4) + 2026 (4) + RO (2) + 001 (3) = 13
    });

    testWidgets('11. CreateLoaneePage initializes with new format CUST[YEAR]L000001', (tester) async {
      final currentYear = DateTime.now().year;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LoaneeProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: const MaterialApp(
            home: CreateLoaneePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check text field has generated Customer ID matching CUST{currentYear}L000001
      final customerIdFinder = find.byWidgetPredicate((widget) {
        return widget is TextFormField &&
            widget.controller?.text.startsWith('CUST${currentYear}L') == true;
      });

      expect(customerIdFinder, findsOneWidget);
    });

    testWidgets('12. CreateRoPage initializes with new format CUST[YEAR]RO001', (tester) async {
      final currentYear = DateTime.now().year;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => RoProvider()),
            ChangeNotifierProvider(create: (_) => CollectionSheetProvider()),
          ],
          child: const MaterialApp(
            home: CreateRoPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check text field has generated Customer ID matching CUST{currentYear}RO001
      final customerIdFinder = find.byWidgetPredicate((widget) {
        return widget is TextFormField &&
            widget.controller?.text.startsWith('CUST${currentYear}RO') == true;
      });

      expect(customerIdFinder, findsOneWidget);
    });
  });
}
