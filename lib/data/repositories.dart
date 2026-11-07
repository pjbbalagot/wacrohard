import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'local_store.dart';

class LearningRepository {
  LearningRepository(this.store, [this.client]);
  final LocalStore store;
  final SupabaseClient? client;

  /// Pulls only published metadata. File contents are cached only when the resource
  /// explicitly permits redistribution; other items remain official-source links.
  Future<void> refreshCatalogue() async {
    if (client == null) return;
    try {
      final remote = <Map<String, dynamic>>[];
      var catalogueComplete = false;
      for (var offset = 0; offset < 500; offset += 100) {
        final page = await client!.from('resources').select(
          'id,title,description,author_organization,subject,topic,language,difficulty,origin,original_source_url,license_name,redistribution_allowed,external_url,is_published,review_status',
        ).eq('is_published', true).order('id').range(offset, offset + 99);
        remote.addAll(page);
        if (page.length < 100) { catalogueComplete = true; break; }
      }
      final db = await store.database;
      if (remote.isEmpty) { if (catalogueComplete) await db.delete('resources', where: 'remote_managed = 1'); return; }
      final ids = remote.map((r) => r['id'].toString()).toList();
      final files = <Map<String, dynamic>>[];
      final translations = <Map<String, dynamic>>[];
      for (var start = 0; start < ids.length; start += 100) {
        final chunk = ids.skip(start).take(100).toList();
        files.addAll(await client!.from('resource_files').select(
          'resource_id,storage_path,external_url,file_format,file_size_bytes,is_primary',
        ).inFilter('resource_id', chunk));
        translations.addAll(await client!.from('resource_translations').select(
          'resource_id,source_language,target_language,title,content_markdown,translation_method,review_status',
        ).inFilter('resource_id', chunk).eq('review_status', 'verified').limit(50));
      }
      final filesById = <String, List<Map<String, dynamic>>>{};
      for (final file in files) {
        final key = file['resource_id'].toString();
        filesById.putIfAbsent(key, () => []).add(Map<String, dynamic>.from(file));
      }
      var downloadBudget = 3 * 1024 * 1024;
      for (final raw in remote) {
        final item = Map<String, dynamic>.from(raw);
        final id = item['id'].toString();
        final allowed = item['redistribution_allowed'] == true;
        final candidates = filesById[id] ?? [];
        candidates.sort((a, b) => (b['is_primary'] == true ? 1 : 0).compareTo(a['is_primary'] == true ? 1 : 0));
        final file = candidates.isEmpty ? null : candidates.first;
        final existingRows = await db.query('resources', columns: ['content'], where: 'id = ?', whereArgs: [id], limit: 1);
        var content = allowed && existingRows.isNotEmpty ? (existingRows.first['content'] as String? ?? '') : '';
        String? external = item['external_url']?.toString() ?? item['original_source_url']?.toString();
        if (file != null) {
          if (file['external_url'] != null) external = file['external_url'].toString();
          final path = file['storage_path']?.toString();
          final format = (file['file_format'] ?? '').toString().toLowerCase();
          final size = (file['file_size_bytes'] as num?)?.toInt();
          if (allowed && path != null && path.isNotEmpty && size != null && size > 0 && size <= 1024 * 1024 && size <= downloadBudget && (format == 'markdown' || format == 'md' || format == 'text')) {
            try { final bytes = await client!.storage.from('learning-materials').download(path); content = utf8.decode(bytes); downloadBudget -= bytes.length; } catch (_) { /* Keep cached content or official source link; retry next refresh. */ }
          }
        }
        await db.insert('resources', {
          'id': id, 'title': item['title'], 'description': item['description'] ?? '',
          'subject': item['subject'], 'topic': item['topic'], 'language': item['language'],
          'difficulty': item['difficulty'], 'source_name': item['author_organization'] ?? 'Unknown source',
          'source_url': item['original_source_url'], 'external_url': external,
          'license': item['license_name'] ?? 'License not specified', 'content': content,
          'content_type': item['origin'] ?? 'official_source', 'is_packaged': content.isNotEmpty ? 1 : 0, 'remote_managed': 1,
          'source_language': null, 'translation_method': null, 'translation_review_status': null, 'review_status': item['review_status'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      // Only translations marked verified are cached. Machine translations cannot be
      // displayed as human-reviewed unless the backend has actually marked them verified.
      var translationBudget = 1024 * 1024;
      final cachedTranslationIds = <String>{};
      for (final raw in translations) {
        final tr = Map<String, dynamic>.from(raw);
        final base = remote.firstWhere((r) => r['id'].toString() == tr['resource_id'].toString(), orElse: () => <String, dynamic>{});
        if (base.isEmpty || base['redistribution_allowed'] != true) continue;
        final translatedContent = (tr['content_markdown'] ?? '').toString();
        if (translatedContent.isEmpty || translatedContent.length > 100000 || utf8.encode(translatedContent).length > translationBudget) continue;
        translationBudget -= utf8.encode(translatedContent).length;
        await db.insert('resources', {
          'id': '${tr['resource_id']}::${tr['target_language']}', 'title': tr['title'],
          'description': base['description'] ?? '', 'subject': base['subject'], 'topic': base['topic'],
          'language': tr['target_language'], 'difficulty': base['difficulty'],
          'source_name': '${base['author_organization'] ?? 'Unknown source'} • reviewed translation',
          'source_url': base['original_source_url'], 'external_url': null,
          'license': base['license_name'] ?? 'License not specified', 'content': translatedContent,
          'content_type': 'translation', 'is_packaged': 1, 'remote_managed': 1,
          'source_language': tr['source_language'], 'translation_method': tr['translation_method'], 'translation_review_status': tr['review_status'], 'review_status': tr['review_status'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        cachedTranslationIds.add('${tr['resource_id']}::${tr['target_language']}');
      }
      final activeIds = <String>{...ids, ...cachedTranslationIds};
      if (catalogueComplete) {
        final cached = await db.query('resources', columns: ['id'], where: 'remote_managed = 1');
        for (final row in cached) { if (!activeIds.contains(row['id'])) await db.delete('resources', where: 'id = ?', whereArgs: [row['id']]); }
      }
    } catch (_) {
      // Offline or backend unavailable: retain the last cached catalogue and packaged lessons.
    }
  }

  Future<List<Map<String, Object?>>> resources({String? query, String? subject, String? language, String? difficulty}) async {
    await store.seedIfEmpty();
    final db = await store.database; final where = <String>[]; final args = <Object?>[];
    if (query != null && query.trim().isNotEmpty) { where.add('(title LIKE ? OR description LIKE ? OR topic LIKE ?)'); final q = '%${query.trim()}%'; args.addAll([q, q, q]); }
    if (subject != null && subject.trim().toLowerCase() != 'all') { where.add('LOWER(TRIM(subject)) = ?'); args.add(subject.trim().toLowerCase()); }
    if (language != null && language.trim().toLowerCase() != 'all') { where.add('LOWER(TRIM(language)) = ?'); args.add(language.trim().toLowerCase()); }
    if (difficulty != null && difficulty.trim().toLowerCase() != 'all') { where.add('LOWER(TRIM(difficulty)) = ?'); args.add(difficulty.trim().toLowerCase()); }
    return db.query('resources', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'title');
  }
  Future<String?> get _activeUserId async => client?.auth.currentUser?.id;

  Future<List<Map<String, Object?>>> assessmentHistory() async {
    final db = await store.database; final userId = await _activeUserId;
    final local = await db.query('assessment_results', where: userId == null ? 'owner_user_id IS NULL' : '(owner_user_id IS NULL OR owner_user_id = ?)', whereArgs: userId == null ? null : [userId]);
    final merged = <String, Map<String, Object?>>{};
    for (final row in local) { merged[row['id'].toString()] = Map<String, Object?>.from(row); }
    if (userId != null) {
      final cloud = await db.query('cloud_assessments', where: 'user_id = ?', whereArgs: [userId]);
      for (final row in cloud) {
        final id = row['operation_id'].toString();
        merged.putIfAbsent(id, () => {'id': id, 'subject': row['subject'], 'score': row['score'], 'level': row['level'], 'answers': row['answers'], 'created_at': row['created_at'], 'sync_status': 'synced', 'owner_user_id': userId});
      }
    }
    final rows = merged.values.toList()..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return rows;
  }

  Future<List<Map<String, Object?>>> recentActivities({int limit = 5}) async {
    final db = await store.database; final userId = await _activeUserId;
    final local = await db.query('activities', where: userId == null ? 'owner_user_id IS NULL' : '(owner_user_id IS NULL OR owner_user_id = ?)', whereArgs: userId == null ? null : [userId]);
    final merged = <String, Map<String, Object?>>{};
    for (final row in local) { merged[row['id'].toString()] = Map<String, Object?>.from(row); }
    if (userId != null) {
      final cloud = await db.query('cloud_activities', where: 'user_id = ?', whereArgs: [userId]);
      for (final row in cloud) {
        final id = row['operation_id'].toString();
        merged.putIfAbsent(id, () => {'id': id, 'resource_id': row['resource_id'], 'activity_type': row['activity_type'], 'payload': row['payload'], 'created_at': row['created_at'], 'sync_status': 'synced', 'owner_user_id': userId});
      }
    }
    final rows = merged.values.toList()..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    final reading = rows.where((row) => row['resource_id'] != null).toList();
    if (reading.isEmpty) return [];
    final ids = reading.map((row) => row['resource_id']).toSet().toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final resources = await db.query('resources', columns: ['id', 'title'],
        where: 'id IN ($placeholders)', whereArgs: ids);
    final titles = {for (final r in resources) r['id']: r['title']};
    return reading.where((row) => titles.containsKey(row['resource_id'])).take(limit)
        .map((row) => <String, Object?>{...row, 'resource_title': titles[row['resource_id']]}).toList();
  }

  Future<double> overallProgress() async {
    final db = await store.database; final userId = await _activeUserId;
    final local = await db.query('reading_progress', where: userId == null ? 'owner_user_id IS NULL' : '(owner_user_id IS NULL OR owner_user_id = ?)', whereArgs: userId == null ? null : [userId]);
    final byResource = <String, Map<String, Object?>>{};
    for (final row in local) { byResource[row['resource_id'].toString()] = Map<String, Object?>.from(row); }
    if (userId != null) {
      final cloud = await db.query('cloud_progress', where: 'user_id = ?', whereArgs: [userId]);
      for (final row in cloud) {
        final id = row['local_resource_id'].toString();
        final current = byResource[id];
        if (current == null || (row['updated_at'] as String).compareTo(current['updated_at'] as String) > 0) {
          byResource[id] = {'resource_id': id, 'percent': row['percent'], 'updated_at': row['updated_at']};
        }
      }
    }
    if (byResource.isEmpty) return 0;
    final values = byResource.values.map((r) => (r['percent'] as num).toDouble()).toList();
    return values.reduce((a, b) => a + b) / values.length;
  }
  Future<List<Map<String, Object?>>> recommendations({String language = 'en'}) async {
    final history = await assessmentHistory();
    String? subject; String? level;
    for (final row in history) { if (row['subject'] == 'Mathematics' || row['subject'] == 'English') { subject = row['subject'] as String; level = row['level'] as String; break; } }
    if (subject == null) return resources(language: language);
    final matched = await resources(subject: subject, language: language, difficulty: level);
    if (matched.isNotEmpty) return matched;
    final sameSubject = await resources(subject: subject, language: language);
    if (sameSubject.isNotEmpty) {
      return sameSubject;
    }

    return await resources(language: language);
  }
}
