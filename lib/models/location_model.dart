import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String id;

  final String locationNo;
  final String locationName;
  final String agency;
  final String policeStation;

  /// ✅ Shared details: filled in Engineering tab, used for both.
  final String details;

  final double? lat;
  final double? lng;

  /// ✅ We will store 4 slots always: '', '', '', '' (either local path or URL)
  final List<String> imagePaths;

  /// imageIndex -> issueIds (keys: "0","1","2","3")
  final Map<String, List<String>> imageIssueIdsMap;

  final List<String> engineeringIssueIds;
  final List<String> enforcementIssueIds;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  LocationModel({
    required this.id,
    required this.locationNo,
    required this.locationName,
    required this.agency,
    required this.policeStation,
    required this.details,
    required this.lat,
    required this.lng,
    required this.imagePaths,
    required this.imageIssueIdsMap,
    this.engineeringIssueIds = const [],
    this.enforcementIssueIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory LocationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    final paths =
        (d['imagePaths'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

    // ensure length 4
    final fixedPaths = List<String>.filled(4, '');
    for (int i = 0; i < 4; i++) {
      if (i < paths.length) fixedPaths[i] = paths[i];
    }

    final rawMap = d['imageIssueIdsMap'];
    final Map<String, List<String>> map = {
      '0': <String>[],
      '1': <String>[],
      '2': <String>[],
      '3': <String>[],
    };

    if (rawMap is Map) {
      for (final k in ['0', '1', '2', '3']) {
        final v = rawMap[k];
        if (v is List) map[k] = v.map((e) => e.toString()).toList();
      }
    }

    final eng =
        (d['engineeringIssueIds'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

    final enf =
        (d['enforcementIssueIds'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

    return LocationModel(
      id: doc.id,
      locationNo: (d['locationNo'] ?? '').toString(),
      locationName: (d['locationName'] ?? '').toString(),
      agency: (d['agency'] ?? 'NHAI').toString(),
      policeStation: (d['policeStation'] ?? '').toString(),
      details: (d['details'] ?? '').toString(), // ✅ NEW
      lat: _toDouble(d['lat']),
      lng: _toDouble(d['lng']),
      imagePaths: fixedPaths,
      imageIssueIdsMap: map,
      engineeringIssueIds: eng,
      enforcementIssueIds: enf,
      createdAt: d['createdAt'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> toCreateMap() => {
        'locationNo': locationNo.trim(),
        'locationName': locationName.trim(),
        'agency': agency,
        'policeStation': policeStation.trim(),
        'details': details.trim(), // ✅ NEW
        'lat': lat,
        'lng': lng,
        'imagePaths': imagePaths, // length 4 always
        'imageIssueIdsMap': imageIssueIdsMap,
        'engineeringIssueIds': engineeringIssueIds,
        'enforcementIssueIds': enforcementIssueIds,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'locationNo': locationNo.trim(),
        'locationName': locationName.trim(),
        'agency': agency,
        'policeStation': policeStation.trim(),
        'details': details.trim(), // ✅ NEW
        'lat': lat,
        'lng': lng,
        'imagePaths': imagePaths,
        'imageIssueIdsMap': imageIssueIdsMap,
        'engineeringIssueIds': engineeringIssueIds,
        'enforcementIssueIds': enforcementIssueIds,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
