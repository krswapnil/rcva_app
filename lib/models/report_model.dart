import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  ReportModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  factory ReportModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ReportModel(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      startDate: _toDateTime(d['startDate']) ?? DateTime.now(),
      endDate: _toDateTime(d['endDate']) ?? DateTime.now(),
      createdAt: d['createdAt'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
    }

  Map<String, dynamic> toCreateMap() => {
        'name': name.trim(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'name': name.trim(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
