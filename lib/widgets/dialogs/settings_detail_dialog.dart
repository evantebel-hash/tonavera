import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';
import '../../core/theme/v35_accent.dart';

class SettingsDetailDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final double maxHeight;

  const SettingsDetailDialog({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.maxWidth = 500,
    this.maxHeight = 620,
  });

  /// Static helper method to display any settings detail dialog with standardized modal overlay styling.
  static Future<T?> show<T>({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
    List<Widget>? actions,
    double maxWidth = 500,
    double maxHeight = 620,
  }) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width >= 600;

    if (isDesktop) {
      return showDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          elevation: 0,
          child: SettingsDetailDialog(
            icon: icon,
            title: title,
            subtitle: subtitle,
            actions: actions,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            child: child,
          ),
        ),
      );
    } else {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (sheetCtx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: SettingsDetailDialog(
              icon: icon,
              title: title,
              subtitle: subtitle,
              actions: actions,
              maxWidth: double.infinity,
              maxHeight: media.size.height * 0.85,
              child: child,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final effectiveMaxWidth = min(maxWidth, screenSize.width * 0.92);
    final effectiveMaxHeight = min(maxHeight, screenSize.height * 0.88);

    return ValueListenableBuilder<V35AccentPalette>(
      valueListenable: V35Accent.notifier,
      builder: (context, accentPalette, _) {
        return Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: effectiveMaxWidth,
              constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
              decoration: BoxDecoration(
                color: V35Tokens.bgElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: V35Tokens.borderSubtle, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Panel
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: V35Tokens.bgSurface,
                        border: Border(
                          bottom: BorderSide(
                            color: V35Tokens.borderSubtle,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: V35Tokens.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              color: V35Tokens.accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: V35Tokens.textPrimary,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                if (subtitle != null &&
                                    subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: V35Tokens.textSecondary,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: V35Tokens.textMuted,
                              size: 20,
                            ),
                            tooltip: 'Tutup',
                            onPressed: () => Navigator.of(context).pop(),
                            hoverColor: Colors.white10,
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // Content Panel (Scrollable)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                        child: child,
                      ),
                    ),

                    // Action / Footer Panel
                    if (actions != null && actions!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          color: V35Tokens.bgSurface,
                          border: Border(
                            top: BorderSide(
                              color: V35Tokens.borderSubtle,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
