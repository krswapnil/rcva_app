import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/issue_model.dart';
import '../models/report_model.dart';
import '../models/location_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ Issues are GLOBAL (same master list for everyone)
  CollectionReference<Map<String, dynamic>> get _issuesCol =>
      _db.collection('issues_master');

  // ✅ Reports are USER-SCOPED (projects within logged-in ID)
  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      throw Exception('Not logged in');
    }
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> get _reportsCol => _db
      .collection('users')
      .doc(_uid)
      .collection('reports');

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  String _normTitle(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// ✅ FIXED: tolerant category normalization.
  /// - Keeps exact ENGINEERING / ENFORCEMENT
  /// - Detects variants like "Enforcement Issues", "Traffic Police", etc.
  /// - Falls back to ENGINEERING
  String _normCategory(dynamic v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (s.isEmpty) return 'ENGINEERING';

    // exact
    if (s == 'ENFORCEMENT') return 'ENFORCEMENT';
    if (s == 'ENGINEERING') return 'ENGINEERING';

    // tolerant detection
    if (s.contains('ENFORCE') ||
        s.contains('POLICE') ||
        s.contains('RTO') ||
        s.contains('TRANSPORT') ||
        s.contains('TRAFFIC')) {
      return 'ENFORCEMENT';
    }
    if (s.contains('ENGINEER')) return 'ENGINEERING';

    return 'ENGINEERING';
  }

  /// Deterministic doc ID => prevents duplicates forever.
  /// Example: ENGINEERING_absent-crash-barrier
  String _issueDocId(String category, String title) {
    final c = category.trim().toUpperCase();

    final t = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-') // spaces -> hyphen
        .replaceAll(RegExp(r'-+'), '-') // collapse hyphens
        .trim();

    return '${c}_$t';
  }

  // ------------------------------------------------------------
  // DEBUG
  // ------------------------------------------------------------
  Future<int> debugCountIssues() async {
    final snap = await _issuesCol.get();
    // ignore: avoid_print
    print('debugCountIssues: total docs in issues_master = ${snap.docs.length}');
    return snap.docs.length;
  }

  /// ✅ Helpful debug: see if ENFORCEMENT docs exist and how many.
  Future<void> debugCategoryCounts() async {
    final snap = await _issuesCol.get();
    int eng = 0, enf = 0, other = 0;

    for (final d in snap.docs) {
      final c = (d.data()['category'] ?? '').toString().trim().toUpperCase();
      if (c == 'ENGINEERING') {
        eng++;
      } else if (c == 'ENFORCEMENT') {
        enf++;
      } else {
        other++;
      }
    }

    // ignore: avoid_print
    print(
      'debugCategoryCounts => ENGINEERING=$eng, ENFORCEMENT=$enf, OTHER=$other, TOTAL=${snap.docs.length}',
    );
  }

  // ------------------------------------------------------------
  // Ensure issues ready (seed + migrate old docs + ensure enforcement exists)
  // ------------------------------------------------------------
  Future<void> ensureIssuesReady(List<IssueModel> seed) async {
    await seedIfEmpty(seed);
    await seedCategoryIfMissing();
    await seedEnforcementIfMissing(seed);
  }

  // ------------------------------------------------------------
  // ✅ ONE-TIME CLEANUP (MIGRATE + DELETE DUPLICATES)
  // For each (category + normalizedTitle):
  // - Write/merge ONE canonical doc at deterministic ID
  // - Delete all other docs in that group
  // ------------------------------------------------------------
  Future<int> cleanupAndCanonicalizeIssues() async {
    final snap = await _issuesCol.get();
    if (snap.docs.isEmpty) return 0;

    final groups = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final d in snap.docs) {
      final data = d.data();
      final titleRaw = (data['title'] ?? '').toString();
      final titleNorm = _normTitle(titleRaw);
      if (titleNorm.isEmpty) continue;

      // ✅ FIXED: normalize category robustly (prevents enforcement becoming engineering)
      final cat = _normCategory(data['category']);
      final key = '$cat|$titleNorm';
      groups.putIfAbsent(key, () => []).add(d);
    }

    int deleted = 0;

    WriteBatch batch = _db.batch();
    int ops = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (ops >= 450 || (force && ops > 0)) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }

    for (final entry in groups.entries) {
      final key = entry.key;
      final docs = entry.value;

      final parts = key.split('|');
      final category = parts[0];
      final normalizedTitle = parts[1];

      // Pick "best" doc as source: longest recommendation (usually most complete)
      docs.sort((a, b) {
        final ar = (a.data()['recommendation'] ?? '').toString().length;
        final br = (b.data()['recommendation'] ?? '').toString().length;
        return br.compareTo(ar);
      });

      final winner = docs.first;
      final winnerData = winner.data();

      final title = (winnerData['title'] ?? '').toString().trim();
      final rec = (winnerData['recommendation'] ?? '').toString().trim();
      final isActive = (winnerData['isActive'] ?? true) == true;

      // canonical deterministic doc id
      final canonicalId = _issueDocId(
        category,
        title.isEmpty ? normalizedTitle : title,
      );
      final canonicalRef = _issuesCol.doc(canonicalId);

      // 1) Upsert canonical doc
      batch.set(
        canonicalRef,
        {
          'title': title.isEmpty ? normalizedTitle : title,
          'recommendation': rec,
          'category': category,
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': winnerData['createdAt'] ?? FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      ops++;
      await commitIfNeeded();

      // 2) Delete all docs in group except canonical doc id
      for (final d in docs) {
        if (d.id == canonicalId) continue;
        batch.delete(d.reference);
        ops++;
        deleted++;
        await commitIfNeeded();
      }
    }

    await commitIfNeeded(force: true);

    // ignore: avoid_print
    print('cleanupAndCanonicalizeIssues: deleted $deleted duplicates');
    return deleted;
  }

  // ------------------------------------------------------------
  // Migration: add `category` to old docs that don't have it
  // ------------------------------------------------------------
  Future<void> seedCategoryIfMissing() async {
    try {
      final snap = await _issuesCol.get();
      if (snap.docs.isEmpty) return;

      final toUpdate = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final d in snap.docs) {
        final data = d.data();
        final hasCategory = data.containsKey('category') &&
            (data['category']?.toString().trim().isNotEmpty ?? false);
        if (!hasCategory) toUpdate.add(d);
      }

      if (toUpdate.isEmpty) {
        // ignore: avoid_print
        print('seedCategoryIfMissing: nothing to migrate');
        return;
      }

      const chunkSize = 450;
      int migrated = 0;

      for (int i = 0; i < toUpdate.length; i += chunkSize) {
        final chunk =
            toUpdate.sublist(i, (i + chunkSize).clamp(0, toUpdate.length));

        final batch = _db.batch();

        for (final doc in chunk) {
          final data = doc.data();

          // some older docs used "agency" to infer category
          final agency = (data['agency'] ?? '').toString().trim().toUpperCase();

          final isEnforcement = agency.contains('POLICE') ||
              agency.contains('ENFORCEMENT') ||
              agency.contains('RTO') ||
              agency.contains('TRANSPORT') ||
              agency.contains('TRAFFIC');

          final cat = isEnforcement ? 'ENFORCEMENT' : 'ENGINEERING';

          batch.update(doc.reference, {
            'category': cat,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        migrated += chunk.length;
      }

      // ignore: avoid_print
      print('seedCategoryIfMissing: migrated $migrated issue docs');
    } catch (e) {
      // ignore: avoid_print
      print('seedCategoryIfMissing failed: $e');
      rethrow;
    }
  }

  // ------------------------------------------------------------
  // MASTER ISSUES (Idempotent seeding - prevents duplicates forever)
  // ------------------------------------------------------------
  Future<void> forceSeedIssues(List<IssueModel> seed) async {
    try {
      const chunkSize = 450;

      for (int i = 0; i < seed.length; i += chunkSize) {
        final chunk = seed.sublist(i, (i + chunkSize).clamp(0, seed.length));
        final batch = _db.batch();

        for (final it in chunk) {
          final title = it.title.trim();
          final rec = it.recommendation.trim();

          final category = _normCategory(
            it.category.trim().isEmpty ? 'ENGINEERING' : it.category,
          );

          final docId = _issueDocId(category, title);
          final ref = _issuesCol.doc(docId);

          batch.set(
            ref,
            {
              'title': title,
              'recommendation': rec,
              'category': category,
              'isActive': true,
              'updatedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> seedIfEmpty(List<IssueModel> seed) async {
    final first = await _issuesCol.limit(1).get();
    if (first.docs.isNotEmpty) return;
    await forceSeedIssues(seed);
  }

  Future<void> seedEnforcementIfMissing(List<IssueModel> seed) async {
    final existing = await _issuesCol
        .where('category', isEqualTo: 'ENFORCEMENT')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    final enforcementSeed = seed
        .where((e) => _normCategory(e.category) == 'ENFORCEMENT')
        .toList();
    if (enforcementSeed.isEmpty) return;

    await forceSeedIssues(enforcementSeed);
  }

  Stream<List<IssueModel>> watchAllIssues() {
    return _issuesCol.orderBy('title').snapshots().map((snap) {
      final all = snap.docs.map((d) => IssueModel.fromDoc(d)).toList();
      return all.where((e) => e.isActive == true).toList();
    });
  }

  Stream<List<IssueModel>> watchIssuesByCategory(String category) {
    final c = _normCategory(category);
    return _issuesCol
        .where('category', isEqualTo: c)
        .orderBy('title')
        .snapshots()
        .map((snap) {
      final all = snap.docs.map((d) => IssueModel.fromDoc(d)).toList();
      return all.where((e) => e.isActive == true).toList();
    });
  }

  Future<void> upsertIssue({
    String? id,
    required String title,
    required String recommendation,
    required String category,
  }) async {
    final t = title.trim();
    final r = recommendation.trim();
    final c = _normCategory(category);

    if (c != 'ENGINEERING' && c != 'ENFORCEMENT') {
      throw Exception('Invalid category');
    }

    if (id == null) {
      // deterministic id for manual add too
      final docId = _issueDocId(c, t);
      await _issuesCol.doc(docId).set(
        {
          'title': t,
          'recommendation': r,
          'category': c,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } else {
      await _issuesCol.doc(id).update({
        'title': t,
        'recommendation': r,
        'category': c,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> setIssueActive(String issueId, bool isActive) async {
    await _issuesCol.doc(issueId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------
  // Get issues by IDs (whereIn chunking)
  // ------------------------------------------------------------
  Future<List<IssueModel>> getIssuesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final chunks = <List<String>>[];
    for (int i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, (i + 10).clamp(0, ids.length)));
    }

    final out = <IssueModel>[];
    for (final c in chunks) {
      final snap = await _issuesCol.where(FieldPath.documentId, whereIn: c).get();
      out.addAll(snap.docs.map((d) => IssueModel.fromDoc(d)));
    }

    out.sort((a, b) => a.title.compareTo(b.title));
    return out;
  }

  // ------------------------------------------------------------
  // REPORTS (USER-SCOPED)
  // ------------------------------------------------------------
  Stream<List<ReportModel>> watchReports() {
    return _reportsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReportModel.fromDoc(d)).toList());
  }

  Future<String> createReport(ReportModel report) async {
    final ref = await _reportsCol.add(report.toCreateMap());
    return ref.id;
  }

  Future<void> updateReport(String reportId, ReportModel report) async {
    await _reportsCol.doc(reportId).update(report.toUpdateMap());
  }

  Future<ReportModel?> getReport(String reportId) async {
    final doc = await _reportsCol.doc(reportId).get();
    if (!doc.exists) return null;
    return ReportModel.fromDoc(doc);
  }

  /// OLD: only deletes report doc (kept for backward compatibility)
  Future<void> deleteReport(String reportId) async {
    await _reportsCol.doc(reportId).delete();
  }

  // ------------------------------------------------------------
  // ✅ DELETE REPORT (Deep) - deletes subcollection locations first,
  // then deletes the report doc. DOES NOT touch local images.
  // ------------------------------------------------------------
  Future<void> deleteReportDeep(String reportId) async {
    // 1) delete locations subcollection in batches
    await _deleteCollectionInBatches(_locCol(reportId));

    // 2) delete report doc
    await _reportsCol.doc(reportId).delete();
  }

  /// Deletes all docs inside a CollectionReference in batches.
  /// Safe for large collections.
  Future<void> _deleteCollectionInBatches(
    CollectionReference<Map<String, dynamic>> col, {
    int batchSize = 450,
  }) async {
    while (true) {
      final snap = await col.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  // ------------------------------------------------------------
  // LOCATIONS (USER-SCOPED because they are under user reports)
  // ------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _locCol(String reportId) =>
      _reportsCol.doc(reportId).collection('locations');

  Stream<List<LocationModel>> watchLocations(String reportId) {
    return _locCol(reportId)
        .orderBy('locationNo')
        .snapshots()
        .map((snap) => snap.docs.map((d) => LocationModel.fromDoc(d)).toList());
  }

  Future<String> createLocation(String reportId, LocationModel location) async {
    final ref = await _locCol(reportId).add(location.toCreateMap());
    return ref.id;
  }

  Future<void> updateLocation(
    String reportId,
    String locationId,
    LocationModel location,
  ) async {
    await _locCol(reportId).doc(locationId).update(location.toUpdateMap());
  }

  Future<LocationModel?> getLocation(String reportId, String locationId) async {
    final doc = await _locCol(reportId).doc(locationId).get();
    if (!doc.exists) return null;
    return LocationModel.fromDoc(doc);
  }

  Future<void> deleteLocation(String reportId, String locationId) async {
    await _locCol(reportId).doc(locationId).delete();
  }
}
