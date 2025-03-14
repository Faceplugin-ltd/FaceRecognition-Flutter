import 'dart:async';
import 'package:facerecognition_flutter/utils/color_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:facesdk_plugin/facedetection_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'model/person.dart';

class FaceRecognitionView extends StatefulWidget {
  final List<Person> personList;
  FaceDetectionViewController? faceDetectionViewController;

  FaceRecognitionView({super.key, required this.personList});

  @override
  State<FaceRecognitionView> createState() => FaceRecognitionViewState();
}

class FaceRecognitionViewState extends State<FaceRecognitionView> {
  dynamic _faces;
  double _livenessThreshold = 0;
  double _identifyThreshold = 0;
  bool _recognized = false;
  String _identifiedName = "";
  String _identifiedSimilarity = "";
  String _identifiedLiveness = "";
  String _identifiedYaw = "";
  String _identifiedRoll = "";
  String _identifiedPitch = "";
  bool _showDetails = false;
  // ignore: prefer_typing_uninitialized_variables
  var _identifiedFace;
  // ignore: prefer_typing_uninitialized_variables
  var _enrolledFace;
  final _facesdkPlugin = FacesdkPlugin();
  FaceDetectionViewController? faceDetectionViewController;

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? livenessThreshold = prefs.getString("liveness_threshold");
    String? identifyThreshold = prefs.getString("identify_threshold");
    setState(() {
      _livenessThreshold = double.parse(livenessThreshold ?? "0.7");
      _identifyThreshold = double.parse(identifyThreshold ?? "0.8");
    });
  }

  Future<void> faceRecognitionStart() async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");

    setState(() {
      _faces = null;
      _recognized = false;
      _showDetails = false;
    });

    await faceDetectionViewController?.startCamera(cameraLens ?? 1);
  }

  Future<bool> onFaceDetected(faces) async {
    if (_recognized == true) {
      return false;
    }

    if (!mounted) return false;

    setState(() {
      _faces = faces;
    });

    bool recognized = false;
    double maxSimilarity = -1;
    String maxSimilarityName = "";
    double maxLiveness = -1;
    double maxYaw = -1;
    double maxRoll = -1;
    double maxPitch = -1;
    // ignore: prefer_typing_uninitialized_variables
    var enrolledFace, identifedFace;
    if (faces.length > 0) {
      var face = faces[0];
      for (var person in widget.personList) {
        double similarity = await _facesdkPlugin.similarityCalculation(
                face['templates'], person.templates) ??
            -1;
        if (maxSimilarity < similarity) {
          maxSimilarity = similarity;
          maxSimilarityName = person.name;
          maxLiveness = face['liveness'];
          maxYaw = face['yaw'];
          maxRoll = face['roll'];
          maxPitch = face['pitch'];
          identifedFace = face['faceJpg'];
          enrolledFace = person.faceJpg;
        }
      }

      if (maxSimilarity > _identifyThreshold &&
          maxLiveness > _livenessThreshold) {
        recognized = true;
      }
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return false;
      setState(() {
        _recognized = recognized;
        _identifiedName = maxSimilarityName;
        _identifiedSimilarity = maxSimilarity.toString();
        _identifiedLiveness = maxLiveness.toString();
        _identifiedYaw = maxYaw.toString();
        _identifiedRoll = maxRoll.toString();
        _identifiedPitch = maxPitch.toString();
        _enrolledFace = enrolledFace;
        _identifiedFace = identifedFace;
      });
      if (recognized) {
        faceDetectionViewController?.stopCamera();
        setState(() {
          _faces = null;
        });
      }
    });

    return recognized;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        faceDetectionViewController?.stopCamera();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Face Recognition',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              )),
          toolbarHeight: 60,
          centerTitle: true,
          elevation: 0,
          // backgroundColor: Theme.of(context).colorScheme.primary,
          // foregroundColor: Theme.of(context).colorScheme.onPrimary,
          // elevation: 2,
          surfaceTintColor: ColorUtils.background1,
        ),
        body: Stack(
          children: <Widget>[
            FaceDetectionView(faceRecognitionViewState: this),
            if (_faces != null)
              SizedBox.expand(
                child: CustomPaint(
                  painter: FacePainter(
                    faces: _faces,
                    livenessThreshold: _livenessThreshold,
                    theme: Theme.of(context),
                  ),
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _recognized ? _buildRecognitionResult() : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecognitionResult() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            _buildFacePair(),
            const SizedBox(height: 32),
            if (_showDetails) _buildRecognitionCard(),
            const SizedBox(height: 32),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => setState(() => _showDetails = !_showDetails),
              child: Text(
                _showDetails ? 'Hide Details' : 'Show Details',
                style:
                    TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            // FilledButton.icon(
            //   icon: const Icon(Icons.refresh_rounded, size: 20),
            //   label: const Text('Try Again'),
            // style: FilledButton.styleFrom(
            //   padding:
            //       const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            //   shape: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.circular(16),
            //   ),
            // ),
            //   onPressed: faceRecognitionStart,
            // )
          ],
        ),
      ),
    );
  }

  Widget _buildFacePair() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFaceCard('Enrolled', _enrolledFace),
        const SizedBox(
          height: 30,
        ),
        _buildFaceCard('Identified', _identifiedFace, name: _identifiedName),
      ],
    );
  }

  Widget _buildFaceCard(String label, Uint8List? image, {String? name}) {
    return Column(
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(10)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20), topRight: Radius.circular(10)),
            child: image != null
                ? Image.memory(image, fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Icon(Icons.person_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
          ),
        ),
        Container(
          width: 160,
          height: name != null ? 60 : 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              name != null
                  ? Text(
                      "ID: $name",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecognitionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ColorUtils.blackbg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow('Identified', _identifiedName),
          _buildDivider(),
          _buildInfoRow('Similarity',
              '${(_identifiedSimilarity.isEmpty ? 0 : (double.parse(_identifiedSimilarity) * 100).toStringAsFixed(1))}%'),
          _buildDivider(),
          _buildInfoRow('Liveness Score', _identifiedLiveness),
          _buildDivider(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildAngleChip('Yaw', _identifiedYaw),
              _buildAngleChip('Pitch', _identifiedPitch),
              _buildAngleChip('Roll', _identifiedRoll),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              )),
          Text(value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Widget _buildAngleChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              )),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 24,
      thickness: 0.5,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class FacePainter extends CustomPainter {
  final dynamic faces;
  final double livenessThreshold;
  final ThemeData theme;

  const FacePainter({
    required this.faces,
    required this.livenessThreshold,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (faces != null) {
      final textStyle = TextStyle(
        color: theme.colorScheme.onPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

      for (var face in faces) {
        final isLive = face['liveness'] >= livenessThreshold;
        final color = isLive ? Colors.green : theme.colorScheme.error;

        final rect = _calculateFaceRect(face, size);
        _drawFaceBox(canvas, rect, color);
        _drawFaceLabel(canvas, face, rect, textStyle, color, isLive);
      }
    }
  }

  Rect _calculateFaceRect(dynamic face, Size size) {
    final xScale = face['frameWidth'] / size.width;
    final yScale = face['frameHeight'] / size.height;
    return Offset(face['x1'] / xScale, face['y1'] / yScale) &
        Size((face['x2'] - face['x1']) / xScale,
            (face['y2'] - face['y1']) / yScale);
  }

  void _drawFaceBox(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    final borderRadius = BorderRadius.circular(8);
    final path = Path()..addRRect(borderRadius.toRRect(rect));
    canvas.drawPath(path, paint);
  }

  void _drawFaceLabel(Canvas canvas, dynamic face, Rect rect,
      TextStyle textStyle, Color color, bool isLive) {
    final textSpan = TextSpan(
      text:
          '${isLive ? 'LIVE' : 'SPOOF'} (${face['liveness'].toStringAsFixed(2)})',
      style: textStyle.copyWith(
        color: color,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      rect.left + 8,
      rect.top - textPainter.height - 4,
    );

    final backgroundRect = Rect.fromPoints(
      textOffset,
      textOffset.translate(textPainter.width + 16, textPainter.height + 8),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
      Paint()..color = Colors.transparent,
    );

    textPainter.paint(canvas, textOffset.translate(8, 4));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class FaceDetectionView extends StatefulWidget
    implements FaceDetectionInterface {
  FaceRecognitionViewState faceRecognitionViewState;

  FaceDetectionView({super.key, required this.faceRecognitionViewState});

  @override
  Future<void> onFaceDetected(faces) async {
    await faceRecognitionViewState.onFaceDetected(faces);
  }

  @override
  State<StatefulWidget> createState() => _FaceDetectionViewState();
}

class _FaceDetectionViewState extends State<FaceDetectionView> {
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'facedetectionview',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      return UiKitView(
        viewType: 'facedetectionview',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
  }

  void _onPlatformViewCreated(int id) async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");

    widget.faceRecognitionViewState.faceDetectionViewController =
        FaceDetectionViewController(id, widget);

    await widget.faceRecognitionViewState.faceDetectionViewController
        ?.initHandler();

    int? livenessLevel = prefs.getInt("liveness_level");
    await widget.faceRecognitionViewState._facesdkPlugin
        .setParam({'check_liveness_level': livenessLevel ?? 0});

    await widget.faceRecognitionViewState.faceDetectionViewController
        ?.startCamera(cameraLens ?? 1);
  }
}
