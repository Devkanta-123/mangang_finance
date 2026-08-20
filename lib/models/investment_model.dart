// lib/models/investment_model.dart

class InvestmentSettingsModel {
  final double baseAmount;
  final double interestAmount;
  final double interestRate;
  final DateTime? updatedAt;

  const InvestmentSettingsModel({
    this.baseAmount = 10000.0,
    this.interestAmount = 1500.0,
    this.interestRate = 15.0,
    this.updatedAt,
  });

  factory InvestmentSettingsModel.fromJson(Map<String, dynamic> json) {
    final base = (json['investment_base_amount'] ?? json['base_amount'] ?? 10000.0) as num;
    final interest = (json['investment_interest_amount'] ?? json['interest_amount'] ?? 1500.0) as num;
    final rate = (json['investment_interest_rate'] ?? json['interest_rate'] ?? 15.0) as num;
    final updated = json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null;

    return InvestmentSettingsModel(
      baseAmount: base.toDouble(),
      interestAmount: interest.toDouble(),
      interestRate: rate.toDouble(),
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'investment_base_amount': baseAmount,
      'investment_interest_amount': interestAmount,
      'investment_interest_rate': interestRate,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }
}

class DailyInvestmentPlan {
  final double totalPayable;
  final int tenureDays;
  final double dailyInstallment;

  DailyInvestmentPlan({
    required this.totalPayable,
    this.tenureDays = 100,
    required this.dailyInstallment,
  });
}

class WeeklyInvestmentPlan {
  final double totalPayable;
  final double tenureWeeks;
  final double weeklyInstallment;

  WeeklyInvestmentPlan({
    required this.totalPayable,
    this.tenureWeeks = 17.5,
    required this.weeklyInstallment,
  });
}

class InvestmentCalculationResult {
  final double investmentAmount;
  final double interestRate; // e.g. 15%
  final double interestAmount; // investmentAmount * (interestRate / 100)
  final double totalAmount; // investmentAmount + interestAmount
  final DailyInvestmentPlan dailyPlan;
  final WeeklyInvestmentPlan weeklyPlan;

  InvestmentCalculationResult({
    required this.investmentAmount,
    required this.interestRate,
    required this.interestAmount,
    required this.totalAmount,
    required this.dailyPlan,
    required this.weeklyPlan,
  });

  factory InvestmentCalculationResult.calculate({
    required double amount,
    required InvestmentSettingsModel settings,
    int dailyTenureDays = 100,
    double weeklyTenureWeeks = 17.5,
  }) {
    final rate = settings.interestRate > 0 ? settings.interestRate : 15.0;
    final interest = amount * (rate / 100.0);
    final total = amount + interest;

    // Daily plan
    final dailyDays = dailyTenureDays > 0 ? dailyTenureDays : 100;
    final dailyInstallment = total / dailyDays;

    // Weekly plan
    final weeklyWeeks = weeklyTenureWeeks > 0 ? weeklyTenureWeeks : 17.5;
    final weeklyInstallment = total / weeklyWeeks;

    return InvestmentCalculationResult(
      investmentAmount: amount,
      interestRate: rate,
      interestAmount: interest,
      totalAmount: total,
      dailyPlan: DailyInvestmentPlan(
        totalPayable: total,
        tenureDays: dailyDays,
        dailyInstallment: dailyInstallment,
      ),
      weeklyPlan: WeeklyInvestmentPlan(
        totalPayable: total,
        tenureWeeks: weeklyWeeks,
        weeklyInstallment: weeklyInstallment,
      ),
    );
  }
}
