import 'package:flutter/material.dart';
import '../app_theme.dart';

enum ToastType { success, error, warning }

class AppToast {
  AppToast._();

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bg;
    final IconData icon;

    switch (type) {
      case ToastType.success:
        bg = isDark ? DarkColors.success : AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case ToastType.error:
        bg = isDark ? DarkColors.danger : AppColors.danger;
        icon = Icons.error_outline_rounded;
        break;
      case ToastType.warning:
        bg = isDark ? DarkColors.warning : AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bg,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          elevation: 4,
        ),
      );
  }
}
