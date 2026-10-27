import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';

/// Reusable top page header bar for V3.5 Obsidian Emerald UI.
///
/// Adaptable across Home, Library, Playlists, Search, Downloads, and Settings.
class V35HeaderBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool isCompact;
  final EdgeInsetsGeometry? padding;

  const V35HeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.isCompact = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = isCompact
        ? V35Tokens.heading.copyWith(fontSize: 20)
        : V35Tokens.display.copyWith(fontSize: 26);

    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: V35Tokens.space16,
            vertical: isCompact ? V35Tokens.space8 : V35Tokens.space16,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: V35Tokens.space12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V35Tokens.secondary.copyWith(
                      color: V35Tokens.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: V35Tokens.space12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < actions!.length; i++) ...[
                  if (i > 0) const SizedBox(width: V35Tokens.space8),
                  actions![i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
