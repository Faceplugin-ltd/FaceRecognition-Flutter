import 'dart:io';

import 'package:facerecognition_flutter/utils/color_utils.dart';
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  void _showContactDetails(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: ColorUtils.blackbg,
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Contact Us',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildContactRow(
                icon: Icon(Icons.email,
                    color: ColorUtils.pinkTouch.withOpacity(0.5)),
                text: 'Email: info@faceplugin.com'),
            _buildContactRow(
                icon: Image.asset('assets/ic_skype.png',
                    width: 24, color: ColorUtils.pinkTouch.withOpacity(0.5)),
                text: 'Skype: live:.cid.6f515492327084aa'),
            _buildContactRow(
                icon: Image.asset('assets/ic_telegram.png',
                    width: 24, color: ColorUtils.pinkTouch.withOpacity(0.5)),
                text: 'Telegram: https://t.me/faceplugin'),
            _buildContactRow(
                icon: Image.asset('assets/ic_whatsapp.png',
                    width: 24, color: ColorUtils.pinkTouch.withOpacity(0.5)),
                text: 'WhatsApp: +14422295661'),
            _buildContactRow(
                icon: Image.asset('assets/ic_github.png',
                    width: 24, color: ColorUtils.pinkTouch.withOpacity(0.5)),
                text: 'Github: https://github.com/Faceplugin-ltd'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({required Widget icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 40,
        ),
        child: SingleChildScrollView(
            child: Stack(
          children: [
            Platform.isIOS
                ? Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                        iconSize: 20,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.arrow_back_ios)),
                  )
                : SizedBox(),
            Column(
              children: [
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 200,
                    height: 200,
                  ),
                ),
                SizedBox(
                  height: 40,
                ),
                Center(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          30,
                        ),
                      ),
                    ),
                    onPressed: () => _showContactDetails(
                      context,
                    ),
                    child: Text(
                      'Contact Us',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontSize: 20),
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                ),
                Text(
                  "We are a leading provider of SDKs for advanced biometric authentication technology, "
                  "including face recognition, liveness detection, and ID card recognition.\n\n"
                  "In addition to biometric authentication solutions, we provide software development "
                  "services for computer vision and mobile applications.\n\n"
                  "With our team's extensive knowledge and proficiency in these areas, we can deliver "
                  "exceptional results to our clients.\n\n"
                  "If you're interested in learning more about how we can help you, please don't hesitate "
                  "to get in touch with us today.",
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ],
        )),
      ),
    );
  }
}
