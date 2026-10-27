import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';

/// Reusable empty state view for V3.5 Obsidian Emerald UI.
///
/// Used when a library, playlist, search query, download list, or queue is empty.
class V35EmptyState extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String? description;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const V35EmptyState({
    super.key,
    this.icon,
    this.customIcon,
    required this.title,
    this.description,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V35Tokens.space32,
              vertical: V35Tokens.space40,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Container
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: V35Tokens.bgSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: V35Tokens.borderSubtle,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: V35Tokens.accent.withValues(alpha: 0.08),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child:
                        customIcon ??
                        Icon(
                          icon ?? Icons.music_off_rounded,
                          size: 32,
                          color: V35Tokens.textMuted,
                        ),
                  ),
                ),
                const SizedBox(height: V35Tokens.space24),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: V35Tokens.heading.copyWith(fontSize: 18),
                ),

                // Description
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: V35Tokens.space8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Text(
                      description!,
                      textAlign: TextAlign.center,
                      style: V35Tokens.secondary.copyWith(
                        color: V35Tokens.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],

                // Actions
                if (primaryActionLabel != null ||
                    secondaryActionLabel != null) ...[
                  const SizedBox(height: V35Tokens.space24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: V35Tokens.space12,
                    runSpacing: V35Tokens.space8,
                    children: [
                      if (primaryActionLabel != null)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: V35Tokens.accent,
                            foregroundColor: V35Tokens.bgVoid,
                            shape: const RoundedRectangleBorder(
                              borderRadius: V35Tokens.brFull,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: V35Tokens.space24,
                              vertical: V35Tokens.space12,
                            ),
                          ),
                          onPressed: onPrimaryAction,
                          child: Text(
                            primaryActionLabel!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (secondaryActionLabel != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: V35Tokens.textSecondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: V35Tokens.space16,
                              vertical: V35Tokens.space12,
                            ),
                          ),
                          onPressed: onSecondaryAction,
                          child: Text(secondaryActionLabel!),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
