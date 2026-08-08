// lib/screens/reports_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loanee_provider.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loaneeProvider = Provider.of<LoaneeProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8B1A1A), Color(0xFF5E0F0F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports & Financial Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Portfolio performance, recovery stats & branch analytics',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Highlights
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Portfolio Monthly Summary',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B1A1A),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildReportStatRow(
                            'Total Sanctioned Loan Capital',
                            '₹ ${(loaneeProvider.totalLoanAmount / 100000).toStringAsFixed(2)} Lakhs'),
                        const Divider(height: 16),
                        _buildReportStatRow(
                            'Total Recovered Principal',
                            '₹ ${(loaneeProvider.totalCollectedAmount / 100000).toStringAsFixed(2)} Lakhs'),
                        const Divider(height: 16),
                        _buildReportStatRow(
                            'Total Outstanding Capital',
                            '₹ ${(loaneeProvider.totalDueAmount / 100000).toStringAsFixed(2)} Lakhs'),
                        const Divider(height: 16),
                        _buildReportStatRow(
                            'Overall Portfolio Recovery Rate', '84.5%'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Download Official Financial Reports',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildReportDownloadItem(
                    title: 'Monthly Collection Summary Report',
                    subtitle: 'PDF • Generated on Aug 2026',
                    icon: Icons.picture_as_pdf_rounded,
                  ),
                  _buildReportDownloadItem(
                    title: 'Loanee Account Wise Ledger',
                    subtitle: 'CSV / Excel • Updated Today',
                    icon: Icons.table_chart_rounded,
                  ),
                  _buildReportDownloadItem(
                    title: 'RO Staff Field Collection Audit',
                    subtitle: 'PDF • Officer performance sheet',
                    icon: Icons.assignment_turned_in_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportStatRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B1A1A))),
      ],
    );
  }

  Widget _buildReportDownloadItem({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF8B1A1A)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.download_rounded, color: Colors.amber),
      ),
    );
  }
}
