import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Amber strip shown while `/ws/chat` is down.
///
/// Messages typed while it is up stay sendable — the composer reports a failed
/// send per bubble — so this only tells the user why live updates paused.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, this.message = 'Ulanish uzildi — qayta ulanmoqda...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AppColors.tint(AppColors.warning, 0x14),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}
