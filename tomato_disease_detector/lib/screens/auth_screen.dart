import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final imagePanel = _ImagePanel(isWide: isWide);
    final signInPanel = _SignInPanel(auth: auth);

    return Scaffold(
      body: SafeArea(
        child: AppShell(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isWide
                ? Row(
                    children: [
                      Expanded(flex: 6, child: imagePanel),
                      const SizedBox(width: 28),
                      Expanded(flex: 4, child: signInPanel),
                    ],
                  )
                : ListView(
                    children: [
                      SizedBox(height: 430, child: imagePanel),
                      const SizedBox(height: 22),
                      signInPanel,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  final bool isWide;

  const _ImagePanel({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/agro_reference.jpg', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AgroColors.field.withValues(alpha: 0.64),
                  AgroColors.field.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isWide ? 28 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandMark(),
                const Spacer(),
                Text(
                  'Protect each harvest with faster field diagnosis.',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'Designed for farmers and agronomy teams who need clear tomato leaf results without noisy dashboards.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInPanel extends StatelessWidget {
  final AuthService auth;

  const _SignInPanel({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome back',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Continue to scan tomato leaves, review disease history, and monitor field health.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () async {
                      try {
                        await context.read<AuthService>().signInWithGoogle();
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
              icon: auth.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Image.asset(
                      'assets/images/icons8-google-100.png',
                      width: 22,
                      height: 22,
                    ),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/playstore.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        const Text(
          'AgroScan',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ],
    );
  }
}
