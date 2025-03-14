import 'dart:async';

import 'package:facerecognition_flutter/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  final MyHomePageState homePageState;

  const SettingsPage({super.key, required this.homePageState});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class LivenessDetectionLevel {
  String levelName;
  int levelValue;

  LivenessDetectionLevel(this.levelName, this.levelValue);
}

const double _kItemExtent = 40.0;
const List<String> _livenessLevelNames = <String>[
  'Best Accuracy',
  'Light Weight',
];

class SettingsPageState extends State<SettingsPage> {
  bool _cameraLens = false;
  String _livenessThreshold = "0.7";
  String _identifyThreshold = "0.8";
  List<LivenessDetectionLevel> livenessDetectionLevel = [
    LivenessDetectionLevel('Best Accuracy', 0),
    LivenessDetectionLevel('Light Weight', 1),
  ];
  int _selectedLivenessLevel = 0;

  final livenessController = TextEditingController();
  final identifyController = TextEditingController();

  // static Future<void> initSettings() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   var firstWrite = prefs.getInt("first_write");
  //   if (firstWrite == 0) {
  //     await prefs.setInt("first_write", 1);
  //     await prefs.setInt("camera_lens", 1);
  //     await prefs.setInt("liveness_level", 0);
  //     await prefs.setString("liveness_threshold", "0.7");
  //     await prefs.setString("identify_threshold", "0.8");
  //   }
  // }

  static Future<void> initSettings() async {
    final prefs = await SharedPreferences.getInstance();

    bool isFirstWrite = prefs.getBool("first_write") ?? true;

    if (isFirstWrite) {
      await prefs.setBool("first_write", false);
      await prefs.setInt("camera_lens", 1); // Ensure front camera is active
      await prefs.setInt("liveness_level", 0);
      await prefs.setString("liveness_threshold", "0.7");
      await prefs.setString("identify_threshold", "0.8");
    }
  }

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");
    var livenessLevel = prefs.getInt("liveness_level");
    var livenessThreshold = prefs.getString("liveness_threshold");
    var identifyThreshold = prefs.getString("identify_threshold");

    setState(() {
      _cameraLens = cameraLens == 1 ? true : false;
      _livenessThreshold = livenessThreshold ?? "0.7";
      _identifyThreshold = identifyThreshold ?? "0.8";
      _selectedLivenessLevel = livenessLevel ?? 0;
      livenessController.text = _livenessThreshold;
      identifyController.text = _identifyThreshold;
    });
  }

  Future<void> restoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("first_write", 0);
    // await initSettings();
    await prefs.setBool("first_write", false);
    await prefs.setInt("camera_lens", 1); // Ensure front camera is active
    await prefs.setInt("liveness_level", 0);
    await prefs.setString("liveness_threshold", "0.7");
    await prefs.setString("identify_threshold", "0.8");
    await loadSettings();

    Fluttertoast.showToast(
      msg: "Default settings restored!",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Theme.of(context).primaryColor,
      fontSize: 14,
    );
  }

  Future<void> updateLivenessLevel(value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("liveness_level", value);
  }

  Future<void> updateCameraLens(value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("camera_lens", value ? 1 : 0);

    setState(() {
      _cameraLens = value;
    });
  }

  Future<void> updateLivenessThreshold(BuildContext context) async {
    try {
      var doubleValue = double.parse(livenessController.text);
      if (doubleValue >= 0 && doubleValue < 1.0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("liveness_threshold", livenessController.text);

        setState(() {
          _livenessThreshold = livenessController.text;
        });
      }
    } catch (e) {}

    // ignore: use_build_context_synchronously
    Navigator.pop(context, 'OK');
    setState(() {
      livenessController.text = _livenessThreshold;
    });
  }

  Future<void> updateIdentifyThreshold(BuildContext context) async {
    try {
      var doubleValue = double.parse(identifyController.text);
      if (doubleValue >= 0 && doubleValue < 1.0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("identify_threshold", identifyController.text);

        setState(() {
          _identifyThreshold = identifyController.text;
        });
      }
    } catch (e) {}

    // ignore: use_build_context_synchronously
    Navigator.pop(context, 'OK');
    setState(() {
      identifyController.text = _identifyThreshold;
    });
  }

// This shows a CupertinoModalPopup with a reasonable fixed height which hosts CupertinoPicker.
  void _showDialog(Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        // The Bottom margin is provided to align the popup above the system navigation bar.
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        // Provide a background color for the popup.
        color: CupertinoColors.systemBackground.resolveFrom(context),
        // Use a SafeArea widget to avoid system overlaps.
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            )),
        toolbarHeight: 60,
        centerTitle: true,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildCameraSection(),
                const SizedBox(height: 24),
                _buildThresholdsSection(),
                const SizedBox(height: 24),
                _buildResetSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Card(
      color: ColorUtils.blackbg,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.camera_alt_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          title: const Text('Camera Lens',
              style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: const Text('Switch between front/rear camera'),
          trailing: Switch.adaptive(
            value: _cameraLens,
            onChanged: updateCameraLens,
            activeColor: ColorUtils.pinkTouch.withOpacity(1),
            activeTrackColor: ColorUtils.pinkTouch.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdsSection() {
    return Card(
      color: ColorUtils.blackbg,
      elevation: 1,
      child: Column(
        children: [
          // _buildSettingsItem(
          //   icon: Icons.security_rounded,
          //   title: 'Liveness Level',
          //   value: _livenessLevelNames[_selectedLivenessLevel],
          //   onTap: () => _showLevelPicker(),
          // ),
          // const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.health_and_safety_rounded,
            title: 'Liveness Threshold',
            value: _livenessThreshold,
            onTap: () => _showThresholdDialog(
              context: context,
              title: 'Liveness Threshold',
              controller: livenessController,
              onConfirm: updateLivenessThreshold,
            ),
          ),
          const Divider(height: 1),
          _buildSettingsItem(
            icon: Icons.person_search_rounded,
            title: 'Face Matching Threshold',
            value: _identifyThreshold,
            onTap: () => _showThresholdDialog(
              context: context,
              title: 'Face Matching Threshold',
              controller: identifyController,
              onConfirm: updateIdentifyThreshold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetSection() {
    return Card(
      color: ColorUtils.blackbg,
      elevation: 1,
      child: Column(
        children: [
          _buildActionItem(
            icon: Icons.restart_alt_rounded,
            title: 'Restore Defaults',
            color: Theme.of(context).colorScheme.errorContainer,
            onTap: restoreSettings,
          ),
          const Divider(height: 1),
          _buildActionItem(
            icon: Icons.people_alt_rounded,
            title: 'Remove All Users',
            color: Theme.of(context).colorScheme.errorContainer,
            onTap: widget.homePageState.deleteAllPerson,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child:
            Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
        ),
      ),
      title:
          Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith()),
      onTap: onTap,
    );
  }

  void _showLevelPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Liveness Level',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...List.generate(
              _livenessLevelNames.length,
              (index) => RadioListTile<int>(
                title: Text(_livenessLevelNames[index]),
                value: index,
                groupValue: _selectedLivenessLevel,
                onChanged: (value) {
                  setState(() => _selectedLivenessLevel = value!);
                  updateLivenessLevel(value!);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThresholdDialog({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    required Function(BuildContext) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Enter value between 0-1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d?\.?\d{0,2}'))
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => onConfirm(context),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
