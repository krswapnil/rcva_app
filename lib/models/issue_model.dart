import 'package:cloud_firestore/cloud_firestore.dart';

class IssueModel {
  final String id;
  final String title;
  final String recommendation;

  /// ✅ NEW: ENGINEERING / ENFORCEMENT
  final String category;

  final bool isActive;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  IssueModel({
    required this.id,
    required this.title,
    required this.recommendation,
    required this.category,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  static String _normalizeCategory(String? v) {
    final s = (v ?? '').trim().toUpperCase();
    if (s == 'ENFORCEMENT') return 'ENFORCEMENT';
    return 'ENGINEERING';
  }

  factory IssueModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    // ✅ Backward compatible:
    // If category is missing (old data), fall back to ENGINEERING.
    final rawCategory = d['category']?.toString();
    final rawAgency = d['agency']?.toString(); // old field

    final category = _normalizeCategory(rawCategory ?? rawAgency);

    return IssueModel(
      id: doc.id,
      title: (d['title'] ?? '').toString(),
      recommendation: (d['recommendation'] ?? '').toString(),
      category: category,
      isActive: (d['isActive'] ?? true) == true,
      createdAt: d['createdAt'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'title': title.trim(),
        'recommendation': recommendation.trim(),
        'category': _normalizeCategory(category),
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'title': title.trim(),
        'recommendation': recommendation.trim(),
        'category': _normalizeCategory(category),
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
