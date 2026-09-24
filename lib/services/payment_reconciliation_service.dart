// lib/services/payment_reconciliation_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/collection_payment_model.dart';
import '../models/ro_collection_entry_model.dart';
import '../models/loanee_model.dart';

/// Categories of payment history and remaining balance discrepancies
enum PaymentReconciliationIssueType {
  excelImport,
  duplicateTransaction,
  missingTransaction,
  sequenceIssue,
  accountMapping,
  calculationMismatch,
}

/// Detailed description of a detected payment ledger issue
class PaymentReconciliationIssue {
  final PaymentReconciliationIssueType type;
  final String title;
  final String description;
  final String? paymentId;
  final DateTime? date;
  final double? recordedValue;
  final double? expectedValue;

  const PaymentReconciliationIssue({
    required this.type,
    required this.title,
    required this.description,
    this.paymentId,
    this.date,
    this.recordedValue,
    this.expectedValue,
  });

  String get typeLabel {
    switch (type) {
      case PaymentReconciliationIssueType.excelImport:
        return 'Excel Import Issue';
      case PaymentReconciliationIssueType.duplicateTransaction:
        return 'Duplicate Transaction';
      case PaymentReconciliationIssueType.missingTransaction:
        return 'Missing Transaction';
      case PaymentReconciliationIssueType.sequenceIssue:
        return 'Sequence / Date Issue';
      case PaymentReconciliationIssueType.accountMapping:
        return 'Account Mapping Issue';
      case PaymentReconciliationIssueType.calculationMismatch:
        return 'Calculation Formula Mismatch';
    }
  }

  Color get badgeColor {
    switch (type) {
      case PaymentReconciliationIssueType.excelImport:
        return const Color(0xFF1565C0); // Blue
      case PaymentReconciliationIssueType.duplicateTransaction:
        return const Color(0xFFC62828); // Red
      case PaymentReconciliationIssueType.missingTransaction:
        return const Color(0xFFE65100); // Deep Orange
      case PaymentReconciliationIssueType.sequenceIssue:
        return const Color(0xFF6A1B9A); // Purple
      case PaymentReconciliationIssueType.accountMapping:
        return const Color(0xFFAD1457); // Pink
      case PaymentReconciliationIssueType.calculationMismatch:
        return const Color(0xFFD84315); // Rust Orange
    }
  }
}

/// Chronologically ordered ledger entry representing a single transaction point
class ReconciledLedgerEntry {
  final int sequence;
  final CollectionPaymentModel payment;
  final double balanceBefore;
  final double paymentAmount;
  final double lateFee;
  final double postMaturityFine;
  final double balanceAfter;
  final bool hasDiscrepancy;
  final double? storedBalance;
  final String? discrepancyNote;

  const ReconciledLedgerEntry({
    required this.sequence,
    required this.payment,
    required this.balanceBefore,
    required this.paymentAmount,
    required this.lateFee,
    required this.postMaturityFine,
    required this.balanceAfter,
    this.hasDiscrepancy = false,
    this.storedBalance,
    this.discrepancyNote,
  });

  double get totalCharges => lateFee + postMaturityFine;
}

/// Complete result of ledger reconciliation for a collection entry
class PaymentReconciliationResult {
  final String collectionId;
  final String customerId;
  final String accountNumber;
  final String loaneeName;
  final double startingLoanAmount;
  final List<ReconciledLedgerEntry> entries;
  final Map<String, double> balancesByPaymentId;
  final List<PaymentReconciliationIssue> issues;
  final double totalPaid;
  final double totalLateFees;
  final double totalPostMaturityFines;
  final double finalRemainingBalance;

  const PaymentReconciliationResult({
    required this.collectionId,
    required this.customerId,
    required this.accountNumber,
    required this.loaneeName,
    required this.startingLoanAmount,
    required this.entries,
    required this.balancesByPaymentId,
    required this.issues,
    required this.totalPaid,
    required this.totalLateFees,
    required this.totalPostMaturityFines,
    required this.finalRemainingBalance,
  });

