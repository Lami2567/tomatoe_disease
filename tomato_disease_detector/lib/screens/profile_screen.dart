import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/scan.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  late Future<List<Scan>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _api.getScanHistory();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: AppShell(
            child: FutureBuilder<List<Scan>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                final scans = snapshot.data ?? [];
                final healthy = scans.where((scan) => scan.isHealthy).length;
                final infected = scans.length - healthy;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: AgroColors.sky,
                              child: Text(
                                (user?.displayName.isNotEmpty == true
                                    ? user!.displayName[0].toUpperCase()
                                    : 'F'),
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AgroColors.field),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user?.displayName ?? 'Farmer',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 2),
                                  Text(user?.email ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _ProfileMetric(
                                label: 'Scans',
                                value: '${scans.length}',
                                color: AgroColors.field)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _ProfileMetric(
                                label: 'Healthy',
                                value: '$healthy',
                                color: AgroColors.leaf)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _ProfileMetric(
                                label: 'Infected',
                                value: '$infected',
                                color: AgroColors.danger)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Column(
                        children: [
                          _ProfileRow(
                              icon: Icons.cloud_done_outlined,
                              title: 'Backend API',
                              subtitle: ApiService.baseUrl),
                          Divider(
                              height: 1,
                              color: AgroColors.ink.withValues(alpha: 0.08)),
                          const _ProfileRow(
                              icon: Icons.eco_outlined,
                              title: 'Crop focus',
                              subtitle:
                                  '10-class tomato leaf disease classifier'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Sign out'),
                            content: const Text(
                                'You will need Google login to return to AgroScan.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sign out')),
                            ],
                          ),
                        );
                        if (shouldLogout == true && context.mounted) {
                          await context.read<AuthService>().logout();
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AgroColors.danger),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProfileMetric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProfileRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: AgroColors.sky, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AgroColors.field),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
    );
  }
}
