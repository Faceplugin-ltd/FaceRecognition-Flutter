import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// EXAMPLE ONLY — local person gallery for the demo app (not part of the plugin).
class EnrolledPerson {
  const EnrolledPerson({
    required this.id,
    required this.name,
    required this.featureBase64,
    this.thumbnailFile,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String featureBase64;

  /// Relative filename under the app documents `thumbnails/` dir (e.g. `id.jpg`),
  /// or a legacy absolute path that [PersonDatabase.resolveThumbnail] migrates.
  final String? thumbnailFile;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'featureBase64': featureBase64,
        'thumbnailFile': thumbnailFile,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EnrolledPerson.fromJson(Map<String, dynamic> json) {
    return EnrolledPerson(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      featureBase64: json['featureBase64']?.toString() ??
          json['featureB64']?.toString() ??
          '',
      thumbnailFile: json['thumbnailFile']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  EnrolledPerson copyWith({
    String? thumbnailFile,
    bool clearThumbnail = false,
  }) {
    return EnrolledPerson(
      id: id,
      name: name,
      featureBase64: featureBase64,
      thumbnailFile:
          clearThumbnail ? null : (thumbnailFile ?? this.thumbnailFile),
      createdAt: createdAt,
    );
  }
}

/// Auto name like FaceRecognitionSDK Apps: Person1xxxx.
String autoPersonName() {
  final n = 10000 + Random().nextInt(10000);
  return 'Person$n';
}

class PersonDatabase extends ChangeNotifier {
  static const _dbFileName = 'face_enrolled_people_v1.json';
  static const _thumbsDirName = 'thumbnails';

  List<EnrolledPerson> _persons = [];
  Directory? _docs;
  Directory? _thumbs;
  bool _dirtyAfterMigrate = false;

  List<EnrolledPerson> get persons => List.unmodifiable(_persons);

  /// Feature templates in enrollment order (for VideoWorker sync).
  List<String> get featureTemplates =>
      _persons.map((e) => e.featureBase64).toList(growable: false);

  /// Absolute path to a readable thumbnail, or null if missing.
  Future<String?> resolveThumbnail(EnrolledPerson person) async {
    await _ensureDirs();
    final raw = person.thumbnailFile;
    if (raw == null || raw.isEmpty) return null;

    // Preferred: relative filename under thumbnails/.
    final relative = File(p.join(_thumbs!.path, p.basename(raw)));
    if (await relative.exists()) return relative.path;

    // Legacy absolute path (breaks after app reinstall / new container UUID).
    if (p.isAbsolute(raw)) {
      final legacy = File(raw);
      if (await legacy.exists()) {
        try {
          final dest = File(p.join(_thumbs!.path, p.basename(raw)));
          if (dest.path != legacy.path) {
            await legacy.copy(dest.path);
          }
          return dest.path;
        } catch (_) {
          return legacy.path;
        }
      }
    }
    return null;
  }

  Future<void> load() async {
    await _ensureDirs();
    final file = File(p.join(_docs!.path, _dbFileName));
    if (!await file.exists()) {
      _persons = [];
      notifyListeners();
      return;
    }
    try {
      final raw = await file.readAsString();
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        _persons = [];
      } else {
        final loaded = parsed
            .whereType<Map>()
            .map((e) => EnrolledPerson.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.id.isNotEmpty && e.featureBase64.isNotEmpty)
            .toList();
        _persons = await _migrateThumbnailPaths(loaded);
        if (_dirtyAfterMigrate) {
          await _persist();
          _dirtyAfterMigrate = false;
        }
      }
    } catch (e) {
      debugPrint('[PersonDatabase] load failed: $e');
      _persons = [];
    }
    notifyListeners();
  }

  Future<List<EnrolledPerson>> _migrateThumbnailPaths(
    List<EnrolledPerson> people,
  ) async {
    await _ensureDirs();
    final out = <EnrolledPerson>[];
    for (final person in people) {
      final raw = person.thumbnailFile;
      if (raw == null || raw.isEmpty) {
        out.add(person);
        continue;
      }
      final base = p.basename(raw);
      final dest = File(p.join(_thumbs!.path, base));
      if (await dest.exists()) {
        if (raw != base) _dirtyAfterMigrate = true;
        out.add(person.copyWith(thumbnailFile: base));
        continue;
      }
      if (p.isAbsolute(raw)) {
        final legacy = File(raw);
        if (await legacy.exists()) {
          try {
            await legacy.copy(dest.path);
            _dirtyAfterMigrate = true;
            out.add(person.copyWith(thumbnailFile: base));
            continue;
          } catch (e) {
            debugPrint('[PersonDatabase] thumb migrate failed: $e');
          }
        }
      }
      // Keep person; drop broken thumb reference so Image.file never crashes.
      _dirtyAfterMigrate = true;
      out.add(person.copyWith(clearThumbnail: true));
    }
    return out;
  }

  Future<EnrolledPerson> add({
    required String name,
    required String featureBase64,
    Uint8List? thumbnailBytes,
    String? thumbnailBase64,
  }) async {
    await _ensureDirs();
    final id =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 20).toRadixString(36)}';
    String? thumbName;
    final bytes = thumbnailBytes ??
        (thumbnailBase64 != null && thumbnailBase64.isNotEmpty
            ? base64Decode(_stripDataUrl(thumbnailBase64))
            : null);
    if (bytes != null && bytes.isNotEmpty) {
      thumbName = '$id.jpg';
      final out = File(p.join(_thumbs!.path, thumbName));
      await out.writeAsBytes(bytes, flush: true);
    }
    final person = EnrolledPerson(
      id: id,
      name: name,
      featureBase64: featureBase64,
      thumbnailFile: thumbName,
      createdAt: DateTime.now(),
    );
    _persons = [..._persons, person];
    await _persist();
    notifyListeners();
    return person;
  }

  String _stripDataUrl(String raw) {
    final i = raw.indexOf('base64,');
    if (i >= 0) return raw.substring(i + 7);
    return raw;
  }

  Future<void> remove(String id) async {
    await _ensureDirs();
    EnrolledPerson? removed;
    final next = <EnrolledPerson>[];
    for (final person in _persons) {
      if (person.id == id) {
        removed = person;
      } else {
        next.add(person);
      }
    }
    _persons = next;
    final name = removed?.thumbnailFile;
    if (name != null && name.isNotEmpty) {
      try {
        final f = File(p.join(_thumbs!.path, p.basename(name)));
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    await _ensureDirs();
    for (final person in _persons) {
      final name = person.thumbnailFile;
      if (name == null || name.isEmpty) continue;
      try {
        final f = File(p.join(_thumbs!.path, p.basename(name)));
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _persons = [];
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _ensureDirs();
    final file = File(p.join(_docs!.path, _dbFileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        _persons.map((e) => e.toJson()).toList(),
      ),
      flush: true,
    );
  }

  Future<void> _ensureDirs() async {
    if (_docs != null && _thumbs != null) return;
    _docs = await getApplicationDocumentsDirectory();
    _thumbs = Directory(p.join(_docs!.path, _thumbsDirName));
    if (!await _thumbs!.exists()) {
      await _thumbs!.create(recursive: true);
    }
  }
}
