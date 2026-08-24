// lib/services/customer_id_service.dart

import '../models/loanee_model.dart';
import '../models/ro_model.dart';

/// Centralized Customer ID generator for Loanee and Recovery Officer (RO) accounts.
///
/// New format specification:
/// - Loanee: CUST + CURRENT_YEAR + L + 6-digit sequence (e.g. CUST2026L000001)
/// - RO:     CUST + CURRENT_YEAR + RO + 3-digit sequence (e.g. CUST2026RO001)
///
/// Where:
/// - Loanee TYPE = L (pad length = 6, starts from 000001)
/// - RO TYPE = RO (pad length = 3, starts from 001)
/// - Current Year is determined dynamically from DateTime.now() or timezone
/// - Separate sequential counters for Loanee and RO
class CustomerIdService {
  static const String prefix = 'CUST';
  static const String loaneeType = 'L';
  static const String roType = 'RO';
  static const int loaneePadLength = 6;
  static const int roPadLength = 3;

  /// Generate the prefix for a given account type and year (e.g. CUST2026L or CUST2026RO)
  static String getPrefix({
    required bool isRo,
    DateTime? now,
    int? year,
  }) {
    final y = year ?? (now ?? DateTime.now()).year;
    final type = isRo ? roType : loaneeType;
    return '$prefix$y$type';
  }

  /// Format a Customer ID given type, year, and sequence number
  static String formatId({
    required bool isRo,
    required int sequence,
    DateTime? now,
    int? year,
  }) {
    final p = getPrefix(isRo: isRo, now: now, year: year);
    final pad = isRo ? roPadLength : loaneePadLength;
    final seqStr = sequence.toString().padLeft(pad, '0');
    return '$p$seqStr';
  }

