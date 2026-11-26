import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A crisp, scalable LensCast mark drawn with vector shapes (no asset needed).
class LensCastLogo extends StatelessWidget {
  const LensCastLogo({super.key, this.size = 48, this.showGlow = true});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: size * 0.35,
                    spreadRadius: size * 0.02,
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}