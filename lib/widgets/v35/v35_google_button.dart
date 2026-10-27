import 'package:flutter/material.dart';
import '../../core/theme/v35_tokens.dart';

/// Clean vector painter for official multi-color Google 'G' icon.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;

    // Scale from standard 24x24 viewport
    final double s = w / 24.0;
    canvas.save();
    canvas.scale(s, s);

    // Blue #4285F4
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.48, 23.675, 10.73, 23.55, 10.0)
      ..lineTo(12.0, 10.0)
      ..lineTo(12.0, 14.51)
      ..lineTo(18.59, 14.51)
      ..cubicTo(18.3, 16.03, 17.42, 17.31, 16.09, 18.18)
      ..lineTo(16.09, 21.28)
      ..lineTo(19.98, 21.28)
      ..cubicTo(22.26, 19.18, 23.745, 16.01, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green #34A853
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.96, 22.93, 19.98, 21.28)
      ..lineTo(16.09, 18.18)
      ..cubicTo(15.01, 18.9, 13.62, 19.33, 12.0, 19.33)
      ..cubicTo(8.87, 19.33, 6.22, 17.21, 5.27, 14.36)
      ..lineTo(1.24, 14.36)
      ..lineTo(1.24, 17.49)
      ..cubicTo(3.26, 21.49, 7.34, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow #FBBC05
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.27, 14.36)
      ..cubicTo(5.03, 13.64, 4.9, 12.87, 4.9, 12.0)
      ..cubicTo(4.9, 11.13, 5.03, 10.36, 5.27, 9.64)
      ..lineTo(5.27, 6.51)
      ..lineTo(1.24, 6.51)
      ..cubicTo(0.45, 8.16, 0.0, 10.02, 0.0, 12.0)
      ..cubicTo(0.0, 13.98, 0.45, 15.84, 1.24, 17.49)
      ..lineTo(5.27, 14.36)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red #EA4335
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12.0, 4.67)
      ..cubicTo(13.76, 4.67, 15.34, 5.28, 16.59, 6.46)
      ..lineTo(20.07, 2.98)
      ..cubicTo(17.95, 1.01, 15.23, 0.0, 12.0, 0.0)
      ..cubicTo(7.34, 0.0, 3.26, 2.51, 1.24, 6.51)
      ..lineTo(5.27, 9.64)
      ..cubicTo(6.22, 6.79, 8.87, 4.67, 12.0, 4.67)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Google 'G' icon rendered via vector canvas.
class GoogleLogoWidget extends StatelessWidget {
  final double size;

  const GoogleLogoWidget({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: GoogleLogoPainter()),
    );
  }
}

/// V3.5 Obsidian Design Language Google Sign-In Button.
///
/// Designed to seamlessly fit into the MyMusic V3.5 UI with subtle Obsidian
/// elevation, rounded border, hover state, and clear loading animation.
class V35GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const V35GoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: V35Tokens.brMd,
        hoverColor: V35Tokens.bgHighlight,
        splashColor: V35Tokens.accent.withValues(alpha: 0.15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: V35Tokens.space16,
            vertical: V35Tokens.space12 + 2,
          ),
          decoration: BoxDecoration(
            color: V35Tokens.bgElevated,
            borderRadius: V35Tokens.brMd,
            border: Border.all(color: V35Tokens.borderSubtle, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(V35Tokens.accent),
                  ),
                )
              else
                const GoogleLogoWidget(size: 20),
              const SizedBox(width: V35Tokens.space12),
              Flexible(
                child: Text(
                  isLoading ? 'Menghubungkan...' : label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: V35Tokens.title.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDisabled
                        ? V35Tokens.textMuted
                        : V35Tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
