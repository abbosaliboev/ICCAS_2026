import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'app_theme.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
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
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'MobiCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      locale: settingsProvider.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('ru'),
        Locale('zh'),
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1.0) * 1.06),
          ),
          child: WithForegroundTask(child: child!),
        );
      },
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const _SplashScreen();
    }
    if (!auth.isLoggedIn) return const LoginScreen();
    if (auth.onboardingPending) return const OnboardingScreen();
    return const HomeScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    const splashBg = AppColors.bg;
    const splashText = AppColors.textPrimary;
    const subtitleColor = AppColors.textSecondary;
    const splashPrimary = AppColors.primary;
    return Scaffold(
      backgroundColor: splashBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: splashPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(34),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/logo/logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'MobiCare',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: splashText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fall detection and care monitoring',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: splashPrimary, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
