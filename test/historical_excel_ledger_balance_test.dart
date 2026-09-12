import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangang_finance/models/loanee_model.dart';
import 'package:mangang_finance/providers/collection_sheet_provider.dart';
import 'package:mangang_finance/providers/loanee_provider.dart';
import 'package:mangang_finance/providers/settings_provider.dart';
import 'package:mangang_finance/services/historical_payment_import_service.dart';

void main() {
  test('Detailed calculation test across dates 9 Sep - 14 Sep', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bytes = await File('/home/dell/Downloads/083.xlsx').readAsBytes();

    final loaneeProvider = LoaneeProvider();
    final collectionProvider = CollectionSheetProvider();
    final settingsProvider = SettingsProvider();

    final loanee = LoaneeAccount(
      customerid: '26LA000083',
      accountnumber: 'MF26A000083',
      loaneename: 'Naosekpam Malabati',
      guardianname: 'Guardian',
      address: 'Naorem makha leikai',
      businesstype: 'Business',
      postoffice: 'PO',
      policestation: 'PS',
      district: 'District',
      pincode: '795133',
      mobileno: '9876543210',
      aadharno: '123456789012',
      loanamount: 13915.0,
      dueamount: 13915.0,
      loansanctiondate: DateTime(2026, 3, 24),
      loanmaturitydate: DateTime(2026, 8, 23),
    );

    loaneeProvider.handleRealtimeLoaneeInsert(loanee);

    final preview = HistoricalPaymentImportService.parseWorkbookBytes(
      bytes: bytes,
      existingLoanees: loaneeProvider.loanees,
      existingEntries: collectionProvider.collectionEntries,
      existingPayments: collectionProvider.payments,
      defaultInterestRate: 15.0,
      defaultBasePrincipal: 12100.0,
    );

    await HistoricalPaymentImportService.executeTransactionalImport(
      previewResult: preview,
      collectionProvider: collectionProvider,
      loaneeProvider: loaneeProvider,
    );

    print('=== PAYMENTS IN COLLECTION PROVIDER (0 to 20) ===');
    for (int i = 0; i <= 20; i++) {
      final p = collectionProvider.payments[i];
      print('[$i] Date: ${p.createdAt.toIso8601String().substring(0, 10)}, Amt: ${p.paymentAmount}, Int: ${p.interest}, Bal: ${p.remainingBalance}, Remarks: ${p.remarks}');
    }
    final entry = collectionProvider.collectionEntries.first;
    final totalCollected = collectionProvider.getTotalPaidForCollection(entry.id);
    final totalInterest = collectionProvider.getTotalInterestForCollection(entry.id);
    final remainingBal = collectionProvider.getLatestRemainingBalance(entry.id);

    print('=== POST-IMPORT SUMMARY ===');
    print('Total Collected: $totalCollected');
    print('Total Interest: $totalInterest');
    print('Remaining Bal: $remainingBal');

    // 1. Assertions for Reference Account 26LA000083
    expect(collectionProvider.payments.length, equals(120), reason: 'All 120 imported payment rows must be preserved');
    expect(totalCollected, equals(6529.0), reason: 'Total collected from all imported payment records: ₹6,529.00');
    expect(totalInterest, equals(765.0), reason: 'Accumulated overdue/additional interest: ₹765.00');
    expect(loanee.loanAmount - totalCollected, equals(7386.0), reason: 'Remaining before overdue/additional interest: ₹7,386.00');
    expect(remainingBal, equals(8151.0), reason: 'FINAL REMAINING BALANCE: ₹8,151.00');
    expect(collectionProvider.isEntryCompleted(entry, loaneeProvider: loaneeProvider), isFalse,
        reason: 'Loan has remaining balance of ₹8,151.00; it cannot be completed even though maturity date has passed');

    // 2. Assertions across dates 9 September through 14 September
    for (int day = 9; day <= 14; day++) {
      final asOfDate = DateTime(2026, 9, day);
      final latePayable = settingsProvider.getLatePayableBreakdownForEntry(
        entry: entry,
        payments: collectionProvider.payments,
        loaneeLoanAmount: loanee.loanAmount,
        loaneeDueAmount: loaneeProvider.loanees.first.dueAmount,
        maturityDate: loanee.loanMaturityDate,
        sanctionDate: loanee.loanSanctionDate,
        asOfDate: asOfDate,
        overrideTotalPaid: totalCollected,
      );
      final postMat = latePayable.postMaturityBreakdown;
      print('--- Date: 2026-09-${day.toString().padLeft(2, "0")} ---');
      print('  isPastMaturity: ${postMat?.isPastMaturity}');
      print('  overdueMonths: ${postMat?.overdueMonths}');
      print('  postMaturityInterestAmount: ${postMat?.postMaturityInterestAmount}');
      print('  cumulativeInterestAmount: ${postMat?.cumulativeInterestAmount}');
      print('  remainingBalance: ${postMat?.remainingBalance}');
      print('  postMaturityPayableAmount: ${postMat?.postMaturityPayableAmount}');
      print('  lateUnits: ${latePayable.lateUnits}');
      print('  calculatedLateFine: ${latePayable.calculatedLateFine}');
      print('  totalPayableAmount: ${latePayable.totalPayableAmount}');
      print('  grandTotalWithPenalty: ${latePayable.grandTotalWithPenalty}');

      expect(postMat?.isPastMaturity, isTrue);
      expect(postMat?.overdueMonths, equals(1));
      expect(postMat?.remainingBalance, equals(8151.0), reason: 'Remaining balance must stay ₹8,151 on 2026-09-$day');
      expect(postMat?.postMaturityPayableAmount, equals(8151.0), reason: 'Post-maturity payable must stay ₹8,151 on 2026-09-$day');
      expect(latePayable.totalPayableAmount, equals(8151.0), reason: 'Total payable must stay ₹8,151 on 2026-09-$day');
      expect(latePayable.grandTotalWithPenalty, equals(8151.0), reason: 'Grand total must stay ₹8,151 on 2026-09-$day');
      expect(latePayable.calculatedLateFine, equals(0.0), reason: 'Late fine must not accrue on post-maturity daily collection');
    }
  });
}