  bool get isReconciled => issues.isEmpty;
  int get totalTransactions => entries.length;

  double getBalanceForPayment(String paymentId) {
    return balancesByPaymentId[paymentId] ?? 0.0;
  }

  String get diagnosticSummary {
    if (isReconciled) {
      return 'Payment history reconciled: All $totalTransactions transactions follow chronological order and match the balance ledger.';
    }
    return '${issues.length} reconciliation issue${issues.length == 1 ? "" : "s"} detected. Chronological ledger calculation is actively enforced to prevent payment reversals.';
  }
}

/// Unified service providing strictly chronological payment ledger reconciliation
/// and comprehensive Excel export for Mangang Finance loanees.
class PaymentReconciliationService {
  /// Reconciles all transactions for a loan entry into a strictly chronological ledger.
  ///
  /// Guarantees:
  /// 1. Chronological order (earliest to latest).
  /// 2. For every transaction:
  ///    Balance After = (Balance Before + Applicable Charges - Payment Amount).clamp(0.0, infinity).
  /// 3. A payment that has already reduced the balance is NEVER added back on a later date.
  /// 4. Stored snapshot discrepancies, Excel import anomalies, duplicates, and out-of-order
  ///    records are automatically audited and diagnosed.
  static PaymentReconciliationResult reconcileLedger({
    required RoCollectionEntry entry,
    LoaneeAccount? loanee,
    required List<CollectionPaymentModel> payments,
  }) {
    final issues = <PaymentReconciliationIssue>[];

    // 1. Starting Balance determination
    final double startingBalance = (entry.loanAmount != null && entry.loanAmount! > 0)
        ? entry.loanAmount!
        : ((loanee != null && loanee.loanAmount > 0)
            ? loanee.loanAmount
            : (entry.actualPrincipal ?? entry.initialBalance));

    // 2. Data Integrity Checks (Duplicates, Foreign Records, Future Dates)
    final idCounts = <String, int>{};
    final seenDailySignatures = <String, List<CollectionPaymentModel>>{};
    int excelZeroCount = 0;
    final nowThreshold = DateTime.now().add(const Duration(days: 1));

    for (final p in payments) {
      // Check duplicate IDs
      idCounts[p.id] = (idCounts[p.id] ?? 0) + 1;

      // Check account mapping / foreign records
      if (p.collectionId.isNotEmpty && p.collectionId != entry.id) {
        issues.add(PaymentReconciliationIssue(
          type: PaymentReconciliationIssueType.accountMapping,
          title: 'Collection ID Mismatch',
          description: 'Payment ${p.id} references collection ID "${p.collectionId}" but is attached to "${entry.id}".',
          paymentId: p.id,
          date: p.createdAt,
        ));
      }

      // Check future dated transactions
      if (p.createdAt.isAfter(nowThreshold)) {
        issues.add(PaymentReconciliationIssue(
          type: PaymentReconciliationIssueType.sequenceIssue,
          title: 'Future-Dated Transaction',
          description: 'Payment ${p.id} has date ${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year} which is in the future.',
          paymentId: p.id,
          date: p.createdAt,
        ));
      }

      // Check Excel import zero-stored-balance
      final isExcel = (p.remarks?.toLowerCase().contains('excel') == true) ||
          (p.remarks?.toLowerCase().contains('imported') == true) ||
          p.id.toLowerCase().contains('excel') ||
          p.id.toLowerCase().contains('hist');
      if (isExcel && p.remainingBalance <= 0.01 && p.paymentAmount > 0) {
        excelZeroCount++;
      }

      // Group by date & amount to detect possible duplicate submissions
      final dateKey = '${p.createdAt.year}-${p.createdAt.month}-${p.createdAt.day}';
      final sigKey = '$dateKey|${p.paymentAmount.toStringAsFixed(2)}|${p.effectiveLateFine.toStringAsFixed(2)}|${p.postMaturityInterest.toStringAsFixed(2)}';
      seenDailySignatures.putIfAbsent(sigKey, () => []).add(p);
    }

    // Flag duplicate IDs
    for (final mapEntry in idCounts.entries) {
      if (mapEntry.value > 1) {
        issues.add(PaymentReconciliationIssue(
          type: PaymentReconciliationIssueType.duplicateTransaction,
          title: 'Duplicate Payment ID: ${mapEntry.key}',
          description: 'Payment ID ${mapEntry.key} appears ${mapEntry.value} times in the database.',
          paymentId: mapEntry.key,
        ));
      }
    }

    // Flag identical same-day duplicate entries
    for (final group in seenDailySignatures.values) {
      if (group.length > 1) {
        final first = group.first;
        final isAuto = first.id.startsWith('PAY-LATE-') || first.id.startsWith('PAY-POSTMAT-');
        issues.add(PaymentReconciliationIssue(
          type: PaymentReconciliationIssueType.duplicateTransaction,
          title: 'Possible Duplicate Entry on ${first.createdAt.day}/${first.createdAt.month}/${first.createdAt.year}',
          description: '${group.length} records have identical date, amount (₹${first.paymentAmount.toStringAsFixed(2)}), '
              'and charges. ${isAuto ? "Duplicate auto-assessed fee detected." : "Check if collection was submitted multiple times."}',
          paymentId: first.id,
          date: first.createdAt,
          recordedValue: first.paymentAmount,
        ));
      }
    }

    if (excelZeroCount > 0) {
      issues.add(PaymentReconciliationIssue(
        type: PaymentReconciliationIssueType.excelImport,
        title: 'Excel Imported Records With 0.0 Stored Balance',
        description: '$excelZeroCount Excel-imported payment(s) have stored remaining balance ₹0.00. '
            'The chronological ledger engine recalculates the exact continuous balance for every date.',
      ));
    }

    // 3. Sort strictly chronologically (oldest first)
    final sortedPayments = List<CollectionPaymentModel>.from(payments);
    sortedPayments.sort((a, b) {
      final dateCmp = a.createdAt.compareTo(b.createdAt);
      if (dateCmp != 0) return dateCmp;
      // If exact same timestamp: place charges before payments so charges accrue first
      final aIsChargeOnly = (a.paymentAmount <= 0 && (a.effectiveLateFine > 0 || a.postMaturityInterest > 0));
      final bIsChargeOnly = (b.paymentAmount <= 0 && (b.effectiveLateFine > 0 || b.postMaturityInterest > 0));
      if (aIsChargeOnly && !bIsChargeOnly) return -1;
      if (!aIsChargeOnly && bIsChargeOnly) return 1;
      return a.id.compareTo(b.id);
    });

    // 4. Chronological Ledger Calculation Loop
    double currentBal = startingBalance;
    final entries = <ReconciledLedgerEntry>[];
    final balancesMap = <String, double>{};
    double totalPaid = 0.0;
    double totalLate = 0.0;
    double totalPostMat = 0.0;

    for (int i = 0; i < sortedPayments.length; i++) {
      final p = sortedPayments[i];
      final balBefore = currentBal;
      final lateFee = p.effectiveLateFine;
      final postMat = p.postMaturityInterest;
      final paid = p.paymentAmount;

      totalPaid += paid;
      totalLate += lateFee;
      totalPostMat += postMat;

      // Core formula: Balance After = Balance Before + Charges - Paid Amount
      final balAfter = (balBefore + lateFee + postMat - paid).clamp(0.0, double.infinity);
      currentBal = balAfter;
      balancesMap[p.id] = balAfter;

      // Audit stored snapshot in ro_collection_payments against chronological balance
      bool hasDiscrepancy = false;
      String? note;
      if (p.remainingBalance > 0.01) {
        final diff = (p.remainingBalance - balAfter).abs();
        if (diff > 0.05) {
          hasDiscrepancy = true;
          note = 'Stored snapshot ₹${p.remainingBalance.toStringAsFixed(2)} differs from chronological balance ₹${balAfter.toStringAsFixed(2)} by ₹${diff.toStringAsFixed(2)}';
          issues.add(PaymentReconciliationIssue(
            type: PaymentReconciliationIssueType.calculationMismatch,
            title: 'Stored Balance Discrepancy on ${p.createdAt.day}/${p.createdAt.month}/${p.createdAt.year}',
            description: 'Payment ${p.id} has stored snapshot ₹${p.remainingBalance.toStringAsFixed(2)}, '
                'but chronological ledger balance is ₹${balAfter.toStringAsFixed(2)} (difference: ₹${diff.toStringAsFixed(2)}). '
                'Ledger balance is applied to prevent payment reversals.',
            paymentId: p.id,
            date: p.createdAt,
            recordedValue: p.remainingBalance,
            expectedValue: balAfter,
          ));
        }
      }

      entries.add(ReconciledLedgerEntry(
        sequence: i + 1,
        payment: p,
        balanceBefore: balBefore,
        paymentAmount: paid,
        lateFee: lateFee,
        postMaturityFine: postMat,
        balanceAfter: balAfter,
        hasDiscrepancy: hasDiscrepancy,
        storedBalance: p.remainingBalance > 0.01 ? p.remainingBalance : null,
        discrepancyNote: note,
      ));
    }

    return PaymentReconciliationResult(
      collectionId: entry.id,
      customerId: entry.customerId,
      accountNumber: entry.accountNumber,
      loaneeName: entry.loaneeName,
      startingLoanAmount: startingBalance,
      entries: entries,
      balancesByPaymentId: balancesMap,
      issues: issues,
      totalPaid: totalPaid,
      totalLateFees: totalLate,
      totalPostMaturityFines: totalPostMat,
      finalRemainingBalance: currentBal,
    );
  }

