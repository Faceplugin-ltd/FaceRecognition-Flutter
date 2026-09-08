import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// FacePlugin company logo — same asset as Android / RN demos.
class FacePluginLogo extends StatelessWidget {
  const FacePluginLogo({
    super.key,
    this.size = 120,
    this.onPressed,
  });

  final double size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/ic_faceplugin.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'FacePlugin',
    );

    if (onPressed == null) {
      return Center(child: image);
    }

    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: image,
      ),
    );
  }

  static Future<void> openWebsite() {
    return launchUrl(Uri.parse('https://faceplugin.com'));
  }
}
