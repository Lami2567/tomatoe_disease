import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/scan.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  int _selectedIndex = 0;
  late Future<List<Scan>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _api.getScanHistory();
  }

  void _refreshHistory() {
    setState(() => _historyFuture = _api.getScanHistory());
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      _HomeTab(
        historyFuture: _historyFuture,
        onScan: () => setState(() => _selectedIndex = 1),
        onRefresh: _refreshHistory,
      ),
      ScanScreen(onScanComplete: _refreshHistory),
      HistoryScreen(onChanged: _refreshHistory),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: destinations),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: AgroColors.moss,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera_rounded), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final Future<List<Scan>> historyFuture;
  final VoidCallback onScan;
  final VoidCallback onRefresh;

  const _HomeTab({
    required this.historyFuture,
    required this.onScan,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: FutureBuilder<List<Scan>>(
          future: historyFuture,
          builder: (context, snapshot) {
            final scans = snapshot.data ?? [];
            final total = scans.length;
            final healthy = scans.where((scan) => scan.isHealthy).length;
            final infected = total - healthy;
            final confidence = scans.isEmpty
                ? '0%'
                : '${((scans.map((scan) => scan.confidence).reduce((a, b) => a + b) / scans.length) * 100).toStringAsFixed(0)}%';

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: AppShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(name: user?.displayName ?? 'Farmer'),
                    const SizedBox(height: 18),
                    _HeroAction(onScan: onScan),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 820 ? 4 : 2;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: constraints.maxWidth > 820 ? 1.9 : 1.35,
                          children: [
                            _MetricCard(label: 'Total scans', value: '$total', icon: Icons.document_scanner_outlined, color: AgroColors.field),
                            _MetricCard(label: 'Healthy', value: '$healthy', icon: Icons.verified_outlined, color: AgroColors.leaf),
                            _MetricCard(label: 'Infected', value: '$infected', icon: Icons.warning_amber_rounded, color: AgroColors.danger),
                            _MetricCard(label: 'Avg confidence', value: confidence, icon: Icons.analytics_outlined, color: AgroColors.clay),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(title: 'Recent scans', action: total > 3 ? 'View all' : null),
                    const SizedBox(height: 12),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const _LoadingPanel()
                    else if (scans.isEmpty)
                      _EmptyPanel(onScan: onScan)
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: scans.take(3).map((scan) => _RecentScanCard(scan: scan)).toList(),
                      ),
                    const SizedBox(height: 24),
                    const _CarePanel(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;

  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $name', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('Your tomato crop health workspace is ready.', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: AgroColors.sky, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.eco_rounded, color: AgroColors.field),
        ),
      ],
    );
  }
}

class _HeroAction extends StatelessWidget {
  final VoidCallback onScan;

  const _HeroAction({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AgroColors.field,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: AgroColors.field.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 14))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Diagnose a tomato leaf', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Upload a clear leaf image and get the model prediction, confidence, and next steps.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.86)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Scan'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AgroColors.field),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;

  const _SectionTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (action != null) Text(action!, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AgroColors.field)),
      ],
    );
  }
}

class _RecentScanCard extends StatelessWidget {
  final Scan scan;

  const _RecentScanCard({required this.scan});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width > 760 ? 360 : double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scan.isHealthy ? AgroColors.sky : const Color(0xFFFFECE8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  scan.isHealthy ? Icons.verified_outlined : Icons.warning_amber_rounded,
                  color: scan.isHealthy ? AgroColors.field : AgroColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scan.readableDisease, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('${scan.confidenceLabel} confidence', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarePanel extends StatelessWidget {
  const _CarePanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AgroColors.sand, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.spa_outlined, color: AgroColors.clay),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Field care note', style: Theme.of(context).textTheme.titleMedium),
                  Text('Scan in natural light, keep one leaf centered, and avoid shadows for stronger confidence.', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final VoidCallback onScan;

  const _EmptyPanel({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.document_scanner_outlined, size: 42, color: AgroColors.field),
            const SizedBox(height: 10),
            Text('No scans yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Start with one clear tomato leaf image.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onScan, child: const Text('Scan first leaf')),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