  /// Exports the complete chronological payment history and reconciliation audit
  /// to an Excel (.xlsx) file and triggers a platform share/download.
  static Future<bool> exportPaymentHistoryToExcel({
    required BuildContext context,
    required RoCollectionEntry entry,
    LoaneeAccount? loanee,
    required PaymentReconciliationResult reconciliation,
  }) async {
    try {
      final excelDoc = Excel.createExcel();
      const sheetName = 'Payment History';
      final sheet = excelDoc[sheetName];

      // Remove default Sheet1 if created
      if (sheetName != 'Sheet1' && excelDoc.sheets.containsKey('Sheet1')) {
        excelDoc.delete('Sheet1');
      }

      // Styles
      final titleStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#8B1A1A'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final sectionHeaderStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#424242'),
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
      );

      final headerLabelStyle = CellStyle(
        bold: true,
        fontSize: 10,
        backgroundColorHex: ExcelColor.fromHexString('#F0F0F0'),
        fontColorHex: ExcelColor.fromHexString('#333333'),
      );

      final headerValueStyle = CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#1E1E1E'),
      );

      final tableHeaderStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        backgroundColorHex: ExcelColor.fromHexString('#8B1A1A'),
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final summaryRowStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#8B1A1A'),
        backgroundColorHex: ExcelColor.fromHexString('#FDE8E8'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );

