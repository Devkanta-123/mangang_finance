import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:mangang_finance/models/collection_payment_model.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/models/ro_collection_entry_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/services/historical_payment_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Historical Payment Import Post Maturity Precision Tests', () {
    test('parseNumericAmount correctly parses various currency and decimal formats', () {
      // Direct numbers
      expect(HistoricalPaymentImportService.parseNumericAmount(1020), 1020.0);
      expect(HistoricalPaymentImportService.parseNumericAmount(1017.66), 1017.66);
      expect(HistoricalPaymentImportService.parseNumericAmount(1020.5), 1020.5);

      // CellValue types
      expect(HistoricalPaymentImportService.parseNumericAmount(IntCellValue(1020)), 1020.0);
      expect(HistoricalPaymentImportService.parseNumericAmount(DoubleCellValue(1017.66)), 1017.66);
      expect(HistoricalPaymentImportService.parseNumericAmount(DoubleCellValue(1020.5)), 1020.5);
      expect(HistoricalPaymentImportService.parseNumericAmount(FormulaCellValue('=1020.00')), 1020.0);
      expect(HistoricalPaymentImportService.parseNumericAmount(FormulaCellValue('1017.66')), 1017.66);

      // Strings with currency symbols and spaces (including non-breaking spaces)
      expect(HistoricalPaymentImportService.parseNumericAmount('₹ ₹ 1,020.00'), 1020.0);
      expect(HistoricalPaymentImportService.parseNumericAmount('₹ 1,017.66'), 1017.66);
      expect(HistoricalPaymentImportService.parseNumericAmount('₹ 1,020.50'), 1020.5);
      expect(HistoricalPaymentImportService.parseNumericAmount('Rs. 1,020.00'), 1020.0);
      expect(HistoricalPaymentImportService.parseNumericAmount('INR 1,020.75'), 1020.75);
      expect(HistoricalPaymentImportService.parseNumericAmount('\u00A0₹\u00A01,020.00\u00A0'), 1020.0);
    });

    test('executeTransactionalImport strictly preserves explicit Post Maturity Interest from Excel', () async {
      final collectionProvider = CollectionSheetProvider();
      final loaneeProvider = LoaneeProvider();

      // Loan with balance 14,538 (where 7% would be 1017.66)
      final loanee = LoaneeAccount(
        customerid: 'CUST-100',
        accountnumber: 'ACC-100',
        loaneename: 'Test Loanee',
        guardianname: 'Guardian',
        address: 'Test Address',
        businesstype: 'Shop',
        postoffice: 'PO',
        policestation: 'PS',
        district: 'District',
        pincode: '795001',
        mobileno: '9999999999',
        aadharno: '123412341234',
        loanamount: 20000.0,
        dueamount: 14538.0,
        loansanctiondate: DateTime(2025, 1, 1),
        loanmaturitydate: DateTime(2025, 6, 1),
      );
      loaneeProvider.handleRealtimeLoaneeInsert(loanee);

      final entry = RoCollectionEntry(
        id: 'COL-100',
        customerId: 'CUST-100',
        accountNumber: 'ACC-100',
        loaneeName: 'Test Loanee',
        loaneeAddress: 'Test Address',
        collectionType: 'Daily',
        route: 'Route 1',
        mobileNo: '9999999999',
        loanAmount: 20000.0,
        createdAt: DateTime(2025, 1, 1),
      );
      await collectionProvider.addCollectionEntry(entry, saveToRemote: false);

      // Prior payment to make remaining balance exactly 14,538
      final priorPayment = CollectionPaymentModel(
        id: 'PAY-PRIOR-1',
        collectionId: entry.id,
        paymentAmount: 5462.0, // 20000 - 5462 = 14538 remaining balance
        remainingBalance: 14538.0,
        paymentType: 'Cash',
        roPasscode: '1234',
        roName: 'RO 1',
        roId: 'RO-1',
        roRoute: 'Route 1',
        createdAt: DateTime(2025, 5, 1),
        status: 'Success',
      );
      await collectionProvider.addCollectionPayment(priorPayment, saveToRemote: false);

      // Excel row imported with post-maturity interest = 1020.00 on 2025-06-01 (maturity date match)
      final importedItem = HistoricalPaymentItem(
        paymentDate: DateTime(2025, 6, 1),
        amount: 0.0,
        interest: 0.0,
        latePaymentFee: 0.0,
        postMaturityInterest: 1020.0, // In Excel it is 1020.00
        roName: 'RO 1',
      );

      final row = HistoricalImportRowRecord(
        rowIndex: 7,
        rawCustomerId: 'CUST-100',
        rawAccountNumber: 'ACC-100',
        rawLoaneeName: 'Test Loanee',
        rawRoute: 'Route 1',
        rawCollectionType: 'Daily',
        rawCollectedBy: 'RO 1',
        resolvedLoanee: loanee,
        resolvedCollectionEntry: entry,
        payments: [importedItem],
        isValid: true,
      );

      final preview = HistoricalImportPreviewResult(
        totalRows: 1,
        validRowsCount: 1,
        invalidRowsCount: 0,
        unmappedRowsCount: 0,
        totalPaymentsParsed: 1,
        validPaymentsCount: 1,
        duplicatePaymentsCount: 0,
        totalAmountToImport: 0.0,
        totalLateFeesToImport: 0.0,
        totalPostMatToImport: 1020.0,
        rowRecords: [row],
      );

      final result = await HistoricalPaymentImportService.executeTransactionalImport(
        previewResult: preview,
        collectionProvider: collectionProvider,
        loaneeProvider: loaneeProvider,
      );

      expect(result.success, isTrue);

      final payments = collectionProvider.getPaymentsForCollection(entry.id);
      final postMatPayment = payments.firstWhere((p) => p.createdAt.year == 2025 && p.createdAt.month == 6 && p.createdAt.day == 1);

      // Must be EXACTLY 1020.00 from Excel, and NOT 1017.66 from 7% calculation!
      expect(postMatPayment.postMaturityInterest, 1020.0);
      expect(postMatPayment.remarks, contains('1020.00'));
    });
  });
}
