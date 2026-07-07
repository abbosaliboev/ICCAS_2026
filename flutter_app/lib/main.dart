import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
      ],
      child: const MobiCareApp(),
    ),
  );
}

class MobiCareApp extends StatelessWidget {
  const MobiCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider    = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'MobiCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      locale: settingsProvider.locale,
      supportedLocales: const [
        Locale('ko'), Locale('en'), Locale('es'),
        Locale('fr'), Locale('ru'), Locale('zh'),
      ],
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? DarkColors.bg : AppColors.bg;
    final textColor = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final primary = isDark ? DarkColors.primary : AppColors.primary;

    if (auth.loading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.shield_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'MobiCare',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: primary, strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
    }
    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
