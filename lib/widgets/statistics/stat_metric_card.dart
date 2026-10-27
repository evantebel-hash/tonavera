import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StatMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Gradient? gradient;

  const StatMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16.0),
        border: gradient == null
            ? Border.all(color: AppColors.divider.withValues(alpha: 0.5))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: gradient != null
                      ? Colors.white70
                      : AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primary).withValues(
                    alpha: 0.15,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: gradient != null ? Colors.white60 : AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
