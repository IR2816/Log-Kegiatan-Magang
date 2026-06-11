import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/search_filter_service.dart';

class SearchFilterPage extends StatefulWidget {
  final List<ActivityEntry> entries;
  final AppSettings settings;
  final VoidCallback onRefresh;

  const SearchFilterPage({
    required this.entries,
    required this.settings,
    required this.onRefresh,
    super.key,
  });

  @override
  State<SearchFilterPage> createState() => _SearchFilterPageState();
}

class _SearchFilterPageState extends State<SearchFilterPage> {
  late TextEditingController _searchController;
  List<ActivityEntry> _filteredEntries = [];
  
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<ActivityCategory> _selectedCategories = {};
  double _minDuration = 0.0;
  
  bool _showAdvancedFilter = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredEntries = widget.entries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final results = SearchFilterService.advancedSearch(
      widget.entries,
      keyword: _searchController.text,
      startDate: _startDate,
      endDate: _endDate,
      categories: _selectedCategories.toList(),
      minDuration: _minDuration,
    );
    
    setState(() {
      _filteredEntries = results;
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _startDate = null;
      _endDate = null;
      _selectedCategories.clear();
      _minDuration = 0.0;
      _filteredEntries = widget.entries;
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _applyFilters();
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = SearchFilterService.calculateStats(_filteredEntries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari & Filter Kegiatan'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari aktivitas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) {
                setState(() {});
                _applyFilters();
              },
            ),
            const SizedBox(height: 16),

            // Advanced filter toggle
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('🔍 Filter Lanjutan'),
                        selected: _showAdvancedFilter,
                        onSelected: (value) {
                          setState(() => _showAdvancedFilter = value);
                        },
                      ),
                      if (_startDate != null || _endDate != null || _selectedCategories.isNotEmpty || _minDuration > 0)
                        FilterChip(
                          label: const Text('Reset'),
                          onSelected: (_) => _resetFilters(),
                          avatar: const Icon(Icons.refresh, size: 16),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Advanced filters
            if (_showAdvancedFilter) ...[
              // Date range filter
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rentang Tanggal', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectStartDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _startDate == null
                                  ? 'Tanggal Mulai'
                                  : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectEndDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _endDate == null
                                  ? 'Tanggal Akhir'
                                  : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Category filter
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final category in ActivityCategory.values)
                          FilterChip(
                            label: Text(category.label),
                            selected: _selectedCategories.contains(category),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                              _applyFilters();
                            },
                            avatar: Icon(category.icon, size: 18),
                            backgroundColor: category.color.withOpacity(0.2),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Duration filter
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Durasi Minimal (jam)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _minDuration,
                            min: 0,
                            max: 12,
                            divisions: 24,
                            label: '${_minDuration.toStringAsFixed(1)} jam',
                            onChanged: (value) {
                              setState(() => _minDuration = value);
                              _applyFilters();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${_minDuration.toStringAsFixed(1)} jam',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Statistics card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hasil: ${_filteredEntries.length} kegiatan',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Total Jam',
                          (stats['totalHours'] as num).toDouble().toStringAsFixed(1),
                        ),
                        _buildStatItem(
                          'Hari',
                          '${stats['uniqueDays']}',
                        ),
                        _buildStatItem(
                          'Rata-rata/hari',
                          '${(stats['averageHoursPerDay'] as num).toDouble().toStringAsFixed(1)}h',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results list
            if (_filteredEntries.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'Tidak ada hasil',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredEntries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = _filteredEntries[index];
                  return _buildEntryCard(entry);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEntryCard(ActivityEntry entry) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(entry.category.icon, color: entry.category.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        entry.category.label,
                        style: TextStyle(color: entry.category.color, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('${entry.durationHours.toStringAsFixed(1)}h'),
                  backgroundColor: Colors.blue.shade100,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.activity),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  for (final tag in entry.tags)
                    Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 10)),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                ],
              ),
            ],
            if (entry.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text('📷 ${entry.imagePaths.length} gambar'),
                avatar: const Icon(Icons.image, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

