import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';

/// Reusable filter and categorization pill chip for V3.5 Obsidian Emerald UI.
///
/// Used for Library filters (Playlists, Local, Downloads), Search facets, etc.
class V35FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Widget? icon;
  final int? count;
  final VoidCallback? onTap;

  const V35FilterPill({
    super.key,
    required this.label,
    this.isSelected = false,
    this.icon,
    this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        final backgroundColor = isSelected
            ? V35Tokens.accent
            : V35Tokens.bgSurface;
        final textColor = isSelected ? V35Tokens.bgVoid : V35Tokens.textPrimary;
        final borderColor = isSelected
            ? V35Tokens.accentBright
            : V35Tokens.borderSubtle;
        final iconColor = isSelected
            ? V35Tokens.bgVoid
            : V35Tokens.textSecondary;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: V35Tokens.brFull,
            hoverColor: isSelected
                ? V35Tokens.accentBright
                : V35Tokens.bgElevated,
            splashColor: isSelected
                ? V35Tokens.accentDeep.withValues(alpha: 0.3)
                : V35Tokens.bgHighlight.withValues(alpha: 0.3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: V35Tokens.space12,
                vertical: V35Tokens.space8,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: V35Tokens.brFull,
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    IconTheme(
                      data: IconThemeData(
                        color: iconColor,
                        size: V35Tokens.iconSm,
                      ),
                      child: icon!,
                    ),
                    const SizedBox(width: V35Tokens.space4),
                  ],
                  Text(
                    label,
                    style: V35Tokens.secondary.copyWith(
                      color: textColor,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: V35Tokens.space4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? V35Tokens.bgVoid.withValues(alpha: 0.2)
                            : V35Tokens.bgElevated,
                        borderRadius: V35Tokens.brSm,
                      ),
                      child: Text(
                        count.toString(),
                        style: V35Tokens.caption.copyWith(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