  /// Extract the sequence number from a Customer ID if it matches the current year & type format
  static int? extractSequence(
    String? id, {
    required bool isRo,
    int? year,
    DateTime? now,
  }) {
    if (id == null || id.trim().isEmpty) return null;
    final cleanId = id.trim().toUpperCase();
    final y = year ?? (now ?? DateTime.now()).year;
    final type = isRo ? roType : loaneeType;

    // Matches standard new format: CUST2026L000001 or CUST2026RO001
    final pattern = RegExp('^CUST$y$type(\\d+)\$', caseSensitive: false);
    final match = pattern.firstMatch(cleanId);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!);
    }

    // Matches previous variant CUSTL202600001 / CUSTRO202600001 for smooth backward compatibility
    final altPattern = RegExp('^CUST$type$y(\\d+)\$', caseSensitive: false);
    final altMatch = altPattern.firstMatch(cleanId);
    if (altMatch != null && altMatch.groupCount >= 1) {
      return int.tryParse(altMatch.group(1)!);
    }

    return null;
  }

  /// Safely generate the next Customer ID for a Loanee account
  static String generateLoaneeCustomerId({
    Iterable<String>? existingIds,
    Iterable<LoaneeAccount>? existingLoanees,
    DateTime? now,
    int? year,
    Set<String>? reservedIds,
  }) {
    final allIds = <String>{};
    if (existingIds != null) {
      for (final id in existingIds) {
        if (id.trim().isNotEmpty) allIds.add(id.trim().toUpperCase());
      }
    }
    if (existingLoanees != null) {
      for (final l in existingLoanees) {
        if (l.customerId.trim().isNotEmpty) {
          allIds.add(l.customerId.trim().toUpperCase());
        }
      }
    }
    if (reservedIds != null) {
      for (final id in reservedIds) {
        if (id.trim().isNotEmpty) allIds.add(id.trim().toUpperCase());
      }
    }

    final targetYear = year ?? (now ?? DateTime.now()).year;
    int maxSeq = 0;

    for (final id in allIds) {
      final seq = extractSequence(id, isRo: false, year: targetYear);
      if (seq != null && seq > maxSeq) {
        maxSeq = seq;
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = formatId(
      isRo: false,
      sequence: nextSeq,
      year: targetYear,
    );

    // Collision avoidance against reserved / concurrent set
    while (allIds.contains(candidate.toUpperCase())) {
      nextSeq++;
      candidate = formatId(
        isRo: false,
        sequence: nextSeq,
        year: targetYear,
      );
    }

    return candidate;
  }

  /// Safely generate the next Customer ID for a Recovery Officer (RO) account
  static String generateRoCustomerId({
    Iterable<String>? existingIds,
    Iterable<RoAccount>? existingRos,
    DateTime? now,
    int? year,
    Set<String>? reservedIds,
  }) {
    final allIds = <String>{};
    if (existingIds != null) {
      for (final id in existingIds) {
        if (id.trim().isNotEmpty) allIds.add(id.trim().toUpperCase());
      }
    }
    if (existingRos != null) {
      for (final r in existingRos) {
        if (r.customerId.trim().isNotEmpty) {
          allIds.add(r.customerId.trim().toUpperCase());
        }
      }
    }
    if (reservedIds != null) {
      for (final id in reservedIds) {
        if (id.trim().isNotEmpty) allIds.add(id.trim().toUpperCase());
      }
    }

    final targetYear = year ?? (now ?? DateTime.now()).year;
    int maxSeq = 0;

    for (final id in allIds) {
      final seq = extractSequence(id, isRo: true, year: targetYear);
      if (seq != null && seq > maxSeq) {
        maxSeq = seq;
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = formatId(
      isRo: true,
      sequence: nextSeq,
      year: targetYear,
    );

    // Collision avoidance against reserved / concurrent set
    while (allIds.contains(candidate.toUpperCase())) {
      nextSeq++;
      candidate = formatId(
        isRo: true,
        sequence: nextSeq,
        year: targetYear,
      );
    }

    return candidate;
  }

  /// Generate a batch of consecutive unique Customer IDs (e.g. for Excel bulk import)
  static List<String> generateLoaneeCustomerIdsBatch(
    int count, {
    Iterable<String>? existingIds,
    Iterable<LoaneeAccount>? existingLoanees,
    DateTime? now,
    int? year,
    Set<String>? reservedIds,
  }) {
    final List<String> result = [];
    final activeReserved = <String>{
      if (reservedIds != null) ...reservedIds,
    };

    for (int i = 0; i < count; i++) {
      final nextId = generateLoaneeCustomerId(
        existingIds: existingIds,
        existingLoanees: existingLoanees,
        now: now,
        year: year,
        reservedIds: activeReserved,
      );
      result.add(nextId);
      activeReserved.add(nextId);
    }

    return result;
  }

  /// Validate if a Customer ID matches the Loanee format (new, previous variant, or legacy)
  static bool isValidLoaneeCustomerId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    final clean = id.trim().toUpperCase();
    // New format: CUST2026L000001 (CUST + 4-digit year + L + 6-digit sequence)
    final newPattern = RegExp(r'^CUST\d{4}L\d{6,}$');
    // Prior format variant: CUSTL202600001
    final priorPattern = RegExp(r'^CUSTL\d{4}\d{4,}$');
    // Legacy format: CUST-1001 or CUST1001
    final legacyPattern = RegExp(r'^CUST-?\d+$');
    return newPattern.hasMatch(clean) || priorPattern.hasMatch(clean) || legacyPattern.hasMatch(clean);
  }

  /// Validate if a Customer ID matches the RO format (new, previous variant, or legacy)
  static bool isValidRoCustomerId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    final clean = id.trim().toUpperCase();
    // New format: CUST2026RO001 (CUST + 4-digit year + RO + 3-digit sequence)
    final newPattern = RegExp(r'^CUST\d{4}RO\d{3,}$');
    // Prior format variant: CUSTRO202600001
    final priorPattern = RegExp(r'^CUSTRO\d{4}\d{3,}$');
    // Legacy format: RO-CUST-5001 or RO-CUST5001
    final legacyPattern = RegExp(r'^RO-CUST-?\d+$');
    return newPattern.hasMatch(clean) || priorPattern.hasMatch(clean) || legacyPattern.hasMatch(clean);
  }
}
