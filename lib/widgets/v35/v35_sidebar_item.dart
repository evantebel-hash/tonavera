import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';

/// Reusable sidebar navigation item for V3.5 Obsidian Emerald desktop layout.
///
/// Features:
/// - Smooth hover and pressed states
/// - Emerald active indicator and icon highlighting
/// - High legibility typography adhering to V3.5 design tokens
class V35SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  const V35SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  @override
  State<V35SidebarItem> createState() => _V35SidebarItemState();
}

class _V35SidebarItemState extends State<V35SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, child) {
        final isSelected = widget.isSelected;

        // Background resolution
        Color backgroundColor = Colors.transparent;
        if (isSelected) {
          backgroundColor = V35Tokens.bgElevated;
        } else if (_isHovered) {
          backgroundColor = V35Tokens.bgSurface.withValues(alpha: 0.7);
        }

        // Color resolution
        final iconColor = isSelected
            ? V35Tokens.accent
            : (_isHovered ? V35Tokens.textPrimary : V35Tokens.textSecondary);

        final textColor = isSelected
            ? V35Tokens.textPrimary
            : (_isHovered ? V35Tokens.textPrimary : V35Tokens.textSecondary);

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: V35Tokens.space8,
              vertical: V35Tokens.space2,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: V35Tokens.brMd,
                splashColor: V35Tokens.bgHighlight.withValues(alpha: 0.3),
                hoverColor: Colors.transparent, // Handled by AnimatedContainer
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: V35Tokens.space12,
                    vertical: V35Tokens.space12,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: V35Tokens.brMd,
                    border: isSelected
                        ? Border.all(color: V35Tokens.borderCard, width: 1.0)
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Active indicator pill
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 3.0,
                        height: isSelected ? 18.0 : 0.0,
                        margin: EdgeInsets.only(
                          right: isSelected ? V35Tokens.space8 : 0.0,
                        ),
                        decoration: BoxDecoration(
                          color: V35Tokens.accent,
                          borderRadius: V35Tokens.brFull,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: V35Tokens.accent.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),

                      // Navigation Icon
                      Icon(
                        widget.icon,
                        size: V35Tokens.iconMd,
                        color: iconColor,
                      ),
                      const SizedBox(width: V35Tokens.space12),

                      // Label
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V35Tokens.body.copyWith(
                            color: textColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                      ),

                      // Trailing optional widget
                      if (widget.trailing != null) widget.trailing!,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
