// lib/services/customer_id_service.dart

import '../models/loanee_model.dart';
import '../models/ro_model.dart';

/// Centralized ID and Account Number generator for Loanee and Recovery Officer (RO) accounts.
///
/// FORMAT SPECIFICATIONS:
/// 1. Loanee Customer ID:   YYYYLA + 6-digit sequence  (e.g. 2026LA000001, 2026LA000002)
/// 2. RO Customer ID:       YYYYR + 3-digit sequence   (e.g. 2026R001, 2026R002)
/// 3. Loanee Account No:    MF + YYYY + A + 6-digit sequence (e.g. MF2026A000001, MF2026A000002)
/// 4. RO Account No:        AC + YYYY + RS + 4-digit sequence (e.g. AC2026RS0001, AC2026RS0002)
///
/// RULES:
/// - Current Year is dynamically resolved (never hardcoded).
/// - Loanee and RO maintain completely independent sequential counters.
/// - Customer ID and Account Number maintain completely independent sequential counters.
/// - Concurrency / collision safety supported via monotonic max detection and reserved IDs sets.
/// - Existing legacy records are preserved without mutation.
class CustomerIdService {
  // Padding Lengths
  static const int loaneeCustomerPadLength = 6;
  static const int roCustomerPadLength = 3;
  static const int loaneeAccountPadLength = 6;
  static const int roAccountPadLength = 4;

  /// Helper to get 2-digit year (e.g., 2026 -> '26', 2027 -> '27')
  static String getShortYear({DateTime? now, int? year}) {
    final y = year ?? (now ?? DateTime.now()).year;
    return (y % 100).toString().padLeft(2, '0');
  }

  // ==========================================
  // 1. LOANEE CUSTOMER ID: YYLA + 6 digits (e.g. 26LA000001)
  // ==========================================

  static String getLoaneeCustomerIdPrefix({DateTime? now, int? year}) {
    final yy = getShortYear(now: now, year: year);
    return '${yy}LA';
  }

  static String formatLoaneeCustomerId(
    int sequence, {
    DateTime? now,
    int? year,
  }) {
    final prefix = getLoaneeCustomerIdPrefix(now: now, year: year);
    final seqStr = sequence.toString().padLeft(loaneeCustomerPadLength, '0');
    return '$prefix$seqStr';
  }

