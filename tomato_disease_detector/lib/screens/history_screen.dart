import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models/scan.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onChanged;

  const HistoryScreen({super.key, this.onChanged});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _api = ApiService();
  List<Scan> _scans = [];
  bool _isLoading = true;
  String? _selectedDisease;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final scans = await _api.getScanHistory();
      setState(() => _scans = scans);
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _diseaseTypes => _scans.map((scan) => scan.disease).toSet().toList()..sort();

  List<Scan> get _filteredScans {
    if (_selectedDisease == null) return _scans;
    return _scans.where((scan) => scan.disease == _selectedDisease).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan history')),
      body: SafeArea(
        child: AppShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_scans.isNotEmpty)
                SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    children: [
                      _FilterChip(label: 'All', selected: _selectedDisease == null, onTap: () => setState(() => _selectedDisease = null)),
                      ..._diseaseTypes.map(
                        (disease) => _FilterChip(
                          label: disease.replaceAll('_', ' '),
                          selected: _selectedDisease == disease,
                          onTap: () => setState(() => _selectedDisease = disease),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredScans.isEmpty
                        ? const _EmptyHistory()
                        : RefreshIndicator(
                            onRefresh: _fetchHistory,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                              itemCount: _filteredScans.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) => _HistoryCard(
                                scan: _filteredScans[index],
                                onTap: () => _showDetail(_filteredScans[index]),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(Scan scan) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scan.readableDisease, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('${scan.confidenceLabel} confidence', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              Text('Recommendation', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(scan.recommendation, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, overflow: TextOverflow.ellipsis),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AgroColors.moss,
        backgroundColor: Colors.white,
        side: BorderSide(color: AgroColors.ink.withValues(alpha: 0.08)),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Scan scan;
  final VoidCallback onTap;

  const _HistoryCard({required this.scan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = scan.isHealthy ? AgroColors.field : AgroColors.danger;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(scan.isHealthy ? Icons.verified_outlined : Icons.warning_amber_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scan.readableDisease, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text('${scan.confidenceLabel} confidence', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatDate(scan.createdAt), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded, color: AgroColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat('MMM d').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return '';
    }
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 52, color: AgroColors.field),
            const SizedBox(height: 12),
            Text('No scan history yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Completed scans will appear here with disease filters and full recommendations.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
