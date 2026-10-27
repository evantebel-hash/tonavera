import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';

/// Item descriptor for [V35ActionSheet].
class V35ActionItem {
  final String title;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isEnabled;
  final Widget? trailing;

  const V35ActionItem({
    required this.title,
    this.icon,
    this.onTap,
    this.isDestructive = false,
    this.isEnabled = true,
    this.trailing,
  });
}

/// Reusable contextual action sheet for V3.5 Obsidian Emerald UI.
///
/// Can be invoked directly via [V35ActionSheet.show].
class V35ActionSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? headerLeading;
  final List<V35ActionItem> actions;
  final String? cancelLabel;

  const V35ActionSheet({
    super.key,
    this.title,
    this.subtitle,
    this.headerLeading,
    required this.actions,
    this.cancelLabel,
  });

  /// Static helper to display the sheet modally.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? subtitle,
    Widget? headerLeading,
    required List<V35ActionItem> actions,
    String? cancelLabel,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: V35Tokens.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(V35Tokens.radiusXl),
        ),
      ),
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (ctx) => V35ActionSheet(
        title: title,
        subtitle: subtitle,
        headerLeading: headerLeading,
        actions: actions,
        cancelLabel: cancelLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: V35Tokens.bgElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(V35Tokens.radiusXl),
          ),
          border: const Border(
            top: BorderSide(color: V35Tokens.borderCard, width: 1.0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle indicator
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: V35Tokens.space8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: V35Tokens.textMuted.withValues(alpha: 0.4),
                  borderRadius: V35Tokens.brFull,
                ),
              ),
            ),

            // Header Section (optional)
            if (title != null || headerLeading != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: V35Tokens.space16,
                  vertical: V35Tokens.space8,
                ),
                child: Row(
                  children: [
                    if (headerLeading != null) ...[
                      headerLeading!,
                      const SizedBox(width: V35Tokens.space12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V35Tokens.title.copyWith(fontSize: 15),
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V35Tokens.secondary.copyWith(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: V35Tokens.borderSubtle, height: 1),
            ],

            // Action Items List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: V35Tokens.space8),
                itemCount: actions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  final color = action.isDestructive
                      ? const Color(0xFFEF4444)
                      : (action.isEnabled
                            ? V35Tokens.textPrimary
                            : V35Tokens.textDisabled);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: action.isEnabled
                          ? () {
                              Navigator.of(context).pop();
                              action.onTap?.call();
                            }
                          : null,
                      hoverColor: V35Tokens.bgHighlight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: V35Tokens.space20,
                          vertical: V35Tokens.space12,
                        ),
                        child: Row(
                          children: [
                            if (action.icon != null) ...[
                              Icon(
                                action.icon,
                                color: color,
                                size: V35Tokens.iconMd,
                              ),
                              const SizedBox(width: V35Tokens.space16),
                            ],
                            Expanded(
                              child: Text(
                                action.title,
                                style: V35Tokens.body.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (action.trailing != null) action.trailing!,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Cancel button (if provided)
            if (cancelLabel != null) ...[
              const Divider(color: V35Tokens.borderSubtle, height: 1),
              Padding(
                padding: const EdgeInsets.all(V35Tokens.space12),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    cancelLabel!,
                    style: V35Tokens.body.copyWith(
                      color: V35Tokens.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