  static int? extractLoaneeCustomerIdSequence(
    String? id, {
    int? year,
    DateTime? now,
  }) {
    if (id == null || id.trim().isEmpty) return null;
    final cleanId = id.trim().toUpperCase();
    final y = year ?? (now ?? DateTime.now()).year;
    final yy = getShortYear(now: now, year: year);

    // 1. New short-year pattern: 26LA000001
    final pattern = RegExp('^${yy}LA(\\d+)\$', caseSensitive: false);
    final match = pattern.firstMatch(cleanId);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!);
    }

    // 2. Previous 4-digit year pattern: 2026LA000001
    final pattern4 = RegExp('^${y}LA(\\d+)\$', caseSensitive: false);
    final match4 = pattern4.firstMatch(cleanId);
    if (match4 != null && match4.groupCount >= 1) {
      return int.tryParse(match4.group(1)!);
    }

    // 3. Previous variants (e.g. CUST2026L000001, CUSTL202600001)
    final prevPattern = RegExp('^CUST${y}L(\\d+)\$', caseSensitive: false);
    final prevMatch = prevPattern.firstMatch(cleanId);
    if (prevMatch != null && prevMatch.groupCount >= 1) {
      return int.tryParse(prevMatch.group(1)!);
    }

    final prevPattern2 = RegExp('^CUSTL$y(\\d+)\$', caseSensitive: false);
    final prevMatch2 = prevPattern2.firstMatch(cleanId);
    if (prevMatch2 != null && prevMatch2.groupCount >= 1) {
      return int.tryParse(prevMatch2.group(1)!);
    }

    return null;
  }

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
      final seq = extractLoaneeCustomerIdSequence(id, year: targetYear, now: now);
      if (seq != null && seq > maxSeq) {
        maxSeq = seq;
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = formatLoaneeCustomerId(
      nextSeq,
      year: targetYear,
      now: now,
    );

    while (allIds.contains(candidate.toUpperCase())) {
      nextSeq++;
      candidate = formatLoaneeCustomerId(
        nextSeq,
        year: targetYear,
        now: now,
      );
    }

    return candidate;
  }

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

  // ==========================================
  // 2. RO CUSTOMER ID: YYR + 3 digits (e.g. 26R001)
  // ==========================================

  static String getRoCustomerIdPrefix({DateTime? now, int? year}) {
    final yy = getShortYear(now: now, year: year);
    return '${yy}R';
  }

  static String formatRoCustomerId(
    int sequence, {
    DateTime? now,
    int? year,
  }) {
    final prefix = getRoCustomerIdPrefix(now: now, year: year);
    final seqStr = sequence.toString().padLeft(roCustomerPadLength, '0');
    return '$prefix$seqStr';
  }

  static int? extractRoCustomerIdSequence(
    String? id, {
    int? year,
    DateTime? now,
  }) {
    if (id == null || id.trim().isEmpty) return null;
    final cleanId = id.trim().toUpperCase();
    final y = year ?? (now ?? DateTime.now()).year;
    final yy = getShortYear(now: now, year: year);

    // 1. New short-year pattern: 26R001
    final pattern = RegExp('^${yy}R(\\d+)\$', caseSensitive: false);
    final match = pattern.firstMatch(cleanId);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!);
    }

    // 2. Previous 4-digit year pattern: 2026R001
    final pattern4 = RegExp('^${y}R(\\d+)\$', caseSensitive: false);
    final match4 = pattern4.firstMatch(cleanId);
    if (match4 != null && match4.groupCount >= 1) {
      return int.tryParse(match4.group(1)!);
    }

    // 3. Previous variants (e.g. CUST2026RO001, CUSTRO202600001)
    final prevPattern = RegExp('^CUST${y}RO(\\d+)\$', caseSensitive: false);
    final prevMatch = prevPattern.firstMatch(cleanId);
    if (prevMatch != null && prevMatch.groupCount >= 1) {
      return int.tryParse(prevMatch.group(1)!);
    }

    final prevPattern2 = RegExp('^CUSTRO$y(\\d+)\$', caseSensitive: false);
    final prevMatch2 = prevPattern2.firstMatch(cleanId);
    if (prevMatch2 != null && prevMatch2.groupCount >= 1) {
      return int.tryParse(prevMatch2.group(1)!);
    }

    return null;
  }

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
      final seq = extractRoCustomerIdSequence(id, year: targetYear, now: now);
      if (seq != null && seq > maxSeq) {
        maxSeq = seq;
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = formatRoCustomerId(
      nextSeq,
      year: targetYear,
      now: now,
    );

    while (allIds.contains(candidate.toUpperCase())) {
      nextSeq++;
      candidate = formatRoCustomerId(
        nextSeq,
        year: targetYear,
        now: now,
      );
    }

    return candidate;
  }

  static List<String> generateRoCustomerIdsBatch(
    int count, {
    Iterable<String>? existingIds,
    Iterable<RoAccount>? existingRos,
    DateTime? now,
    int? year,
    Set<String>? reservedIds,
  }) {
    final List<String> result = [];
    final activeReserved = <String>{
      if (reservedIds != null) ...reservedIds,
    };

    for (int i = 0; i < count; i++) {
      final nextId = generateRoCustomerId(
        existingIds: existingIds,
        existingRos: existingRos,
        now: now,
        year: year,
        reservedIds: activeReserved,
      );
      result.add(nextId);
      activeReserved.add(nextId);
    }

    return result;
  }

  // ==========================================
  // 3. LOANEE ACCOUNT NUMBER: MF + YY + A + 6 digits (e.g. MF26A000001)
  // ==========================================

  static String getLoaneeAccountNumberPrefix({DateTime? now, int? year}) {
    final yy = getShortYear(now: now, year: year);
    return 'MF${yy}A';
  }

  static String formatLoaneeAccountNumber(
    int sequence, {
    DateTime? now,
    int? year,
  }) {
    final prefix = getLoaneeAccountNumberPrefix(now: now, year: year);
    final seqStr = sequence.toString().padLeft(loaneeAccountPadLength, '0');
    return '$prefix$seqStr';
  }

  static int? extractLoaneeAccountNumberSequence(
    String? acc, {
    int? year,
    DateTime? now,
  }) {
    if (acc == null || acc.trim().isEmpty) return null;
    final cleanAcc = acc.trim().toUpperCase();
    final y = year ?? (now ?? DateTime.now()).year;
    final yy = getShortYear(now: now, year: year);

    // 1. New short-year pattern: MF26A000001
    final pattern = RegExp('^MF${yy}A(\\d+)\$', caseSensitive: false);
    final match = pattern.firstMatch(cleanAcc);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!);
    }

    // 2. Previous 4-digit pattern: MF2026A000001
    final pattern4 = RegExp('^MF${y}A(\\d+)\$', caseSensitive: false);
    final match4 = pattern4.firstMatch(cleanAcc);
    if (match4 != null && match4.groupCount >= 1) {
      return int.tryParse(match4.group(1)!);
    }

    return null;
  }

  static String generateLoaneeAccountNumber({
    Iterable<String>? existingAccNos,
    Iterable<LoaneeAccount>? existingLoanees,
    DateTime? now,
    int? year,
    Set<String>? reservedAccNos,
  }) {
    final allAccs = <String>{};
    if (existingAccNos != null) {
      for (final acc in existingAccNos) {
        if (acc.trim().isNotEmpty) allAccs.add(acc.trim().toUpperCase());
      }
    }
    if (existingLoanees != null) {
      for (final l in existingLoanees) {
        if (l.accountNumber.trim().isNotEmpty) {
          allAccs.add(l.accountNumber.trim().toUpperCase());
        }
      }
    }
    if (reservedAccNos != null) {
      for (final acc in reservedAccNos) {
        if (acc.trim().isNotEmpty) allAccs.add(acc.trim().toUpperCase());
      }
    }

    final targetYear = year ?? (now ?? DateTime.now()).year;
    int maxSeq = 0;

    for (final acc in allAccs) {
      final seq = extractLoaneeAccountNumberSequence(acc, year: targetYear, now: now);
      if (seq != null && seq > maxSeq) {
        maxSeq = seq;
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = formatLoaneeAccountNumber(
      nextSeq,
      year: targetYear,
      now: now,
    );

    while (allAccs.contains(candidate.toUpperCase())) {
      nextSeq++;
      candidate = formatLoaneeAccountNumber(
        nextSeq,
        year: targetYear,
        now: now,
      );
    }

    return candidate;
  }

  static List<String> generateLoaneeAccountNumbersBatch(
    int count, {
    Iterable<String>? existingAccNos,
    Iterable<LoaneeAccount>? existingLoanees,
    DateTime? now,
    int? year,
    Set<String>? reservedAccNos,
  }) {
    final List<String> result = [];
    final activeReserved = <String>{
      if (reservedAccNos != null) ...reservedAccNos,
    };

    for (int i = 0; i < count; i++) {
      final nextAcc = generateLoaneeAccountNumber(
        existingAccNos: existingAccNos,
        existingLoanees: existingLoanees,
        now: now,
        year: year,
        reservedAccNos: activeReserved,
      );
      result.add(nextAcc);
      activeReserved.add(nextAcc);
    }

    return result;
  }

  // ==========================================
  // 4. RO ACCOUNT NUMBER: AC + YY + RS + 4 digits (e.g. AC26RS0001)
  // ==========================================

  static String getRoAccountNumberPrefix({DateTime? now, int? year}) {
    final yy = getShortYear(now: now, year: year);
    return 'AC${yy}RS';
  }

  static String formatRoAccountNumber(
    int sequence, {
    DateTime? now,
    int? year,
  }) {
    final prefix = getRoAccountNumberPrefix(now: now, year: year);
    final seqStr = sequence.toString().padLeft(roAccountPadLength, '0');
    return '$prefix$seqStr';
  }

  static int? extractRoAccountNumberSequence(
    String? acc, {
    int? year,
    DateTime? now,
  }) {
    if (acc == null || acc.trim().isEmpty) return null;
    final cleanAcc = acc.trim().toUpperCase();
    final y = year ?? (now ?? DateTime.now()).year;
    final yy = getShortYear(now: now, year: year);

    // 1. New short-year pattern: AC26RS0001
    final pattern = RegExp('^AC${yy}RS(\\d+)\$', caseSensitive: false);
    final match = pattern.firstMatch(cleanAcc);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1)!);
    }

    // 2. Previous 4-digit pattern: AC2026RS0001
    final pattern4 = RegExp('^AC${y}RS(\\d+)\$', caseSensitive: false);
    final match4 = pattern4.firstMatch(cleanAcc);
    if (match4 != null && match4.groupCount >= 1) {
      return int.tryParse(match4.group(1)!);
    }

    return null;
  }

  static String generateRoAccountNumber({
    Iterable<String>? existingAccNos,
    Iterable<RoAccount>? existingRos,
    DateTime? now,
    int? year,
    Set<String>? reservedAccNos,
  }) {
    final allAccs = <String>{};
    if (existingAccNos != null) {
      for (final acc in existingAccNos) {
        if (acc.trim().isNotEmpty) allAccs.add(acc.trim().toUpperCase());
      }
    }
    if (existingRos != null) {
      for (final r in existingRos) {
        if (r.accountNumber.trim().isNotEmpty) {
          allAccs.add(r.accountNumber.trim().toUpperCase());
        }
      }
    }
    if (reservedAccNos != null) {
      for (final acc in reservedAccNos) {
        if (acc.trim().isNotEmpty) allAccs.add(acc.trim().toUpperCase());
      }
    }

    final targetYear = year ?? (now ?? DateTime.now()).year;
    int maxSeq = 0;

    for (final acc in allAccs) {
      final seq = extractRoAccountNumberSequence(acc, year: targetYear, now: now);
      if (seq != null && seq > maxSeq) {
        maxSeq = seq;
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = formatRoAccountNumber(
      nextSeq,
      year: targetYear,
      now: now,
    );

    while (allAccs.contains(candidate.toUpperCase())) {
      nextSeq++;
      candidate = formatRoAccountNumber(
        nextSeq,
        year: targetYear,
        now: now,
      );
    }

    return candidate;
  }

  static List<String> generateRoAccountNumbersBatch(
    int count, {
    Iterable<String>? existingAccNos,
    Iterable<RoAccount>? existingRos,
    DateTime? now,
    int? year,
    Set<String>? reservedAccNos,
  }) {
    final List<String> result = [];
    final activeReserved = <String>{
      if (reservedAccNos != null) ...reservedAccNos,
    };

    for (int i = 0; i < count; i++) {
      final nextAcc = generateRoAccountNumber(
        existingAccNos: existingAccNos,
        existingRos: existingRos,
        now: now,
        year: year,
        reservedAccNos: activeReserved,
      );
      result.add(nextAcc);
      activeReserved.add(nextAcc);
    }

    return result;
  }

  // ==========================================
  // VALIDATION HELPERS
  // ==========================================

  /// Validate if a Customer ID matches the Loanee format (new short-year, 4-digit year, variant, or legacy)
  static bool isValidLoaneeCustomerId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    final clean = id.trim().toUpperCase();
    final newShortPattern = RegExp(r'^\d{2}LA\d{6,}$');
    final prevPattern = RegExp(r'^\d{4}LA\d{6,}$');
    final variantPattern = RegExp(r'^CUST\d{4}L\d{6,}$');
    final priorPattern = RegExp(r'^CUSTL\d{4}\d{4,}$');
    final legacyPattern = RegExp(r'^CUST-?\d+$');
    return newShortPattern.hasMatch(clean) ||
        prevPattern.hasMatch(clean) ||
        variantPattern.hasMatch(clean) ||
        priorPattern.hasMatch(clean) ||
        legacyPattern.hasMatch(clean);
  }

  /// Validate if a Customer ID matches the RO format (new short-year, 4-digit year, variant, or legacy)
  static bool isValidRoCustomerId(String? id) {
    if (id == null || id.trim().isEmpty) return false;
    final clean = id.trim().toUpperCase();
    final newShortPattern = RegExp(r'^\d{2}R\d{3,}$');
    final prevPattern = RegExp(r'^\d{4}R\d{3,}$');
    final variantPattern = RegExp(r'^CUST\d{4}RO\d{3,}$');
    final priorPattern = RegExp(r'^CUSTRO\d{4}\d{3,}$');
    final legacyPattern = RegExp(r'^RO-CUST-?\d+$');
    return newShortPattern.hasMatch(clean) ||
        prevPattern.hasMatch(clean) ||
        variantPattern.hasMatch(clean) ||
        priorPattern.hasMatch(clean) ||
        legacyPattern.hasMatch(clean);
  }

  /// Validate if an Account Number matches the Loanee format (new short-year, 4-digit year, or legacy)
  static bool isValidLoaneeAccountNumber(String? acc) {
    if (acc == null || acc.trim().isEmpty) return false;
    final clean = acc.trim().toUpperCase();
    final newShortPattern = RegExp(r'^MF\d{2}A\d{6,}$');
    final prevPattern = RegExp(r'^MF\d{4}A\d{6,}$');
    final legacyPattern = RegExp(r'^(ACC-?\d+|LN\d+)$');
    return newShortPattern.hasMatch(clean) ||
        prevPattern.hasMatch(clean) ||
        legacyPattern.hasMatch(clean);
  }

  /// Validate if an Account Number matches the RO format (new short-year, 4-digit year, or legacy)
  static bool isValidRoAccountNumber(String? acc) {
    if (acc == null || acc.trim().isEmpty) return false;
    final clean = acc.trim().toUpperCase();
    final newShortPattern = RegExp(r'^AC\d{2}RS\d{4,}$');
    final prevPattern = RegExp(r'^AC\d{4}RS\d{4,}$');
    final legacyPattern = RegExp(r'^RO-ACC-?\d+$');
    return newShortPattern.hasMatch(clean) ||
        prevPattern.hasMatch(clean) ||
        legacyPattern.hasMatch(clean);
  }

  // ==========================================
  // 5. ADMIN & MANAGER CUSTOMER IDs (ADM-01, MGR-01)
  // ==========================================

  static String formatAdminCustomerId(int sequence) {
    return 'ADM-${sequence.toString().padLeft(2, '0')}';
  }

  static int? extractAdminCustomerIdSequence(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    final cleanId = id.trim().toUpperCase();
    final match = RegExp(r'^ADM-(\d+)$').firstMatch(cleanId);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static String generateAdminCustomerId({
    Iterable<String>? existingIds,
    Set<String>? reservedIds,
  }) {
    final allIds = <String>{};
    if (existingIds != null) {
      for (final id in existingIds) {
        if (id.trim().isNotEmpty) allIds.add(id.trim().toUpperCase());
      }
    }
    if (reservedIds != null) {
      for (final id in reservedIds) {
        if (id.trim().isNotEmpty) allIds.add(id.trim().toUpperCase());
      }
    }

    int maxSeq = 0;
    for (final id in allIds) {
      final seq = extractAdminCustomerIdSequence(id);
      if (seq != null && seq > maxSeq) {
        maxSeq = seq;
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = formatAdminCustomerId(nextSeq);
    while (allIds.contains(candidate.toUpperCase())) {
      nextSeq++;
      candidate = formatAdminCustomerId(nextSeq);
    }
    return candidate;
  }

  static String formatManagerCustomerId(int sequence) {
    return 'MGR-${sequence.toString().padLeft(2, '0')}';
  }

  static int? extractManagerCustomerIdSequence(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    final cleanId = id.trim().toUpperCase();
    final match = RegExp(r'^MGR-(\d+)$').firstMatch(cleanId);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static String generateManagerCustomerId({
    Iterable<String>? existingIds,
    Set<String>? reservedIds,
  }) {
    final allIds = <String>{};
    if (existingIds != null) {
      for (final id in existingIds) {
        if (id.trim().isNotEmpty) allIds.add(id.trim().toUpperCase());
      }
    }
    if (reservedIds != null) {
      for (final id in reservedIds) {
        if (id.trim().isNotEmpty) allIds.add(id.trim().toUpperCase());
      }
    }

    int maxSeq = 0;
    for (final id in allIds) {
      final seq = extractManagerCustomerIdSequence(id);
      if (seq != null && seq > maxSeq) {
        maxSeq = seq;
      }
    }

    int nextSeq = maxSeq + 1;
    String candidate = formatManagerCustomerId(nextSeq);
    while (allIds.contains(candidate.toUpperCase())) {
      nextSeq++;
      candidate = formatManagerCustomerId(nextSeq);
    }
    return candidate;
  }

  // ==========================================
  // BACKWARD-COMPATIBILITY ALIASES
  // ==========================================

  static String getPrefix({
    required bool isRo,
    DateTime? now,
    int? year,
  }) {
    return isRo
        ? getRoCustomerIdPrefix(now: now, year: year)
        : getLoaneeCustomerIdPrefix(now: now, year: year);
  }

  static String formatId({
    required bool isRo,
    required int sequence,
    DateTime? now,
    int? year,
  }) {
    return isRo
        ? formatRoCustomerId(sequence, now: now, year: year)
        : formatLoaneeCustomerId(sequence, now: now, year: year);
  }

  static int? extractSequence(
    String? id, {
    required bool isRo,
    int? year,
    DateTime? now,
  }) {
    return isRo
        ? extractRoCustomerIdSequence(id, now: now, year: year)
        : extractLoaneeCustomerIdSequence(id, now: now, year: year);
  }
}
