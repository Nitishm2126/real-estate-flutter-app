import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/customer_service.dart';
import '../utils/theme.dart';
import '../widgets/customer_card.dart';

class FollowUpListScreen extends StatefulWidget {
  const FollowUpListScreen({
    super.key,
    required this.initialFilter,
    required this.title,
    this.isInline = false,
  });

  final SortMode initialFilter;
  final String title;
  final bool isInline;

  @override
  State<FollowUpListScreen> createState() => _FollowUpListScreenState();
}

class _FollowUpListScreenState extends State<FollowUpListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = [
    SortMode.followUpsOverdue,
    SortMode.followUpsToday,
    SortMode.followUpsUpcoming,
    SortMode.followUpsCompleted,
    SortMode.followUpsAll,
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = _tabs.indexOf(widget.initialFilter);
    if (initialIndex == -1) initialIndex = 1; // Default to Today

    _tabController =
        TabController(length: 5, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Follow-ups'),
        automaticallyImplyLeading: !widget.isInline,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'OVERDUE'),
            Tab(text: 'TODAY'),
            Tab(text: 'UPCOMING'),
            Tab(text: 'COMPLETED'),
            Tab(text: 'ALL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FollowUpTabContent(mode: SortMode.followUpsOverdue, isInline: widget.isInline),
          _FollowUpTabContent(mode: SortMode.followUpsToday, isInline: widget.isInline),
          _FollowUpTabContent(mode: SortMode.followUpsUpcoming, isInline: widget.isInline),
          _FollowUpTabContent(mode: SortMode.followUpsCompleted, isInline: widget.isInline),
          _FollowUpTabContent(mode: SortMode.followUpsAll, isInline: widget.isInline),
        ],
      ),
    );
  }
}

class _FollowUpTabContent extends StatelessWidget {
  const _FollowUpTabContent({required this.mode, required this.isInline});
  final SortMode mode;
  final bool isInline;

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerService>(
      builder: (context, service, child) {
        // Local filtering logic based on CustomerService's helper
        var list = service.allCustomersUnfiltered;

        switch (mode) {
          case SortMode.followUpsToday:
            list =
                list.where((c) => service.getFollowUpPriority(c) == 1).toList();
            break;
          case SortMode.followUpsOverdue:
            list =
                list.where((c) => service.getFollowUpPriority(c) == 0).toList();
            break;
          case SortMode.followUpsUpcoming:
            list =
                list.where((c) => service.getFollowUpPriority(c) == 2).toList();
            break;
          case SortMode.followUpsCompleted:
            list =
                list.where((c) => service.getFollowUpPriority(c) == 3).toList();
            break;
          case SortMode.followUpsAll:
            list =
                list.where((c) => service.getFollowUpPriority(c) != -1).toList();
            break;
          default:
            break;
        }

        // Sort by date inside the tab
        list.sort((a, b) {
          if (a.followUpDate == null || b.followUpDate == null) return 0;
          return a.followUpDate!.compareTo(b.followUpDate!);
        });

        if (service.isLoading || service.isSyncing) {
          return Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 80,
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _getEmptyStateText(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn()
                .scale(duration: 400.ms, curve: Curves.easeOutBack),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, isInline ? 160 : AppSpacing.md),
          itemCount: list.length,
          itemBuilder: (context, index) {
            return CustomerCard(
              customer: list[index],
              index: index,
            );
          },
        );
      },
    );
  }

  String _getEmptyStateText() {
    switch (mode) {
      case SortMode.followUpsOverdue:
        return 'No overdue follow-ups!';
      case SortMode.followUpsToday:
        return 'No follow-ups for today.\nYou\'re all caught up!';
      case SortMode.followUpsUpcoming:
        return 'No upcoming follow-ups scheduled.';
      case SortMode.followUpsCompleted:
        return 'No completed follow-ups yet.';
      case SortMode.followUpsAll:
        return 'No follow-ups found.';
      default:
        return 'No follow-ups';
    }
  }
}
