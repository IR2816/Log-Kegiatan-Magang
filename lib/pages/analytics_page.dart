import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/models.dart';
import '../services/search_filter_service.dart';
import '../services/pdf_export_service.dart';
import '../helpers/helpers.dart';

class AnalyticsPage extends StatefulWidget {
  final List<ActivityEntry> entries;
  final AppSettings settings;
  final InternshipProfile profile;

  const AnalyticsPage({
    required this.entries,
    required this.settings,
    required this.profile,
    super.key,
  });

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedWeek = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalStats = SearchFilterService.calculateStats(widget.entries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Laporan & Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Mingguan'),
            Tab(text: 'Bulanan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(totalStats),
          _buildWeeklyTab(),
          _buildMonthlyTab(),
        ],
      ),
    );
  }

  // ============= TAB 1: Ringkasan =============
  Widget _buildSummaryTab(Map<String, dynamic> stats) {
    final catStats = Map<String, dynamic>.from(stats['categoryStats'] as Map);
    final totalHrs = (stats['totalHours'] as num).toDouble();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Cards
          _buildHeaderCard(
            'Total Kegiatan',
            '${stats['totalEntries']}',
            Icons.assignment,
            Colors.blue,
          ),
          const SizedBox(height: 12),

          _buildHeaderCard(
            'Total Jam',
            '${(stats['totalHours'] as num).toDouble().toStringAsFixed(1)} jam',
            Icons.schedule,
            Colors.green,
          ),
          const SizedBox(height: 12),

          _buildHeaderCard(
            'Hari Kerja',
            '${stats['uniqueDays']} hari',
            Icons.calendar_today,
            Colors.orange,
          ),
          const SizedBox(height: 12),

          _buildHeaderCard(
            'Rata-rata per Hari',
            '${(stats['averageHoursPerDay'] as num).toDouble().toStringAsFixed(1)} jam',
            Icons.trending_up,
            Colors.purple,
          ),
          const SizedBox(height: 24),

          // Category Breakdown with Pie Chart
          const Text(
            'Breakdown Kategori',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: catStats.isEmpty
                  ? const Center(child: Text('Tidak ada data'))
                  : Column(
                      children: [
                        SizedBox(
                          height: 160,
                          child: _CategoryPieChart(
                            categoryStats: catStats,
                            totalHours: totalHrs,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: catStats.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final entries = catStats.entries.toList();
                            final categoryName = entries[index].key;
                            final hours = (entries[index].value as num).toDouble();
                            final percentage = ((hours / totalHrs) * 100).toStringAsFixed(1);
                            final category = ActivityCategory.values.firstWhere(
                              (c) => c.label == categoryName,
                              orElse: () => ActivityCategory.other,
                            );
          
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(category.icon, color: category.color, size: 18),
                                        const SizedBox(width: 8),
                                        Text(categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    Text('${hours.toStringAsFixed(1)}h ($percentage%)'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: hours / totalHrs,
                                    minHeight: 8,
                                    backgroundColor: category.color.withOpacity(0.15),
                                    color: category.color,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Heatmap
          const Text(
            'Aktivitas per Hari (Heatmap)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildHeatmap(widget.entries),
            ),
          ),
        ],
      ),
    );
  }

  // ============= TAB 2: Mingguan =============
  Widget _buildWeeklyTab() {
    final stats = SearchFilterService.getWeeklyStats(
      widget.entries,
      _selectedWeek,
    );

    final weekStart = stats['weekStart'] as DateTime;
    final weekEnd = stats['weekEnd'] as DateTime;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week selector
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedWeek = _selectedWeek.subtract(const Duration(days: 7));
                  });
                },
              ),
              Expanded(
                child: Text(
                  '${formatDate(weekStart)} - ${formatDate(weekEnd)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedWeek = _selectedWeek.add(const Duration(days: 7));
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekly stats cards
          _buildHeaderCard(
            'Jam Minggu Ini',
            '${(stats['totalHours'] as num).toDouble().toStringAsFixed(1)} jam',
            Icons.schedule,
            Colors.green,
          ),
          const SizedBox(height: 12),

          _buildHeaderCard(
            'Kegiatan',
            '${stats['totalEntries']}',
            Icons.assignment,
            Colors.blue,
          ),
          const SizedBox(height: 16),

          // Daily breakdown
          const Text(
            'Jam per Hari',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _BarChart(
                data: _buildDailyData(widget.entries, weekStart),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Export weekly report button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _exportWeeklyReport(weekStart, weekEnd),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Ekspor Laporan Mingguan (PDF)'),
            ),
          ),
        ],
      ),
    );
  }

  // ============= TAB 3: Bulanan =============
  Widget _buildMonthlyTab() {
    final stats = SearchFilterService.getMonthlyStats(
      widget.entries,
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final catStats = Map<String, dynamic>.from(stats['categoryStats'] as Map);
    final totalHrs = (stats['totalHours'] as num).toDouble();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month selector
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                },
              ),
              Expanded(
                child: Text(
                  '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly stats cards
          _buildHeaderCard(
            'Total Jam',
            '${(stats['totalHours'] as num).toDouble().toStringAsFixed(1)} jam',
            Icons.schedule,
            Colors.green,
          ),
          const SizedBox(height: 12),

          _buildHeaderCard(
            'Hari Kerja',
            '${stats['uniqueDays']} hari',
            Icons.calendar_today,
            Colors.orange,
          ),
          const SizedBox(height: 12),

          _buildHeaderCard(
            'Rata-rata per Hari',
            '${(stats['averageHoursPerDay'] as num).toDouble().toStringAsFixed(1)} jam',
            Icons.trending_up,
            Colors.purple,
          ),
          const SizedBox(height: 16),

          // Category breakdown
          const Text(
            'Kategori',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: catStats.isEmpty
                  ? const Center(child: Text('Tidak ada data'))
                  : Column(
                      children: [
                        if (catStats.isNotEmpty)
                          SizedBox(
                            height: 140,
                            child: _CategoryPieChart(
                              categoryStats: catStats,
                              totalHours: totalHrs,
                            ),
                          ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: catStats.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final entries = catStats.entries.toList();
                            final categoryName = entries[index].key;
                            final hours = (entries[index].value as num).toDouble();
                            final category = ActivityCategory.values.firstWhere(
                              (c) => c.label == categoryName,
                              orElse: () => ActivityCategory.other,
                            );

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(category.icon, color: category.color, size: 16),
                                    const SizedBox(width: 6),
                                    Text(categoryName),
                                  ],
                                ),
                                Chip(
                                  label: Text('${hours.toStringAsFixed(1)}h'),
                                  backgroundColor: category.color.withOpacity(0.15),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Export monthly report button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _exportMonthlyReport(),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Ekspor Laporan Bulanan (PDF)'),
            ),
          ),
        ],
      ),
    );
  }

  // ============= Export Methods =============

  Future<void> _exportWeeklyReport(DateTime weekStart, DateTime weekEnd) async {
    final filteredEntries = widget.entries.where((e) {
      final d = dateOnly(e.date);
      return !d.isBefore(dateOnly(weekStart)) && !d.isAfter(dateOnly(weekEnd));
    }).toList();

    if (filteredEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk minggu ini.')),
      );
      return;
    }

    final data = AppData(
      profile: widget.profile,
      entries: filteredEntries,
      settings: widget.settings,
    );
    final path = await PdfExportService.exportToPdf(data);
    if (mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ PDF mingguan disimpan di: $path')),
      );
    }
  }

  Future<void> _exportMonthlyReport() async {
    final filteredEntries = widget.entries.where((e) {
      return e.date.year == _selectedMonth.year && e.date.month == _selectedMonth.month;
    }).toList();

    if (filteredEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk bulan ini.')),
      );
      return;
    }

    final data = AppData(
      profile: widget.profile,
      entries: filteredEntries,
      settings: widget.settings,
    );
    final path = await PdfExportService.exportToPdf(data);
    if (mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ PDF bulanan disimpan di: $path')),
      );
    }
  }

  // ============= Chart Data =============

  List<_BarChartData> _buildDailyData(List<ActivityEntry> entries, DateTime weekStart) {
    final dailyData = <DateTime, double>{};
    for (int i = 0; i < 7; i++) {
      final date = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      dailyData[date] = 0.0;
    }
    for (final entry in entries) {
      final dateKey = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = dailyData[dateKey]! + entry.durationHours;
      }
    }
    return dailyData.entries.map((e) {
      return _BarChartData(
        label: _getDayName(e.key.weekday).substring(0, 3),
        value: e.value,
      );
    }).toList();
  }

  // ============= Helper Widgets =============

  Widget _buildHeaderCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(List<ActivityEntry> entries) {
    final heatmap = SearchFilterService.getHeatmapData(entries);
    final maxHours = heatmap.values.isEmpty ? 1.0 : heatmap.values.reduce((a, b) => a > b ? a : b);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: heatmap.entries.map((entry) {
        final dayName = entry.key;
        final hours = entry.value;
        final intensity = hours / maxHours;

        return Container(
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.blue.shade100,
              Colors.blue.shade700,
              intensity,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${hours.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDailyChart(List<ActivityEntry> entries, DateTime weekStart) {
    // Kept for backward compatibility but now uses _BarChart
    return _BarChart(data: _buildDailyData(entries, weekStart));
  }

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return days[weekday - 1];
  }
}

// ─── Chart Data ──────────────────────────────────────────────────────────

class _BarChartData {
  const _BarChartData({required this.label, required this.value});
  final String label;
  final double value;
}

// ─── Bar Chart Widget ────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});
  final List<_BarChartData> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = data.fold<double>(0, (m, d) => d.value > m ? d.value : m);
    final safeMax = maxValue > 0 ? maxValue : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Y-axis label
        Text(
          'Jam per Hari',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        // Bar chart
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final fraction = d.value / safeMax;
              final isDark = theme.brightness == Brightness.dark;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value label
                      Text(
                        d.value > 0 ? d.value.toStringAsFixed(1) : '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: double.infinity,
                        height: (fraction * 100).clamp(2.0, 100.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(
                            isDark ? 0.7 : 0.8,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        // X-axis labels
        Row(
          children: data.map((d) {
            return Expanded(
              child: Center(
                child: Text(
                  d.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Pie Chart Widget ────────────────────────────────────────────────────

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({
    required this.categoryStats,
    required this.totalHours,
  });

  final Map<String, dynamic> categoryStats;
  final double totalHours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (totalHours <= 0) return const Center(child: Text('Tidak ada data'));

    final entries = categoryStats.entries.toList();
    final colors = entries.map((e) {
      final category = ActivityCategory.values.firstWhere(
        (c) => c.label == e.key,
        orElse: () => ActivityCategory.other,
      );
      return category.color;
    }).toList();

    return Row(
      children: [
        // Pie chart
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _PieChartPainter(
              values: entries.map((e) => (e.value as num).toDouble()).toList(),
              colors: colors,
              total: totalHours,
              centerColor: isDark ? theme.colorScheme.surface : Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: entries.asMap().entries.map((e) {
              final idx = e.key;
              final name = e.value.key;
              final hours = (e.value.value as num).toDouble();
              final pct = ((hours / totalHours) * 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[idx],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors[idx],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({
    required this.values,
    required this.colors,
    required this.total,
    this.centerColor = Colors.white,
  });

  final List<double> values;
  final List<Color> colors;
  final double total;
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Draw center circle for donut effect
    final innerPaint = Paint()
      ..color = centerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
