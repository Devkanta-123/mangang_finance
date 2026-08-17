import 'package:flutter/material.dart';

/// Reusable AppLogo widget that loads the logo image from assets.
/// Renders as a perfect round circle by default.
class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  final bool isCircular;
  final double? borderRadius;
  final IconData fallbackIcon;
  final Color fallbackIconColor;
  final Color backgroundColor;
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.width = 160,
    this.height = 160,
    this.isCircular = true,
    this.borderRadius,
    this.fallbackIcon = Icons.currency_rupee_rounded,
    this.fallbackIconColor = const Color(0xFF8B1A1A),
    this.backgroundColor = Colors.white,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = isCircular ? width / 2 : (borderRadius ?? 16);

    Widget imageWidget = Image.asset(
      'assets/images/logo.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Try secondary filename assets/images/logo2.png or assets/logo.png before fallback icon
        return Image.asset(
          'assets/images/logo2.png',
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error2, stackTrace2) {
            return Image.asset(
              'assets/logo.png',
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error3, stackTrace3) {
                return Icon(
                  fallbackIcon,
                  size: width * 0.60,
                  color: fallbackIconColor,
                );
              },
            );
          },
        );
      },
    );

    Widget clippedImage = isCircular
        ? ClipOval(child: imageWidget)
        : ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: imageWidget,
          );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: clippedImage,
    );
  }
}
