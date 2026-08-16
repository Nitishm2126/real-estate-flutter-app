import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/customer_service.dart';
import '../utils/theme.dart';
import '../widgets/customer_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/shimmer_list.dart';

/// Dedicated Customers screen for listing, searching, and filtering all customer leads.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.wifi_off_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.statusRed : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerService>(
      builder: (context, service, child) {
        final customers = service.customers;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Customers',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            actions: [
              if (service.isSyncing)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            strokeWidth: 2.5,
            onRefresh: () async {
              await service.syncWithDatabase();
              if (service.errorMessage == null) {
                _showSnackBar(context, 'Data Synced Successfully');
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Search & Filter controls
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  sliver: SliverToBoxAdapter(child: SearchFilterBar()),
                ),

                // Customer Count & status label
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          '${customers.length} Customer${customers.length != 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (service.isSyncing)
                          Text(
                            'Updating live database…',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Customer List
                if (service.isLoading)
                  const SliverPadding(
                    padding: EdgeInsets.only(bottom: 100),
                    sliver: SliverToBoxAdapter(child: ShimmerList()),
                  )
                else if (service.errorMessage != null && customers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                size: 48, color: AppColors.statusRed),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                service.errorMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: service.syncWithDatabase,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (customers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: EmptyState(
                        isSearchResult: service.searchQuery.trim().isNotEmpty,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, 100),
                    sliver: SliverList.builder(
                      itemCount: customers.length,
                      itemBuilder: (context, index) => CustomerCard(
                        customer: customers[index],
                        index: index,
                        onDeleted: () =>
                            _showSnackBar(context, 'Customer Deleted Successfully'),
                        onUpdated: () =>
                            _showSnackBar(context, 'Customer Updated Successfully'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
