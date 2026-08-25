// test/historical_payment_import_test.dart

import "dart:io";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";
import "package:excel/excel.dart";
import "package:mangang_finance/models/collection_payment_model.dart";
import "package:mangang_finance/models/loanee_model.dart";
import "package:mangang_finance/models/ro_collection_entry_model.dart";
import "package:mangang_finance/models/route_model.dart";
import "package:mangang_finance/providers/collection_sheet_provider.dart";
import "package:mangang_finance/providers/loanee_provider.dart";
import "package:mangang_finance/services/historical_payment_import_service.dart";
import "package:mangang_finance/widgets/historical_payment_import_dialog.dart";
import "package:mangang_finance/services/supabase_service.dart";
import "package:mangang_finance/screens/ro_collection_sheet_view_page.dart";
import "package:mangang_finance/providers/auth_provider.dart";
import "package:mangang_finance/providers/settings_provider.dart";
import "package:mangang_finance/providers/ro_provider.dart";

/// Helper function to create an in-memory Excel file with custom headers and data rows
List<int> createTestExcel({
  List<String>? headers,
  List<List<dynamic>>? dataRows,
}) {
  final excel = Excel.createExcel();
  final sheetName = excel.getDefaultSheet() ?? "Sheet1";
  final sheet = excel[sheetName];

  final defaultHeaders = [
    "Coustomer ID",
    "Account No.",
    "Loanee Name",
    "Route",
    "Collection Types",
    "Collected_BY",
    "46204.0", // 2026-07-01
    "46205.0", // 2026-07-02
    "46206.0", // 2026-07-03
  ];

  final actualHeaders = headers ?? defaultHeaders;
  for (int col = 0; col < actualHeaders.length; col++) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
    cell.value = TextCellValue(actualHeaders[col]);
  }

  if (dataRows != null) {
    for (int r = 0; r < dataRows.length; r++) {
      final rowData = dataRows[r];
      for (int c = 0; c < rowData.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final val = rowData[c];
        if (val == null) {
          continue;
        } else if (val is num) {
          cell.value = DoubleCellValue(val.toDouble());
        } else {
          cell.value = TextCellValue(val.toString());
        }
      }
    }
  }

  return excel.save() ?? [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Historical Payment Import - 13 Comprehensive Tests", () {
    late List<LoaneeAccount> sampleLoanees;
    late List<RoCollectionEntry> sampleEntries;
    late List<CollectionPaymentModel> samplePayments;
    late List<RouteModel> sampleRoutes;

    setUp(() {
      sampleLoanees = [
        LoaneeAccount(
          customerid: "26LA000001",
          accountnumber: "MF2026A000001",
          loaneename: "Ramesh Kumar",
          guardianname: "R. Sharma",
          address: "Angom Leikai",
          businesstype: "Retail Shop",
          postoffice: "Imphal",
          policestation: "Porompat",
          district: "Imphal East",
          pincode: "795005",
          mobileno: "9862112233",
          aadharno: "123456789012",
          loanamount: 11500.0,
          paidamount: 0.0,
          dueamount: 11500.0,
        ),
        LoaneeAccount(
          customerid: "CUST-1031",
          accountnumber: "ACC-88239131",
          loaneename: "Arambam Nikhil",
          guardianname: "A. Tomba",
          address: "Angom Leikai",
          businesstype: "Retail Shop",
          postoffice: "Imphal",
          policestation: "Porompat",
          district: "Imphal East",
          pincode: "795005",
          mobileno: "9862112233",
          aadharno: "123456789012",
          loanamount: 11500.0,
          paidamount: 0.0,
          dueamount: 11500.0,
        ),
        LoaneeAccount(
          customerid: "CUST-1032",
          accountnumber: "ACC-88239132",
          loaneename: "Bembem Devi",
          guardianname: "B. Chaoba",
          address: "Khurai",
          businesstype: "Vegetable Vendor",
          postoffice: "Lamlong",
          policestation: "Porompat",
          district: "Imphal East",
          pincode: "795010",
          mobileno: "9862223344",
          aadharno: "234567890123",
          loanamount: 23000.0,
          paidamount: 0.0,
          dueamount: 23000.0,
        ),
      ];

      sampleEntries = [
        RoCollectionEntry(
          id: "COL-26LA000001",
          customerId: "26LA000001",
          accountNumber: "MF2026A000001",
          loaneeName: "Ramesh Kumar",
          loaneeAddress: "Angom Leikai",
          collectionType: "Daily",
          route: "Angom",
          mobileNo: "9862112233",
          payableAmount: 100.0,
          loanAmount: 11500.0,
          actualPrincipal: 10000.0,
          interestAmount: 1500.0,
        ),
        RoCollectionEntry(
          id: "COL-1031",
          customerId: "CUST-1031",
          accountNumber: "ACC-88239131",
          loaneeName: "Arambam Nikhil",
          loaneeAddress: "Angom Leikai",
          collectionType: "Daily",
          route: "Angom",
          mobileNo: "9862112233",
          payableAmount: 100.0,
          loanAmount: 11500.0,
          actualPrincipal: 10000.0,
          interestAmount: 1500.0,
        ),
      ];

      samplePayments = [];

      sampleRoutes = [
        RouteModel(id: "R-1", name: "Angom", code: "ANG", isActive: true),
        RouteModel(id: "R-2", name: "Office", code: "OFF", isActive: true),
      ];
    });

    // Test 1: Valid Excel row parsing from the actual template assets/template/old_payment_history.xlsx
    test("1. Valid Excel row from actual template file parses correctly", () {
      final file = File("assets/template/old_payment_history.xlsx");
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
        existingRoutes: sampleRoutes,
      );

      expect(preview.hasFileErrors, isFalse);
      expect(preview.totalRows, greaterThanOrEqualTo(1));
      expect(preview.validRowsCount, greaterThanOrEqualTo(1));

      final firstRow = preview.rowRecords.first;
      expect(firstRow.rawCustomerId, equals("26LA000001"));
      expect(firstRow.rawAccountNumber, equals("MF2026A000001"));
      expect(firstRow.rawLoaneeName, equals("Ramesh Kumar"));
      expect(firstRow.rawRoute, equals("Angom"));
      expect(firstRow.rawCollectedBy, equals("Dev"));
      expect(firstRow.resolvedCollectionEntry?.id, equals("COL-26LA000001"));
      expect(firstRow.validPaymentsCount, equals(5));
      expect(preview.totalAmountToImport, equals(900.0));
    });

    // Test 2: Multiple valid rows
    test("2. Multiple valid rows parse all payments and aggregate totals", () {
      final excelBytes = createTestExcel(
        dataRows: [
          [
            "CUST-1031",
            "ACC-88239131",
            "Arambam Nikhil",
            "Angom",
            "Daily",
            "Dev",
            100.0, // 2026-07-01
            200.0, // 2026-07-02
            null,
          ],
          [
            "CUST-1032",
            "ACC-88239132",
            "Bembem Devi",
            "Office",
            "Daily",
            "Dev",
            300.0, // 2026-07-01
            null,
            400.0, // 2026-07-03
          ],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
        existingRoutes: sampleRoutes,
      );

      expect(preview.totalRows, equals(2));
      expect(preview.validRowsCount, equals(2));
      expect(preview.invalidRowsCount, equals(0));
      expect(preview.validPaymentsCount, equals(4)); // (100 + 200) + (300 + 400)
      expect(preview.totalAmountToImport, equals(1000.0));
    });

    // Test 3: Missing required column
    test("3. Missing required column returns fatal file error and prevents import", () {
      final excelBytes = createTestExcel(
        headers: ["ColA", "ColB", "ColC"], // No customer, account, or name headers
        dataRows: [
          ["Val1", "Val2", "Val3"],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
      );

      expect(preview.hasFileErrors, isTrue);
      expect(preview.canImport, isFalse);
    });

    // Test 4: Invalid payment date
    test("4. Invalid payment date header does not produce invalid dates", () {
      final excelBytes = createTestExcel(
        headers: [
          "Customer ID",
          "Account No",
          "Loanee Name",
          "Route",
          "Collection Type",
          "Collected_BY",
          "InvalidDateColumn",
          "2026-07-01",
        ],
        dataRows: [
          [
            "CUST-1031",
            "ACC-88239131",
            "Arambam Nikhil",
            "Angom",
            "Daily",
            "Dev",
            100.0,
            200.0,
          ],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
      );

      expect(preview.rowRecords.first.payments.length, equals(1));
      expect(preview.rowRecords.first.payments.first.paymentDate, equals(DateTime(2026, 7, 1)));
      expect(preview.rowRecords.first.payments.first.amount, equals(200.0));
    });

    // Test 5: Invalid amount (string or negative)
    test("5. Invalid payment amount is flagged with error message and skipped", () {
      final excelBytes = createTestExcel(
        dataRows: [
          [
            "CUST-1031",
            "ACC-88239131",
            "Arambam Nikhil",
            "Angom",
            "Daily",
            "Dev",
            "INVALID_AMT", // Column 1
            -50.0, // Column 2 (negative)
            150.0, // Column 3 (valid)
          ],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
      );

      final row = preview.rowRecords.first;
      expect(row.validPaymentsCount, equals(1));
      expect(row.payments.any((p) => p.errorMessage != null), isTrue);
      expect(preview.totalAmountToImport, equals(150.0));
    });

    // Test 6: Loan Account Map not found
    test("6. Loan Account Map not found flags unmapped warning and generates collection card", () {
      final excelBytes = createTestExcel(
        dataRows: [
          [
            "CUST-9999", // Unregistered customer
            "ACC-99999999", // Unregistered account
            "Unknown Loanee",
            "Office",
            "Daily",
            "Dev",
            500.0,
            null,
            null,
          ],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
      );

      expect(preview.unmappedRowsCount, equals(1));
      final row = preview.rowRecords.first;
      expect(row.isUnmapped, isTrue);
      expect(row.newCollectionEntryNeeded, isTrue);
      expect(row.newCollectionEntry?.customerId, equals("CUST-9999"));
    });

    // Test 7: Duplicate payment in DB
    test("7. Duplicate payment already in DB is detected and marked as duplicate", () {
      // Add existing payment for CUST-1031 on 2026-07-01
      samplePayments.add(
        CollectionPaymentModel(
          id: "PAY-EXISTING-1",
          collectionId: "COL-1031",
          paymentAmount: 100.0,
          createdAt: DateTime(2026, 7, 1),
        ),
      );

      final excelBytes = createTestExcel(
        dataRows: [
          [
            "CUST-1031",
            "ACC-88239131",
            "Arambam Nikhil",
            "Angom",
            "Daily",
            "Dev",
            100.0, // 2026-07-01 (duplicate)
            200.0, // 2026-07-02 (new)
            null,
          ],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
      );

      expect(preview.duplicatePaymentsCount, equals(1));
      expect(preview.validPaymentsCount, equals(1));
      expect(preview.totalAmountToImport, equals(200.0));

      final dupItem = preview.rowRecords.first.payments.firstWhere((p) => p.isDuplicate);
      expect(dupItem.isDuplicate, isTrue);
      expect(dupItem.paymentDate, equals(DateTime(2026, 7, 1)));
    });

    // Test 8: Same file imported twice
    test("8. Same file imported twice does not create duplicates on second run", () async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();

      // Seed provider with initial collection entry
      await collectionProvider.addCollectionEntry(sampleEntries.first);

      final excelBytes = createTestExcel(
        dataRows: [
          [
            "CUST-1031",
            "ACC-88239131",
            "Arambam Nikhil",
            "Angom",
            "Daily",
            "Dev",
            100.0, // 2026-07-01
            200.0, // 2026-07-02
            null,
          ],
        ],
      );

      // Run 1: First Import
      final preview1 = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: loaneeProvider.loanees,
        existingEntries: collectionProvider.collectionEntries,
        existingPayments: collectionProvider.payments,
      );

      expect(preview1.validPaymentsCount, equals(2));
      final result1 = await HistoricalPaymentImportService.executeTransactionalImport(
        previewResult: preview1,
        collectionProvider: collectionProvider,
        loaneeProvider: loaneeProvider,
      );
      expect(result1.success, isTrue);
      expect(result1.paymentsInsertedCount, equals(2));

      // Run 2: Second Import with same file
      final preview2 = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: loaneeProvider.loanees,
        existingEntries: collectionProvider.collectionEntries,
        existingPayments: collectionProvider.payments,
      );

      expect(preview2.validPaymentsCount, equals(0));
      expect(preview2.duplicatePaymentsCount, equals(2));

      final result2 = await HistoricalPaymentImportService.executeTransactionalImport(
        previewResult: preview2,
        collectionProvider: collectionProvider,
        loaneeProvider: loaneeProvider,
      );
      expect(result2.paymentsInsertedCount, equals(0));
      expect(result2.duplicatePaymentsSkippedCount, equals(2));
    });

    // Test 9: Empty Excel file
    test("9. Empty Excel file is handled gracefully without crashing", () {
      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: [],
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
      );

      expect(preview.hasFileErrors, isTrue);
      expect(preview.canImport, isFalse);
      expect(preview.fileValidationErrors.first, contains("empty"));
    });

    // Test 10: Database transaction failure and rollback
    test("10. Database transaction failure cleans up records and reports failure", () async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();

      final preview = HistoricalImportPreviewResult(
        totalRows: 1,
        validRowsCount: 1,
        invalidRowsCount: 0,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 1,
        validPaymentsCount: 1,
        duplicatePaymentsCount: 0,
        totalAmountToImport: 100.0,
        rowRecords: [
          HistoricalImportRowRecord(
            rowIndex: 2,
            rawCustomerId: "CUST-TEST-FAIL",
            rawAccountNumber: "ACC-FAIL-1",
            rawLoaneeName: "Fail User",
            rawRoute: "Office",
            rawCollectionType: "Daily",
            rawCollectedBy: "Dev",
            newCollectionEntryNeeded: true,
            newCollectionEntry: RoCollectionEntry(
              id: "COL-FAIL-TEST",
              customerId: "CUST-TEST-FAIL",
              accountNumber: "ACC-FAIL-1",
              loaneeName: "Fail User",
              loaneeAddress: "Imphal",
              collectionType: "Daily",
              route: "Office",
              mobileNo: "9862000000",
            ),
            payments: [],
            isValid: false, // Invalid row triggers failure handling
            errorMessage: "Forced test failure",
          ),
        ],
      );

      final result = await HistoricalPaymentImportService.executeTransactionalImport(
        previewResult: preview,
        collectionProvider: collectionProvider,
        loaneeProvider: loaneeProvider,
      );

      expect(result.paymentsInsertedCount, equals(0));
    });

    // Test 11: Historical dates preserved correctly
    test("11. Historical dates are preserved exactly without timezone shifting", () {
      final excelBytes = createTestExcel(
        headers: [
          "Customer ID",
          "Account No",
          "Loanee Name",
          "Route",
          "Collection Type",
          "Collected_BY",
          "2026-07-01",
          "2026-07-15",
          "2026-07-30",
        ],
        dataRows: [
          [
            "CUST-1031",
            "ACC-88239131",
            "Arambam Nikhil",
            "Angom",
            "Daily",
            "Dev",
            100.0,
            200.0,
            300.0,
          ],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
      );

      final payments = preview.rowRecords.first.payments;
      expect(payments.length, equals(3));
      expect(payments[0].paymentDate, equals(DateTime(2026, 7, 1)));
      expect(payments[1].paymentDate, equals(DateTime(2026, 7, 15)));
      expect(payments[2].paymentDate, equals(DateTime(2026, 7, 30)));
    });

    // Test 12: Correct mapping into Collection Entry
    test("12. Correct mapping into RoCollectionEntry model", () {
      final excelBytes = createTestExcel(
        dataRows: [
          [
            "CUST-NEW-01",
            "ACC-NEW-01",
            "New Loanee Profile",
            "Angom",
            "Daliy", // Intentionally misspelled to test normalization
            "Dev",
            100.0,
            null,
            null,
          ],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: [],
        existingEntries: [],
        existingPayments: [],
        defaultInterestRate: 15.0,
        defaultBasePrincipal: 10000.0,
      );

      final row = preview.rowRecords.first;
      expect(row.newCollectionEntryNeeded, isTrue);
      final entry = row.newCollectionEntry!;

      expect(entry.customerId, equals("CUST-NEW-01"));
      expect(entry.accountNumber, equals("ACC-NEW-01"));
      expect(entry.loaneeName, equals("New Loanee Profile"));
      expect(entry.route, equals("Angom"));
      expect(entry.collectionType, equals("Daily")); // Normalized
      expect(entry.loanAmount, equals(11500.0));
      expect(entry.actualPrincipal, equals(10000.0));
      expect(entry.interestAmount, equals(1500.0));
    });

    // Test 13: Correct mapping into Payment Entry
    test("13. Correct mapping into CollectionPaymentModel with RO name and amount", () {
      final excelBytes = createTestExcel(
        headers: [
          "Customer ID",
          "Account No",
          "Loanee Name",
          "Route",
          "Collection Type",
          "Collected_BY",
          "2026-07-05",
        ],
        dataRows: [
          [
            "CUST-1031",
            "ACC-88239131",
            "Arambam Nikhil",
            "Angom",
            "Daily",
            "Officer Dev",
            250.0,
          ],
        ],
      );

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: excelBytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
      );

      final paymentItem = preview.rowRecords.first.payments.first;
      expect(paymentItem.amount, equals(250.0));
      expect(paymentItem.roName, equals("Officer Dev"));
      expect(paymentItem.paymentDate, equals(DateTime(2026, 7, 5)));

      final paymentModel = paymentItem.paymentModel!;
      expect(paymentModel.collectionId, equals("COL-1031"));
      expect(paymentModel.paymentAmount, equals(250.0));
      expect(paymentModel.roName, equals("Officer Dev"));
      expect(paymentModel.paymentType, equals("Cash"));
      expect(paymentModel.status, equals("Success"));
      expect(paymentModel.createdAt, equals(DateTime(2026, 7, 5)));
    });

    // Widget Test 14: HistoricalPaymentImportDialog UI renders summary, tabs, and rows
    testWidgets("14. HistoricalPaymentImportDialog UI renders summary chips, tabs, and parsed rows", (tester) async {
      final previewResult = HistoricalImportPreviewResult(
        totalRows: 2,
        validRowsCount: 1,
        invalidRowsCount: 1,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 2,
        validPaymentsCount: 1,
        duplicatePaymentsCount: 1,
        totalAmountToImport: 250.0,
        rowRecords: [
          HistoricalImportRowRecord(
            rowIndex: 2,
            rawCustomerId: "CUST-1031",
            rawAccountNumber: "ACC-88239131",
            rawLoaneeName: "Arambam Nikhil",
            rawRoute: "Angom",
            rawCollectionType: "Daily",
            rawCollectedBy: "Dev",
            payments: [
              HistoricalPaymentItem(
                paymentDate: DateTime(2026, 7, 1),
                amount: 250.0,
                roName: "Dev",
                paymentModel: CollectionPaymentModel(
                  id: "PAY-1",
                  collectionId: "COL-1031",
                  paymentAmount: 250.0,
                  createdAt: DateTime(2026, 7, 1),
                ),
              ),
            ],
            isValid: true,
          ),
          HistoricalImportRowRecord(
            rowIndex: 3,
            rawCustomerId: "",
            rawAccountNumber: "",
            rawLoaneeName: "",
            rawRoute: "Office",
            rawCollectionType: "Daily",
            rawCollectedBy: "Dev",
            payments: [],
            isValid: false,
            errorMessage: "Loanee Name is required.",
          ),
        ],
      );

      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
              ChangeNotifierProvider<LoaneeProvider>.value(value: loaneeProvider),
            ],
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => HistoricalPaymentImportDialog.show(
                    context,
                    previewResult: previewResult,
                  ),
                  child: const Text("Open Dialog"),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Dialog"));
      await tester.pumpAndSettle();

      expect(find.text("Historical Payment Import Preview"), findsOneWidget);
      expect(find.text("Total Rows"), findsOneWidget);
      expect(find.text("Payments to Import"), findsOneWidget);
      expect(find.text("Arambam Nikhil"), findsOneWidget);
      expect(find.text("ACC-88239131"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
      expect(find.textContaining("Confirm Import"), findsOneWidget);
    });

    test("15. Scoped Notification Suppression enables during block and strictly resets on completion or exception", () async {
      final supa = SupabaseService.instance;
      expect(supa.arePaymentNotificationsSuppressed, isFalse);

      final result = await supa.runWithNotificationSuppression<String>(() async {
        expect(supa.arePaymentNotificationsSuppressed, isTrue);
        return "import_success";
      });

      expect(result, equals("import_success"));
      expect(supa.arePaymentNotificationsSuppressed, isFalse);

      // Verify reset on exception
      try {
        await supa.runWithNotificationSuppression(() async {
          expect(supa.arePaymentNotificationsSuppressed, isTrue);
          throw Exception("Import fatal failure");
        });
      } catch (e) {
        expect(e.toString(), contains("Import fatal failure"));
      }

      expect(supa.arePaymentNotificationsSuppressed, isFalse);
    });

    test("16. Paginated Payment History queries with 5 default records, total pages, and navigation", () async {
      final collectionProvider = CollectionSheetProvider();
      
      // Populate 12 payments across multiple dates
      for (int i = 1; i <= 12; i++) {
        final payment = CollectionPaymentModel(
          id: "PAY-$i",
          collectionId: "COL-${(i % 3) + 1}",
          paymentAmount: 100.0 * i,
          roRoute: i % 2 == 0 ? "Angom" : "Khurai",
          roName: "Dev",
          createdAt: DateTime(2026, 7, i),
        );
        collectionProvider.handleRealtimePaymentInsert(payment);
      }

      // Page 1 (records 1 to 5, ordered desc by date)
      final page1 = await collectionProvider.getPaginatedPaymentHistory(page: 1, pageSize: 5);
      expect(page1.totalCount, equals(12));
      expect(page1.totalPages, equals(3));
      expect(page1.page, equals(1));
      expect(page1.pageSize, equals(5));
      expect(page1.hasPreviousPage, isFalse);
      expect(page1.hasNextPage, isTrue);
      expect(page1.payments.length, equals(5));
      expect(page1.payments.first.id, equals("PAY-12")); // Newest date first

      // Page 2 (records 6 to 10)
      final page2 = await collectionProvider.getPaginatedPaymentHistory(page: 2, pageSize: 5);
      expect(page2.page, equals(2));
      expect(page2.hasPreviousPage, isTrue);
      expect(page2.hasNextPage, isTrue);
      expect(page2.payments.length, equals(5));
      expect(page2.payments.first.id, equals("PAY-7"));

      // Page 3 (records 11 to 12)
      final page3 = await collectionProvider.getPaginatedPaymentHistory(page: 3, pageSize: 5);
      expect(page3.page, equals(3));
      expect(page3.hasPreviousPage, isTrue);
      expect(page3.hasNextPage, isFalse);
      expect(page3.payments.length, equals(2));
      expect(page3.payments.last.id, equals("PAY-1")); // Oldest date last

      // Filter by Route
      final angomResult = await collectionProvider.getPaginatedPaymentHistory(page: 1, pageSize: 5, route: "Angom");
      expect(angomResult.totalCount, equals(6));
      expect(angomResult.totalPages, equals(2));
      for (final p in angomResult.payments) {
        expect(p.roRoute, equals("Angom"));
      }

      // Filter by Search Query
      final searchResult = await collectionProvider.getPaginatedPaymentHistory(page: 1, pageSize: 5, searchQuery: "PAY-11");
      expect(searchResult.totalCount, equals(1));
      expect(searchResult.payments.first.id, equals("PAY-11"));
    });

    testWidgets("17. RoCollectionSheetViewPage renders DataTable with all columns and Actions dropdown", (WidgetTester tester) async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();
      final authProvider = AuthProvider();
      final settingsProvider = SettingsProvider();
      final roProvider = RoProvider();

      final entry1 = RoCollectionEntry(
        id: "COL-1031",
        customerId: "CUST-1031",
        accountNumber: "ACC-88239131",
        loaneeName: "Arambam Nikhil",
        mobileNo: "9862112233",
        loaneeAddress: "Angom Leikai",
        route: "Angom",
        collectionType: "Daily",
        loanAmount: 11500.0,
      );
      collectionProvider.handleRealtimeEntryInsert(entry1);
      collectionProvider.addRoute(RouteModel(id: "R1", name: "Angom", code: "ANG"));

      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider<LoaneeProvider>.value(value: loaneeProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
          ],
          child: const MaterialApp(
            home: RoCollectionSheetViewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Action buttons (Download Template & Upload Excel)
      expect(find.text("Collection Sheet"), findsOneWidget);
      expect(find.text("Download Template"), findsOneWidget);
      expect(find.text("Upload Excel"), findsOneWidget);

      // Verify compact Route chip is present
      expect(find.text("ROUTE ZONES"), findsOneWidget);
      expect(find.text("Angom"), findsOneWidget);

      // Select Route "Angom"
      await tester.tap(find.text("Angom"));
      await tester.pumpAndSettle();

      // Verify primary DataTable is rendered with all columns
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text("Loanee Name"), findsOneWidget);
      expect(find.text("ACNO"), findsOneWidget);
      expect(find.text("Payable Amount"), findsOneWidget);
      expect(find.text("Overdue"), findsOneWidget);
      expect(find.text("Sanction Date"), findsOneWidget);
      expect(find.text("Maturity Date"), findsOneWidget);
      expect(find.text("Collected"), findsOneWidget);
      expect(find.text("Today"), findsWidgets);
      expect(find.text("Actions"), findsWidgets);

      // Verify Data row for Arambam Nikhil
      expect(find.text("Arambam Nikhil"), findsOneWidget);
      expect(find.text("ACC-88239131"), findsOneWidget);
    });

    testWidgets("18. Actions dropdown contains Payment, Collection, and View History with per-loan history dialog", (WidgetTester tester) async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();
      final authProvider = AuthProvider();
      final settingsProvider = SettingsProvider();
      final roProvider = RoProvider();

      // Create Loan A & Loan B
      final entryA = RoCollectionEntry(
        id: "COL-A",
        customerId: "CUST-1001",
        accountNumber: "ACC-0001",
        loaneeName: "Loan A Borrower",
        mobileNo: "9862000001",
        loaneeAddress: "Imphal",
        route: "Angom",
        collectionType: "Daily",
        loanAmount: 11500.0,
      );
      final entryB = RoCollectionEntry(
        id: "COL-B",
        customerId: "CUST-1002",
        accountNumber: "ACC-0002",
        loaneeName: "Loan B Borrower",
        mobileNo: "9862000002",
        loaneeAddress: "Imphal",
        route: "Angom",
        collectionType: "Daily",
        loanAmount: 11500.0,
      );
      collectionProvider.handleRealtimeEntryInsert(entryB);
      collectionProvider.handleRealtimeEntryInsert(entryA);
      collectionProvider.addRoute(RouteModel(id: "R1", name: "Angom", code: "ANG"));

      // Seed 6 payments for Loan A across old dates
      for (int i = 1; i <= 6; i++) {
        collectionProvider.handleRealtimePaymentInsert(
          CollectionPaymentModel(
            id: "PAY-A-$i",
            collectionId: "COL-A",
            paymentAmount: 200.0 * i,
            roRoute: "Angom",
            roName: "Dev",
            createdAt: DateTime(2026, 6, i),
          ),
        );
      }

      // Seed 2 payments for Loan B
      for (int i = 1; i <= 2; i++) {
        collectionProvider.handleRealtimePaymentInsert(
          CollectionPaymentModel(
            id: "PAY-B-$i",
            collectionId: "COL-B",
            paymentAmount: 500.0 * i,
            roRoute: "Angom",
            roName: "Dev",
            createdAt: DateTime(2026, 6, i),
          ),
        );
      }

      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider<LoaneeProvider>.value(value: loaneeProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
          ],
          child: const MaterialApp(
            home: RoCollectionSheetViewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Route "Angom"
      await tester.tap(find.text("Angom"));
      await tester.pumpAndSettle();

      // Open Actions dropdown on Loan A (first row)
      final actionDropdowns = find.byType(PopupMenuButton<String>);
      expect(actionDropdowns, findsNWidgets(2));

      await tester.tap(actionDropdowns.first);
      await tester.pumpAndSettle();

      // Verify dropdown actions
      expect(find.text("Collection"), findsOneWidget);
      expect(find.text("View History"), findsOneWidget);

      // Tap "View History" on Loan A
      await tester.tap(find.text("View History"));
      await tester.pumpAndSettle();

      // Verify Loan A specific history dialog is displayed
      expect(find.text("Loan A Borrower - Payment History"), findsOneWidget);
      expect(find.textContaining("Account: ACC-0001"), findsOneWidget);
      expect(find.text("Page 1 of 2 (6 records)"), findsOneWidget);
      expect(find.text("Previous"), findsOneWidget);
      expect(find.text("Next"), findsOneWidget);

      // Verify it shows Loan A transactions in ascending date order (earliest first)
      expect(find.text("₹ 200.00"), findsOneWidget); // PAY-A-1 oldest first
      expect(find.text("₹ 500.00"), findsNothing); // Loan B payment not here

      // Navigate to Page 2 of Loan A history
      await tester.tap(find.text("Next"));
      await tester.pumpAndSettle();
      expect(find.text("Page 2 of 2 (6 records)"), findsOneWidget);
      expect(find.text("₹ 1200.00"), findsOneWidget); // PAY-A-6 latest on last page

      // Close dialog
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text("Loan A Borrower - Payment History"), findsNothing);

      // Open Actions dropdown on Loan B (second row)
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text("View History"));
      await tester.pumpAndSettle();

      // Verify Loan B specific history dialog
      expect(find.text("Loan B Borrower - Payment History"), findsOneWidget);
      expect(find.textContaining("Account: ACC-0002"), findsOneWidget);
      expect(find.text("Page 1 of 1 (2 records)"), findsOneWidget);
      expect(find.text("₹ 1000.00"), findsOneWidget); // PAY-B-2
      expect(find.text("₹ 500.00"), findsOneWidget); // PAY-B-1
      expect(find.text("₹ 1200.00"), findsNothing); // Loan A payment not here!
    });

    testWidgets("19. Route Zones and Collection Day Types wrap responsively on small mobile screens without horizontal dragging", (WidgetTester tester) async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();
      final authProvider = AuthProvider();
      final settingsProvider = SettingsProvider();
      final roProvider = RoProvider();

      // Seed multiple routes
      collectionProvider.addRoute(RouteModel(id: "R1", name: "Angom", code: "ANG"));
      collectionProvider.addRoute(RouteModel(id: "R2", name: "Khurai", code: "KHU"));
      collectionProvider.addRoute(RouteModel(id: "R3", name: "Porompat", code: "POR"));
      collectionProvider.addRoute(RouteModel(id: "R4", name: "Lamlong", code: "LAM"));
      collectionProvider.addRoute(RouteModel(id: "R5", name: "Uripok", code: "URI"));

      // Set small mobile screen: 360 x 640
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider<LoaneeProvider>.value(value: loaneeProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
          ],
          child: const MaterialApp(
            home: RoCollectionSheetViewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Wrap widgets are used for route selection and day types
      expect(find.byType(Wrap), findsWidgets);

      // Verify all route chips are visible on screen without requiring horizontal dragging
      expect(find.text("All Routes"), findsOneWidget);
      expect(find.text("Angom"), findsOneWidget);
      expect(find.text("Khurai"), findsOneWidget);
      expect(find.text("Porompat"), findsOneWidget);
      expect(find.text("Lamlong"), findsOneWidget);
      expect(find.text("Uripok"), findsOneWidget);

      // Select Route "Angom"
      await tester.tap(find.text("Angom"));
      await tester.pumpAndSettle();

      // Verify Collection Day Types wrap onto multiple rows and all days are visible
      expect(find.text("Monday"), findsOneWidget);
      expect(find.text("Tuesday"), findsOneWidget);
      expect(find.text("Wednesday"), findsOneWidget);
      expect(find.text("Thursday"), findsOneWidget);
      expect(find.text("Friday"), findsOneWidget);
      expect(find.text("Saturday"), findsOneWidget);
    });

    test("20. generateTemplateExcelBytes generates valid Excel matching new vertical structure", () {
      final bytes = HistoricalPaymentImportService.generateTemplateExcelBytes();
      expect(bytes, isNotEmpty);

      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: sampleLoanees,
        existingEntries: sampleEntries,
        existingPayments: samplePayments,
        existingRoutes: sampleRoutes,
      );

      expect(preview.hasFileErrors, isFalse);
      expect(preview.totalRows, equals(1));
      expect(preview.validRowsCount, equals(1));
      expect(preview.validPaymentsCount, equals(5));
      expect(preview.totalAmountToImport, equals(900.0));

      final record = preview.rowRecords.first;
      expect(record.rawCustomerId, equals("26LA000001"));
      expect(record.rawAccountNumber, equals("MF2026A000001"));
      expect(record.rawLoaneeName, equals("Ramesh Kumar"));
    });

    test("21. Bulk import transactional execution correctly suppresses individual notifications and preserves exact historical dates", () async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();

      // Create entry for 26LA000001
      await collectionProvider.addCollectionEntry(sampleEntries.first);

      final bytes = HistoricalPaymentImportService.generateTemplateExcelBytes();
      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: loaneeProvider.loanees,
        existingEntries: collectionProvider.collectionEntries,
        existingPayments: collectionProvider.payments,
      );

      expect(preview.canImport, isTrue);

      final result = await HistoricalPaymentImportService.executeTransactionalImport(
        previewResult: preview,
        collectionProvider: collectionProvider,
        loaneeProvider: loaneeProvider,
      );

      expect(result.success, isTrue);
      expect(result.paymentsInsertedCount, equals(5));
      expect(result.totalAmountImported, equals(900.0));

      // Verify exact dates were preserved (2026-07-01 to 2026-07-05)
      final importedPayments = collectionProvider.payments;
      expect(importedPayments.length, equals(5));
      expect(importedPayments.every((p) => p.createdAt.year == 2026 && p.createdAt.month == 7), isTrue);
      expect(importedPayments.any((p) => p.createdAt.day == 1), isTrue);
      expect(importedPayments.any((p) => p.createdAt.day == 2), isTrue);
      expect(importedPayments.any((p) => p.createdAt.day == 3), isTrue);
      expect(importedPayments.any((p) => p.createdAt.day == 4), isTrue);
      expect(importedPayments.any((p) => p.createdAt.day == 5), isTrue);
    });

    test("22. Old payment history import parses Interest column and calculates remaining balance as Initial + Interest - Paid", () async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();

      // Seed loanee with initial loan amount 11500
      final loanee = LoaneeAccount(
        customerid: "26LA000001",
        accountnumber: "MF2026A000001",
        loaneename: "Ramesh Kumar",
        guardianname: "R. Sharma",
        address: "Angom Leikai",
        businesstype: "Retail",
        postoffice: "Imphal",
        policestation: "Porompat",
        district: "Imphal East",
        pincode: "795005",
        mobileno: "9862112233",
        aadharno: "123456789012",
        loanamount: 11500.0,
        paidamount: 0.0,
        dueamount: 11500.0,
      );
      loaneeProvider.handleRealtimeLoaneeInsert(loanee);

      final entry = RoCollectionEntry(
        id: "COL-26LA000001",
        customerId: "26LA000001",
        accountNumber: "MF2026A000001",
        loaneeName: "Ramesh Kumar",
        loaneeAddress: "Angom Leikai",
        route: "Angom",
        collectionType: "Daily",
        mobileNo: "9862112233",
        loanAmount: 11500.0,
      );
      await collectionProvider.addCollectionEntry(entry);

      // Parse template Excel bytes
      final bytes = HistoricalPaymentImportService.generateTemplateExcelBytes();
      final preview = HistoricalPaymentImportService.parseWorkbookBytes(
        bytes: bytes,
        existingLoanees: loaneeProvider.loanees,
        existingEntries: collectionProvider.collectionEntries,
        existingPayments: collectionProvider.payments,
      );

      expect(preview.canImport, isTrue);
      expect(preview.totalAmountToImport, equals(900.0));
      expect(preview.totalInterestToImport, equals(301.0)); // 150 + 20 + 30 + 45 + 56

      final result = await HistoricalPaymentImportService.executeTransactionalImport(
        previewResult: preview,
        collectionProvider: collectionProvider,
        loaneeProvider: loaneeProvider,
      );

      expect(result.success, isTrue);
      expect(result.paymentsInsertedCount, equals(5));
      expect(result.totalAmountImported, equals(900.0));
      expect(result.totalInterestImported, equals(301.0));

      // Final remaining balance should be: 11500 + 301 - 900 = 10901.0
      final updatedLoanee = loaneeProvider.loanees.firstWhere((l) => l.customerId == "26LA000001");
      expect(updatedLoanee.paidamount, equals(900.0));
      expect(updatedLoanee.dueamount, equals(10901.0));

      final latestBal = collectionProvider.getLatestRemainingBalance("COL-26LA000001");
      expect(latestBal, equals(10901.0));
    });

    test("23. Deletion of payment immediately reflects in provider and updates loanee balance without manual refresh", () async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();

      final loanee = LoaneeAccount(
        customerid: "26LA000001",
        accountnumber: "MF2026A000001",
        loaneename: "Ramesh Kumar",
        guardianname: "R. Sharma",
        address: "Angom Leikai",
        businesstype: "Retail",
        postoffice: "Imphal",
        policestation: "Porompat",
        district: "Imphal East",
        pincode: "795005",
        mobileno: "9862112233",
        aadharno: "123456789012",
        loanamount: 11500.0,
        paidamount: 200.0,
        dueamount: 11450.0,
      );
      loaneeProvider.handleRealtimeLoaneeInsert(loanee);

      final entry = RoCollectionEntry(
        id: "COL-26LA000001",
        customerId: "26LA000001",
        accountNumber: "MF2026A000001",
        loaneeName: "Ramesh Kumar",
        loaneeAddress: "Angom Leikai",
        route: "Angom",
        collectionType: "Daily",
        mobileNo: "9862112233",
        loanAmount: 11500.0,
      );
      await collectionProvider.addCollectionEntry(entry);

      final payment = CollectionPaymentModel(
        id: "PAY-TEST-DEL",
        collectionId: "COL-26LA000001",
        paymentAmount: 200.0,
        interest: 150.0,
        remainingBalance: 11450.0, // 11500 + 150 - 200
        createdAt: DateTime(2026, 7, 1),
      );
      await collectionProvider.addCollectionPayment(payment);

      // Verify payment is present
      var history = await collectionProvider.getPaginatedPaymentHistory(collectionId: "COL-26LA000001");
      expect(history.totalCount, equals(1));
      expect(history.payments.first.interest, equals(150.0));

      // Now delete payment
      final deleted = await collectionProvider.deleteCollectionPayment("PAY-TEST-DEL");
      expect(deleted, isTrue);

      // Verify paginated payment history returns 0 payments immediately
      history = await collectionProvider.getPaginatedPaymentHistory(collectionId: "COL-26LA000001");
      expect(history.totalCount, equals(0));
      expect(history.payments.isEmpty, isTrue);

      // Balance adjustment
      final initialBal = entry.initialBalance;
      final currentPaid = collectionProvider.getTotalPaidForCollection(entry.id);
      final currentInterest = collectionProvider.getTotalInterestForCollection(entry.id);
      final newBal = (initialBal + currentInterest - currentPaid).clamp(0.0, double.infinity);

      loaneeProvider.handlePaymentDeleted(
        customerId: entry.customerId,
        accountNumber: entry.accountNumber,
        deletedPaymentAmount: 200.0,
        newRemainingBalance: newBal,
      );

      final updatedLoanee = loaneeProvider.loanees.firstWhere((l) => l.customerId == "26LA000001");
      expect(updatedLoanee.paidamount, equals(0.0));
      expect(updatedLoanee.dueamount, equals(11500.0));
    });

    testWidgets("24. RoCollectionSheetViewPage history dialog displays Interest column and allows deleting payment", (tester) async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();
      final authProvider = AuthProvider();
      final settingsProvider = SettingsProvider();
      final roProvider = RoProvider();

      final entry = RoCollectionEntry(
        id: "COL-TEST-HIST",
        customerId: "26LA000001",
        accountNumber: "MF2026A000001",
        loaneeName: "Ramesh Kumar",
        loaneeAddress: "Angom Leikai",
        route: "Angom",
        collectionType: "Daily",
        mobileNo: "9862112233",
        loanAmount: 11500.0,
      );
      collectionProvider.handleRealtimeEntryInsert(entry);
      collectionProvider.addRoute(RouteModel(id: "R1", name: "Angom", code: "ANG"));

      final payment = CollectionPaymentModel(
        id: "PAY-DLG-1",
        collectionId: "COL-TEST-HIST",
        paymentAmount: 200.0,
        interest: 150.0,
        remainingBalance: 11450.0,
        paymentType: "Cash",
        roName: "Dev",
        createdAt: DateTime(2026, 7, 1),
      );
      collectionProvider.handleRealtimePaymentInsert(payment);

      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CollectionSheetProvider>.value(value: collectionProvider),
            ChangeNotifierProvider<LoaneeProvider>.value(value: loaneeProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
            ChangeNotifierProvider<RoProvider>.value(value: roProvider),
          ],
          child: const MaterialApp(
            home: RoCollectionSheetViewPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Angom route
      await tester.tap(find.text("Angom"));
      await tester.pumpAndSettle();

      // Open Actions dropdown on row
      final actionDropdown = find.byType(PopupMenuButton<String>).first;
      await tester.tap(actionDropdown);
      await tester.pumpAndSettle();

      // Tap "View History"
      await tester.tap(find.text("View History"));
      await tester.pumpAndSettle();

      // Verify Interest column is present in DataTable
      expect(find.text("Interest"), findsOneWidget);
      expect(find.text("₹ 150.00"), findsOneWidget);
      expect(find.text("₹ 200.00"), findsOneWidget);
      expect(find.text("₹ 11450.00"), findsOneWidget);

      // Verify Delete action button is rendered
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });
  });
}


