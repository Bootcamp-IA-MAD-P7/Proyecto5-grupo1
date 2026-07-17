import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// SentiLife logo widget — uses the actual app icon asset.
class SentiLifeLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool lightMode;

  const SentiLifeLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.lightMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = lightMode ? Colors.white : AppTheme.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App icon with subtle shadow
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: [
              BoxShadow(
                color: (lightMode ? Colors.black : AppTheme.primaryColor)
                    .withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.2),
          Text(
            'SentiLife',
            style: TextStyle(
              fontSize: size * 0.32,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: size * 0.06),
          Text(
            'Health Monitoring',
            style: TextStyle(
              fontSize: size * 0.18,
              fontWeight: FontWeight.w400,
              color: (lightMode ? Colors.white : AppTheme.textSecondary)
                  .withValues(alpha: 0.85),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