      final warningStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#D32F2F'),
        backgroundColorHex: ExcelColor.fromHexString('#FFEBEE'),
      );

      final successStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#2E7D32'),
        backgroundColorHex: ExcelColor.fromHexString('#E8F5E9'),
      );

      int currentRow = 0;

      // 1. Title Banner (Merged A1:J1)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
        ..value = TextCellValue('MANGANG FINANCE - LOANEE PAYMENT HISTORY & RECONCILIATION')
        ..cellStyle = titleStyle;
      for (int c = 1; c <= 9; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: currentRow)).cellStyle = titleStyle;
      }
      sheet.setRowHeight(currentRow, 32);
      currentRow += 2;

      // 2. Loanee Profile & Loan Details Header
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
        ..value = TextCellValue('LOANEE PROFILE & ACCOUNT METRICS')
        ..cellStyle = sectionHeaderStyle;
      for (int c = 1; c <= 9; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: currentRow)).cellStyle = sectionHeaderStyle;
      }
      currentRow++;

      final profileFields = [
        ['Loanee Name', entry.loaneeName, 'Customer ID', entry.customerId],
        ['Account Number', entry.accountNumber, 'Route', '${entry.route} (${entry.collectionType})'],
        ['Sanction Date', loanee?.formattedSanctionDate ?? 'N/A', 'Maturity Date', loanee?.formattedMaturityDate ?? 'N/A'],
        ['Sanctioned Loan Amount', '₹ ${reconciliation.startingLoanAmount.toStringAsFixed(2)}', 'Current Status', entry.status],
        ['Total Paid Amount', '₹ ${reconciliation.totalPaid.toStringAsFixed(2)}', 'Total Late Fees', '₹ ${reconciliation.totalLateFees.toStringAsFixed(2)}'],
        ['Total Post-Maturity Fines', '₹ ${reconciliation.totalPostMaturityFines.toStringAsFixed(2)}', 'Final Remaining Balance', '₹ ${reconciliation.finalRemainingBalance.toStringAsFixed(2)}'],
      ];

      for (final pRow in profileFields) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
          ..value = TextCellValue(pRow[0])
          ..cellStyle = headerLabelStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
          ..value = TextCellValue(pRow[1])
          ..cellStyle = headerValueStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow))
          ..value = TextCellValue(pRow[2])
          ..cellStyle = headerLabelStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow))
          ..value = TextCellValue(pRow[3])
          ..cellStyle = headerValueStyle;
        currentRow++;
      }
      currentRow++;

      // 3. Diagnostic Audit Section
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
        ..value = TextCellValue('AUDIT & RECONCILIATION STATUS')
        ..cellStyle = sectionHeaderStyle;
      for (int c = 1; c <= 9; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: currentRow)).cellStyle = sectionHeaderStyle;
      }
      currentRow++;

      if (reconciliation.isReconciled) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
          ..value = TextCellValue('✓ STATUS: RECONCILED — All ${reconciliation.totalTransactions} transactions strictly follow chronological ledger rules. No reversals or discrepancies found.')
          ..cellStyle = successStyle;
        currentRow += 2;
      } else {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
          ..value = TextCellValue('⚠️ STATUS: ${reconciliation.issues.length} ISSUE(S) DETECTED — Chronological ledger calculation enforced below to ensure accurate balances.')
          ..cellStyle = warningStyle;
        currentRow++;

        for (final issue in reconciliation.issues) {
          final issueText = '[${issue.typeLabel}] ${issue.title}: ${issue.description}';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
            ..value = TextCellValue(issueText)
            ..cellStyle = headerValueStyle;
          currentRow++;
        }
        currentRow++;
      }

      // 4. Payment History Table Header
      final tableHeaders = [
        'Sl No.',
        'Payment Date',
        'Transaction ID',
        'Payment Mode',
        'Collected By',
        'Balance Before (₹)',
        'Amount Paid (₹)',
        'Late Fee (₹)',
        'Post Maturity Fine (₹)',
        'Remaining Balance (₹)',
        'Audit Note / Remarks',
      ];

      for (int col = 0; col < tableHeaders.length; col++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow))
          ..value = TextCellValue(tableHeaders[col])
          ..cellStyle = tableHeaderStyle;
      }
      sheet.setRowHeight(currentRow, 26);
      currentRow++;

      // 5. Payment History Data Rows (Chronological)
      final regularCellStyle = CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#212121'),
        verticalAlign: VerticalAlign.Center,
      );

      final numberCellStyle = CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#212121'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );

      final discrepancyCellStyle = CellStyle(
        fontSize: 10,
        fontColorHex: ExcelColor.fromHexString('#C62828'),
        backgroundColorHex: ExcelColor.fromHexString('#FFF8E1'),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      );

      for (final entryItem in reconciliation.entries) {
        final p = entryItem.payment;
        final d = p.createdAt;
        final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        final roName = (p.roName?.isNotEmpty == true) ? p.roName! : 'RO Officer';
        final note = entryItem.discrepancyNote ?? (p.remarks?.isNotEmpty == true ? p.remarks! : '-');

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
          ..value = IntCellValue(entryItem.sequence)
          ..cellStyle = regularCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow))
          ..value = TextCellValue(dateStr)
          ..cellStyle = regularCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow))
          ..value = TextCellValue(p.id)
          ..cellStyle = regularCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow))
          ..value = TextCellValue(p.paymentType)
          ..cellStyle = regularCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow))
          ..value = TextCellValue(roName)
          ..cellStyle = regularCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow))
          ..value = DoubleCellValue(double.parse(entryItem.balanceBefore.toStringAsFixed(2)))
          ..cellStyle = numberCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow))
          ..value = DoubleCellValue(double.parse(entryItem.paymentAmount.toStringAsFixed(2)))
          ..cellStyle = numberCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow))
          ..value = DoubleCellValue(double.parse(entryItem.lateFee.toStringAsFixed(2)))
          ..cellStyle = numberCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow))
          ..value = DoubleCellValue(double.parse(entryItem.postMaturityFine.toStringAsFixed(2)))
          ..cellStyle = numberCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: currentRow))
          ..value = DoubleCellValue(double.parse(entryItem.balanceAfter.toStringAsFixed(2)))
          ..cellStyle = entryItem.hasDiscrepancy ? discrepancyCellStyle : numberCellStyle;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: currentRow))
          ..value = TextCellValue(note)
          ..cellStyle = regularCellStyle;

        currentRow++;
      }

      // 6. Summary Totals Row
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow))
        ..value = TextCellValue('TOTALS')
        ..cellStyle = summaryRowStyle;

      for (int c = 1; c <= 5; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: currentRow)).cellStyle = summaryRowStyle;
      }

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow))
        ..value = DoubleCellValue(double.parse(reconciliation.totalPaid.toStringAsFixed(2)))
        ..cellStyle = summaryRowStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow))
        ..value = DoubleCellValue(double.parse(reconciliation.totalLateFees.toStringAsFixed(2)))
        ..cellStyle = summaryRowStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: currentRow))
        ..value = DoubleCellValue(double.parse(reconciliation.totalPostMaturityFines.toStringAsFixed(2)))
        ..cellStyle = summaryRowStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: currentRow))
        ..value = DoubleCellValue(double.parse(reconciliation.finalRemainingBalance.toStringAsFixed(2)))
        ..cellStyle = summaryRowStyle;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: currentRow))
        ..value = TextCellValue('Final Balance')
        ..cellStyle = summaryRowStyle;

      // Encode workbook bytes
      final bytes = excelDoc.save() ?? [];
      if (bytes.isEmpty) {
        throw Exception('Failed to generate Excel bytes');
      }

      final cleanAccount = entry.accountNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'payment_history_${cleanAccount}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      if (kIsWeb) {
        final xfile = XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          name: fileName,
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [xfile],
            text: 'Mangang Finance - Payment History for ${entry.loaneeName} ($cleanAccount)',
          ),
        );
        return true;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Payment History - ${entry.loaneeName} ($cleanAccount)',
          text: 'Chronological Payment History & Ledger Statement for ${entry.loaneeName} (Account: ${entry.accountNumber}).',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment history Excel generated successfully: $fileName'),
            backgroundColor: const Color(0xFF1E7E34),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return true;
    } catch (e, stack) {
      debugPrint('❌ Error exporting payment history to Excel: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export payment history: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
}
