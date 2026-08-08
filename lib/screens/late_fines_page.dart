// lib/screens/late_fines_page.dart
import 'package:flutter/material.dart';

class LateFinesPage extends StatelessWidget {
  const LateFinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header Banner
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
                    'Late Fines & Overdue Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Monitor overdue installments and penalty calculations',
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
                  // Overview Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildFineCard(
                          title: 'Total Fine Assessed',
                          amount: '₹ 42,500',
                          subtitle: '14 Overdue Accounts',
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFineCard(
                          title: 'Fine Collected',
                          amount: '₹ 28,100',
                          subtitle: '66.1% Collected',
                          icon: Icons.check_circle_rounded,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Overdue Accounts & Penalty Records',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildOverdueItem(
                    name: 'Yumnam Ranbir Singh',
                    accountNo: 'ACC-88239103',
                    daysOverdue: 14,
                    emiAmount: '₹ 4,500',
                    fineAmount: '₹ 450',
                  ),
                  _buildOverdueItem(
                    name: 'K. Tomba Meitei',
                    accountNo: 'ACC-88239088',
                    daysOverdue: 7,
                    emiAmount: '₹ 5,000',
                    fineAmount: '₹ 250',
                  ),
                  _buildOverdueItem(
                    name: 'L. Chaoba Devi',
                    accountNo: 'ACC-88239062',
                    daysOverdue: 21,
                    emiAmount: '₹ 3,200',
                    fineAmount: '₹ 640',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFineCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(amount,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B1A1A))),
          Text(subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildOverdueItem({
    required String name,
    required String accountNo,
    required int daysOverdue,
    required String emiAmount,
    required String fineAmount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.shade50,
            child: Icon(Icons.timer_off_rounded,
                color: Colors.orange.shade800, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text('$accountNo • $daysOverdue days overdue',
                    style: TextStyle(
                        fontSize: 11, color: Colors.red.shade700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('EMI: $emiAmount',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              Text('Fine: $fineAmount',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700)),
            ],
          ),
        ],
      ),
    );
  }
}
