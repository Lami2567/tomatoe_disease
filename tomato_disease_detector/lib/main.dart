import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  runApp(MyApp(initialToken: token));
}

class MyApp extends StatelessWidget {
  final String? initialToken;
  const MyApp({super.key, this.initialToken});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(initialToken: initialToken),
      child: MaterialApp(
        title: 'AgroScan',
        debugShowCheckedModeBanner: false,
        theme: buildAgroTheme(),
        home: Consumer<AuthService>(
          builder: (context, auth, _) {
            if (auth.isLoading) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (auth.isAuthenticated) {
              return const DashboardScreen();
            }
            return FutureBuilder<bool>(
              future: checkOnboardingSeen(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return const AuthScreen();
                } else {
                  return const OnboardingScreen();
                }
              },
            );
          },
        ),
      ),
    );
  }

  Future<bool> checkOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_seen') ?? false;
  }
}
