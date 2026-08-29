import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../screens/follow_up_list_screen.dart';
import '../screens/pdf_report_screen.dart';

import '../services/customer_service.dart';
import '../utils/theme.dart';

/// More Screen containing links to secondary features like Follow-ups, Reports, and Help.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: Text(
          'Support & Help',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'For any assistance, issues, or custom CRM modifications, please contact the Technical Support team at Avadi Branch.\n\nPhone: +91 72002 89643',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomerService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'More Options',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _optionCard(
            context,
            icon: Icons.notifications_active_rounded,
            color: AppColors.gold,
            title: 'Smart Follow-ups',
            description: 'Manage overdue, today, and upcoming follow-ups.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowUpListScreen(
                    initialFilter: SortMode.followUpsToday,
                    title: 'Follow-ups',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _optionCard(
            context,
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFFDC2626), // Red
            title: 'Reports & Analytics',
            description: 'Generate, preview, share, and export PDF reports.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfReportScreen(
                    customers: service.customers,
                    totalCustomers: service.totalCustomers,
                    bookedCustomers: service.bookedCustomers,
                    registrationCompleted: service.registrationCompleted,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _optionCard(
            context,
            icon: Icons.help_outline_rounded,
            color: const Color(0xFF2563EB), // Blue
            title: 'Help & Support',
            description: 'Get help using the application or contact branch support.',
            onTap: () => _showHelpDialog(context),
          ),
          const SizedBox(height: AppSpacing.md),
          _optionCard(
            context,
            icon: Icons.info_outline_rounded,
            color: AppColors.primary,
            title: 'About CRM Platform',
            description: 'Madras City Properties CRM for Avadi Branch.',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'MCP Avadi CRM',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(
                  Icons.apartment_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Madras City Properties Premium CRM for tracking and managing real estate customer leads.',
                      style: GoogleFonts.poppins(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _optionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
