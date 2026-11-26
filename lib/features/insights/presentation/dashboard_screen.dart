import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receipt_lens/features/scan/presentation/receipt_providers.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/glass.dart';
import '../../budgets/presentation/budgets_screen.dart';
import '../../budgets/presentation/budgets_section.dart';
import '../domain/month_summary.dart';
import 'insights_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthSummaryProvider);
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    // Status bar plus the standard 56 px toolbar.
    final top = MediaQuery.paddingOf(context).top + 56;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            tooltip: 'Budgets',
            icon: const Icon(Icons.savings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(child: BrandHeaderBackground()),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(16, top + 4, 16, 24),
            children: [
              _MonthPicker(month: month),
              const SizedBox(height: 12),
              ...summary.when<List<Widget>>(
                loading: () => const [
                  GlassCard(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
                ],
                error: (e, _) => [GlassCard(child: Text('Could not load: $e'))],
                data: (s) => s.isEmpty
                    ? const [
                        GlassCard(
                          child: Text(
                            'No receipts this month.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ]
                    : [
                        _TotalCard(summary: s),
                        const SizedBox(height: 16),
                        const BudgetsSection(),
                        const SizedBox(height: 16),
                        _CategorySection(summary: s, categories: categories),
                        const SizedBox(height: 16),
                        _DailySection(summary: s),
                        const SizedBox(height: 16),
                        _MerchantsSection(summary: s),
                      ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends ConsumerWidget {
  const _MonthPicker({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final canGoForward = month.isBefore(DateTime(now.year, now.month));
    final notifier = ref.read(selectedMonthProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous month',
          color: Colors.white,
          icon: const Icon(Icons.chevron_left),
          onPressed: notifier.previous,
        ),
        SizedBox(
          width: 170,
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Colors.white),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          color: Colors.white,
          disabledColor: Colors.white38,
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoForward ? notifier.next : null,
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = Colors.white.withValues(alpha: 0.85);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spent in ${DateFormat('MMMM').format(summary.month)}',
            style: TextStyle(color: soft),
          ),
          const SizedBox(height: 6),
          Text(
            summary.total.format(),
            style: theme.textTheme.displaySmall?.copyWith(
              color: Brand.butter,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.receipt_long, size: 16, color: soft),
              const SizedBox(width: 6),
              Text(
                '${summary.count} ${summary.count == 1 ? 'receipt' : 'receipts'}',
                style: TextStyle(color: soft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.summary, required this.categories});

  final MonthSummary summary;
  final Map<int, Category> categories;

  @override
  Widget build(BuildContext context) {
    Color colorOf(int id) {
      final c = categories[id];
      return c == null ? Colors.grey : Color(c.color);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: [
                    for (final c in summary.byCategory)
                      PieChartSectionData(
                        value: c.total.sen.toDouble(),
                        color: colorOf(c.categoryId),
                        title: '',
                        radius: 48,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final c in summary.byCategory)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorOf(c.categoryId),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        categories[c.categoryId]?.name ?? 'Uncategorized',
                      ),
                    ),
                    Text('${(c.total.sen * 100 / summary.total.sen).round()}%'),
                    const SizedBox(width: 12),
                    Text(
                      c.total.format(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DailySection extends StatelessWidget {
  const _DailySection({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily spending (RM)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: hidden,
                    rightTitles: hidden,
                    topTitles: hidden,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          if (day != 1 && day % 5 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$day',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < summary.dailyTotals.length; i++)
                      BarChartGroupData(
                        x: i + 1,
                        barRods: [
                          BarChartRodData(
                            toY: summary.dailyTotals[i].sen / 100,
                            width: 5,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantsSection extends StatelessWidget {
  const _MerchantsSection({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top merchants',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final m in summary.topMerchants)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m.name),
                subtitle: Text(
                  '${m.count} ${m.count == 1 ? 'receipt' : 'receipts'}',
                ),
                trailing: Text(
                  m.total.format(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
