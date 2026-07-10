import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? DarkColors.bg : AppColors.bg;
    final surface = isDark ? DarkColors.surface : AppColors.surface;
    final border = isDark ? DarkColors.border : AppColors.border;
    final primary = isDark ? DarkColors.primary : AppColors.primary;
    final textPrimary = isDark ? DarkColors.textPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? DarkColors.textSecondary : AppColors.textSecondary;
    final isGuardian = context.watch<AuthProvider>().user?.isGuardian == true;

    final steps = isGuardian
        ? [
            _GuideStep(
              Icons.group_outlined,
              'Connect recipients',
              'Add or edit care recipients from Settings.',
            ),
            _GuideStep(
              Icons.videocam_outlined,
              'Check live status',
              'Use Home to view each recipient live and check their status.',
            ),
            _GuideStep(
              Icons.crop_free_outlined,
              'Set safe zones',
              'Set detection zones per recipient from Settings > Safe Zone.',
            ),
          ]
        : [
            _GuideStep(
              Icons.camera_alt_outlined,
              'Connect camera',
              'Check Home to confirm the live camera is visible.',
            ),
            _GuideStep(
              Icons.crop_free_outlined,
              'Set safe zones',
              'Set the detection area and camera direction in Settings.',
            ),
            _GuideStep(
              Icons.favorite_border_rounded,
              'Link guardian',
              'Link a guardian from Profile to share alerts.',
            ),
          ];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo/logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MobiCare',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Before you begin',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'How to use this app',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A quick guide to the first things to set up.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: steps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(step.icon, color: primary, size: 21),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  step.body,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.read<AuthProvider>().completeOnboarding(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Get started',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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
}

class _GuideStep {
  final IconData icon;
  final String title;
  final String body;

  const _GuideStep(this.icon, this.title, this.body);
}
