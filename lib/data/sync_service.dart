import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_store.dart';

class SyncService {
  static Future<void> syncIfConsented(LocalStore store, SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null || await store.preference('cloud_sync_consent') != 'true') return;
    if (await store.preference('cloud_sync_user_id') != user.id) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (!connectivity.any((state) => state != ConnectivityResult.none)) return;
    try { await SyncService(store, client).migrateApprovedRecords(); } catch (_) { /* Local rows and queue retain failed operations. */ }
  }

  SyncService(this.store, this.client);
  final LocalStore store;
  final SupabaseClient client;

  Future<Map<String, int>> pendingCounts({String? userId, bool includeGuestRecords = true}) async {
    final db = await store.database;
    final ownerFilter = userId == null ? '' : includeGuestRecords ? ' AND (owner_user_id IS NULL OR owner_user_id = ?)' : ' AND owner_user_id = ?';
    final ownerArgs = userId == null ? <Object?>[] : <Object?>[userId];
    final assessments = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM assessment_results WHERE sync_status != 'synced'$ownerFilter", ownerArgs)) ?? 0;
    final activities = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM activities WHERE sync_status != 'synced'$ownerFilter", ownerArgs)) ?? 0;
    final progress = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM reading_progress WHERE sync_status != 'synced'$ownerFilter", ownerArgs)) ?? 0;
    return {'assessments': assessments, 'activities': activities, 'progress': progress, 'total': assessments + activities + progress};
  }

  Future<Map<String, int>> statusCounts({String? userId}) async {
    final db = await store.database;
    final pending = await pendingCounts(userId: userId, includeGuestRecords: false);
    final ownerFilter = userId == null ? 'owner_user_id IS NULL' : 'owner_user_id = ?';
    final ownerArgs = userId == null ? <Object?>[] : <Object?>[userId];
    final assessmentTotal = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM assessment_results WHERE $ownerFilter', ownerArgs)) ?? 0;
    final activityTotal = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM activities WHERE $ownerFilter', ownerArgs)) ?? 0;
    final progressTotal = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reading_progress WHERE $ownerFilter', ownerArgs)) ?? 0;
    final pendingTotal = pending['total'] ?? 0;
    final localSynced = (assessmentTotal + activityTotal + progressTotal) - pendingTotal;
    var synced = localSynced;
    if (userId != null) {
      final cloudAssessments = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cloud_assessments WHERE user_id = ?', [userId])) ?? 0;
      final cloudActivities = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cloud_activities WHERE user_id = ?', [userId])) ?? 0;
      final cloudProgress = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM cloud_progress WHERE user_id = ?', [userId])) ?? 0;
      final cloudSynced = cloudAssessments + cloudActivities + cloudProgress;
      if (cloudSynced > synced) synced = cloudSynced;
    }
    return {'pending': pendingTotal, 'synced': synced, 'total': pendingTotal + synced};
  }

  /// Download only the authenticated account's cloud history into a separate local cache.
  /// Guest records and other accounts' cached rows are never overwritten.
  Future<void> restoreCloudRecords() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in before restoring cloud history.');
    final assessments = await client.from('assessments').select(
      'client_operation_id,subject,score,level,answers,completed_at',
    ).order('completed_at');
    final activities = await client.from('learning_activities').select(
      'client_operation_id,resource_id,activity_type,payload,occurred_at',
    ).order('occurred_at');
    final progress = await client.from('learning_progress').select(
      'resource_id,local_resource_id,last_position,percent_complete,updated_at,client_operation_id',
    );
    final db = await store.database;
    await db.transaction((txn) async {
      await txn.delete('cloud_assessments', where: 'user_id = ?', whereArgs: [user.id]);
      await txn.delete('cloud_activities', where: 'user_id = ?', whereArgs: [user.id]);
      await txn.delete('cloud_progress', where: 'user_id = ?', whereArgs: [user.id]);
      final batch = txn.batch();
      for (final row in assessments) {
        batch.insert('cloud_assessments', {
          'user_id': user.id, 'operation_id': row['client_operation_id'], 'subject': row['subject'],
          'score': row['score'], 'level': row['level'], 'answers': jsonEncode(row['answers']),
          'created_at': row['completed_at'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in activities) {
        batch.insert('cloud_activities', {
          'user_id': user.id, 'operation_id': row['client_operation_id'], 'resource_id': row['resource_id']?.toString(),
          'activity_type': row['activity_type'], 'payload': jsonEncode(row['payload']), 'created_at': row['occurred_at'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in progress) {
        final resourceKey = (row['local_resource_id'] ?? row['resource_id'])?.toString();
        if (resourceKey == null) continue;
        batch.insert('cloud_progress', {
          'user_id': user.id, 'local_resource_id': resourceKey, 'position': row['last_position'],
          'percent': row['percent_complete'], 'updated_at': row['updated_at'], 'operation_id': row['client_operation_id'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Invoke only after explicit approval. Stable local UUIDs make retries idempotent.
  /// Each operation is queued before transmission and marked synced only after success.
  Future<void> migrateApprovedRecords({bool includeGuestRecords = false}) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in before migrating learning records.');
    if (await store.approvedAccountId(user.id) != user.id) throw StateError('Cloud sync has not been approved for this account.');
    final db = await store.database;
    if (includeGuestRecords) {
      // Associate the full explicitly approved guest batch before network work begins.
      // If connectivity fails halfway through, all remaining rows still belong to this account.
      await db.transaction((txn) async {
        await txn.update('assessment_results', {'owner_user_id': user.id}, where: "sync_status != 'synced' AND owner_user_id IS NULL");
        await txn.update('activities', {'owner_user_id': user.id}, where: "sync_status != 'synced' AND owner_user_id IS NULL");
        await txn.update('reading_progress', {'owner_user_id': user.id}, where: "sync_status != 'synced' AND owner_user_id IS NULL");
      });
    }
    final ownerClause = includeGuestRecords ? '(owner_user_id IS NULL OR owner_user_id = ?)' : 'owner_user_id = ?';
    final assessments = await db.query('assessment_results', where: "sync_status != 'synced' AND $ownerClause", whereArgs: [user.id], orderBy: 'created_at');
    for (final row in assessments) {
      final operationId = row['id'] as String;
      await db.update('assessment_results', {'owner_user_id': user.id}, where: 'id = ?', whereArgs: [operationId]);
      final payload = {
        'subject': row['subject'], 'score': row['score'], 'level': row['level'],
        'answers': jsonDecode(row['answers'] as String), 'completed_at': row['created_at'],
      };
      await db.insert('sync_queue', {
        'operation_id': operationId, 'user_id': user.id, 'resource_id': null,
        'operation_type': 'assessment_completed', 'created_at': row['created_at'],
        'payload': jsonEncode(payload), 'status': 'pending',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      try {
        await client.from('assessments').upsert({
          'user_id': user.id, ...payload, 'client_operation_id': operationId,
        }, onConflict: 'user_id,client_operation_id', ignoreDuplicates: true);
        await db.update('assessment_results', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [operationId]);
        await db.update('sync_queue', {'status': 'synced', 'last_error': null}, where: 'operation_id = ?', whereArgs: [operationId]);
      } catch (error) {
        await db.update('sync_queue', {'status': 'failed', 'last_error': error.toString()}, where: 'operation_id = ?', whereArgs: [operationId]);
        rethrow;
      }
    }
    final progressRows = await db.query('reading_progress', where: "sync_status != 'synced' AND $ownerClause", whereArgs: [user.id], orderBy: 'updated_at');
    for (final row in progressRows) {
      final operationId = row['operation_id'] as String;
      final localResourceId = row['resource_id'] as String;
      await db.update('reading_progress', {'owner_user_id': user.id}, where: 'resource_id = ?', whereArgs: [localResourceId]);
      final payload = {'local_resource_id': localResourceId, 'last_position': row['position'], 'percent_complete': row['percent']};
      await db.insert('sync_queue', {
        'operation_id': operationId, 'user_id': user.id, 'resource_id': null,
        'operation_type': 'reading_progress', 'created_at': row['updated_at'],
        'payload': jsonEncode(payload), 'status': 'pending',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      try {
        await client.from('learning_progress').upsert({
          'user_id': user.id, 'resource_id': null, 'local_resource_id': localResourceId,
          'last_position': row['position'], 'percent_complete': row['percent'],
          'updated_at': row['updated_at'], 'client_operation_id': operationId,
        }, onConflict: 'user_id,local_resource_id');
        await db.update('reading_progress', {'sync_status': 'synced'}, where: 'resource_id = ?', whereArgs: [localResourceId]);
        await db.update('sync_queue', {'status': 'synced', 'last_error': null}, where: 'operation_id = ?', whereArgs: [operationId]);
      } catch (error) {
        await db.update('sync_queue', {'status': 'failed', 'last_error': error.toString()}, where: 'operation_id = ?', whereArgs: [operationId]);
        rethrow;
      }
    }
    final activities = await db.query('activities', where: "sync_status != 'synced' AND $ownerClause", whereArgs: [user.id], orderBy: 'created_at');
    for (final row in activities) {
      final operationId = row['id'] as String;
      await db.update('activities', {'owner_user_id': user.id}, where: 'id = ?', whereArgs: [operationId]);
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      await db.insert('sync_queue', {
        'operation_id': operationId, 'user_id': user.id, 'resource_id': null,
        'operation_type': row['activity_type'], 'created_at': row['created_at'],
        'payload': jsonEncode(payload), 'status': 'pending',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      try {
        await client.from('learning_activities').upsert({
          'user_id': user.id, 'resource_id': null, 'activity_type': row['activity_type'],
          'payload': payload, 'occurred_at': row['created_at'], 'client_operation_id': operationId,
        }, onConflict: 'user_id,client_operation_id', ignoreDuplicates: true);
        await db.update('activities', {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [operationId]);
        await db.update('sync_queue', {'status': 'synced', 'last_error': null}, where: 'operation_id = ?', whereArgs: [operationId]);
      } catch (error) {
        await db.update('sync_queue', {'status': 'failed', 'last_error': error.toString()}, where: 'operation_id = ?', whereArgs: [operationId]);
        rethrow;
      }
    }
  }
}
