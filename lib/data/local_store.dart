import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class LocalStore {
  LocalStore._();
  static final instance = LocalStore._();
  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    return openDatabase(p.join(base, 'tulai.db'), version: 7, onCreate: (db, _) async {
      await db.execute('''CREATE TABLE resources(id TEXT PRIMARY KEY,title TEXT NOT NULL,description TEXT NOT NULL,subject TEXT NOT NULL,topic TEXT NOT NULL,language TEXT NOT NULL,difficulty TEXT NOT NULL,source_name TEXT NOT NULL,source_url TEXT,external_url TEXT,license TEXT NOT NULL,content TEXT NOT NULL,content_type TEXT NOT NULL DEFAULT 'platform',is_packaged INTEGER NOT NULL DEFAULT 1,remote_managed INTEGER NOT NULL DEFAULT 0,source_language TEXT,translation_method TEXT,translation_review_status TEXT,review_status TEXT)''');
      await db.execute('''CREATE TABLE preferences(key TEXT PRIMARY KEY,value TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE assessment_results(id TEXT PRIMARY KEY,subject TEXT NOT NULL,score INTEGER NOT NULL,level TEXT NOT NULL,answers TEXT NOT NULL,created_at TEXT NOT NULL,sync_status TEXT NOT NULL DEFAULT 'local',owner_user_id TEXT)''');
      await db.execute('''CREATE TABLE reading_progress(resource_id TEXT PRIMARY KEY,position INTEGER NOT NULL DEFAULT 0,percent REAL NOT NULL DEFAULT 0,updated_at TEXT NOT NULL,sync_status TEXT NOT NULL DEFAULT 'local',operation_id TEXT NOT NULL,owner_user_id TEXT)''');
      await db.execute('''CREATE TABLE activities(id TEXT PRIMARY KEY,resource_id TEXT,activity_type TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,sync_status TEXT NOT NULL DEFAULT 'local',owner_user_id TEXT)''');
      await db.execute('''CREATE TABLE sync_queue(operation_id TEXT PRIMARY KEY,user_id TEXT NOT NULL,resource_id TEXT,operation_type TEXT NOT NULL,created_at TEXT NOT NULL,payload TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'pending',last_error TEXT)''');
      await db.execute('''CREATE TABLE cloud_assessments(user_id TEXT NOT NULL,operation_id TEXT NOT NULL,subject TEXT NOT NULL,score INTEGER NOT NULL,level TEXT NOT NULL,answers TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(user_id,operation_id))''');
      await db.execute('''CREATE TABLE cloud_activities(user_id TEXT NOT NULL,operation_id TEXT NOT NULL,resource_id TEXT,activity_type TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(user_id,operation_id))''');
      await db.execute('''CREATE TABLE cloud_progress(user_id TEXT NOT NULL,local_resource_id TEXT NOT NULL,position INTEGER NOT NULL,percent REAL NOT NULL,updated_at TEXT NOT NULL,operation_id TEXT NOT NULL,PRIMARY KEY(user_id,local_resource_id))''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await db.execute('ALTER TABLE resources ADD COLUMN external_url TEXT');
      if (oldVersion < 3) {
        await db.execute("ALTER TABLE reading_progress ADD COLUMN operation_id TEXT NOT NULL DEFAULT ''");
        final rows = await db.query('reading_progress', columns: ['resource_id']);
        for (final row in rows) { await db.update('reading_progress', {'operation_id': const Uuid().v4()}, where: 'resource_id = ?', whereArgs: [row['resource_id']]); }
      }
      if (oldVersion < 4) await db.execute('ALTER TABLE resources ADD COLUMN remote_managed INTEGER NOT NULL DEFAULT 0');
      if (oldVersion < 5) {
        await db.execute('ALTER TABLE resources ADD COLUMN source_language TEXT');
        await db.execute('ALTER TABLE resources ADD COLUMN translation_method TEXT');
        await db.execute('ALTER TABLE resources ADD COLUMN translation_review_status TEXT');
      }
      if (oldVersion < 6) await db.execute('ALTER TABLE resources ADD COLUMN review_status TEXT');
      if (oldVersion < 7) {
        await db.execute('ALTER TABLE assessment_results ADD COLUMN owner_user_id TEXT');
        await db.execute('ALTER TABLE activities ADD COLUMN owner_user_id TEXT');
        await db.execute('ALTER TABLE reading_progress ADD COLUMN owner_user_id TEXT');
        await db.execute('''CREATE TABLE IF NOT EXISTS cloud_assessments(user_id TEXT NOT NULL,operation_id TEXT NOT NULL,subject TEXT NOT NULL,score INTEGER NOT NULL,level TEXT NOT NULL,answers TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(user_id,operation_id))''');
        await db.execute('''CREATE TABLE IF NOT EXISTS cloud_activities(user_id TEXT NOT NULL,operation_id TEXT NOT NULL,resource_id TEXT,activity_type TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(user_id,operation_id))''');
        await db.execute('''CREATE TABLE IF NOT EXISTS cloud_progress(user_id TEXT NOT NULL,local_resource_id TEXT NOT NULL,position INTEGER NOT NULL,percent REAL NOT NULL,updated_at TEXT NOT NULL,operation_id TEXT NOT NULL,PRIMARY KEY(user_id,local_resource_id))''');
      }
    });
  }

  Future<void> seedIfEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM resources')) ?? 0;
    if (count > 0) return;
    final seeds = [
      {
        'id':'math-foundations', 'title':'Foundational Mathematics',
        'description':'Build confidence with whole numbers and the four basic operations.',
        'subject':'Mathematics', 'topic':'Arithmetic', 'language':'en', 'difficulty':'Beginner',
        'source_name':'TULAI learning content', 'source_url':null,
        'license':'CC BY 4.0 — original TULAI starter content', 'content_type':'platform',
        'content': r'''# Foundational Mathematics

## Overview
This lesson introduces whole numbers and the four basic operations.

## Learning Objectives
- Read and compare whole numbers.
- Add and subtract whole numbers.
- Use multiplication and division in simple situations.

## Introduction
Numbers help us count, compare, measure, and solve everyday problems.

## Lessons and Sections
### Addition
Addition combines quantities. Example: 12 + 8 = 20.

### Subtraction
Subtraction finds the difference. Example: 20 - 8 = 12.

### Multiplication
Multiplication is repeated addition. Example: 4 × 3 = 12.

### Division
Division shares a quantity equally. Example: 12 ÷ 3 = 4.

## Exercises
1. Calculate 15 + 7.
2. Calculate 30 - 12.
3. Calculate 6 × 4.
4. Calculate 24 ÷ 6.

## Answer Key
1. 22  2. 18  3. 24  4. 4

## Summary
Addition combines, subtraction finds a difference, multiplication repeats addition, and division shares equally.

## References and Attribution
Original TULAI starter learning material. CC BY 4.0.'''
      },
      {
        'id':'english-vocabulary', 'title':'Everyday English Vocabulary',
        'description':'Learn useful everyday words and understand them in context.',
        'subject':'English', 'topic':'Vocabulary', 'language':'en', 'difficulty':'Beginner',
        'source_name':'TULAI learning content', 'source_url':null,
        'license':'CC BY 4.0 — original TULAI starter content', 'content_type':'platform',
        'content': r'''# Everyday English Vocabulary

## Overview
Practice common English words used in daily communication.

## Learning Objectives
- Identify common words.
- Use context to understand meaning.
- Choose words that fit simple sentences.

## Introduction
Vocabulary is the set of words we know and use. Reading, listening, and practice help build vocabulary.

## Lessons and Sections
### Useful words
- **Assist**: to help someone.
- **Purchase**: to buy something.
- **Rapid**: fast or quick.
- **Essential**: very important or necessary.

### Use context
In “Please assist me with this task,” assist means help.

## Exercises
Choose a word that means “to buy”: assist, purchase, rapid.

## Answer Key
Purchase.

## Summary
Learn a word's meaning and notice how it is used in a sentence.

## References and Attribution
Original TULAI starter learning material. CC BY 4.0.'''
      },
      {
        'id':'digital-literacy', 'title':'Getting Started with Digital Devices',
        'description':'Understand basic device parts, safe use, and common digital tasks.',
        'subject':'Digital Skills', 'topic':'Computer Literacy', 'language':'en', 'difficulty':'Beginner',
        'source_name':'TULAI learning content', 'source_url':null,
        'license':'CC BY 4.0 — original TULAI starter content', 'content_type':'platform',
        'content': r'''# Getting Started with Digital Devices

## Overview
An introduction to common digital devices and responsible use.

## Learning Objectives
- Identify common computer components.
- Describe basic input and output.
- Practice safe device habits.

## Introduction
A digital device processes information. A computer can help people create documents, communicate, and find information.

## Lessons and Sections
### Common components
A keyboard and mouse are input devices. A monitor is an output device. A processor carries out instructions.

### Safe habits
Use strong, unique passwords. Do not share passwords or open unexpected links. Keep software updated when possible.

## Exercises
Is a keyboard an input or output device?

## Answer Key
Input device.

## Summary
Know the basic parts of a device and use it carefully.

## References and Attribution
Original TULAI starter learning material. CC BY 4.0.'''
      },
    ];
    final batch = db.batch();
    for (final item in seeds) {
      batch.insert('resources', item, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveAssessment(String subject, int score, String level, List<int> answers, {String? ownerUserId}) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    final storedSubject = subject == 'English Vocabulary' ? 'English' : subject;
    await db.transaction((txn) async {
      await txn.insert('assessment_results', {
        'id': const Uuid().v4(), 'subject': storedSubject, 'score': score, 'level': level,
        'answers': jsonEncode(answers), 'created_at': now, 'owner_user_id': ownerUserId,
      });
      await txn.insert('activities', {
        'id': const Uuid().v4(), 'resource_id': null, 'activity_type': 'assessment_completed',
        'payload': jsonEncode({'subject': storedSubject, 'score': score, 'level': level}), 'created_at': now, 'owner_user_id': ownerUserId,
      });
    });
  }

  Future<void> saveGeneratedResource({required String title, required String description, required String subject, required String language, required String difficulty, required String content}) async {
    await (await database).insert('resources', {
      'id': const Uuid().v4(), 'title': title, 'description': description,
      'subject': subject, 'topic': 'AI-generated draft', 'language': language,
      'difficulty': difficulty, 'source_name': 'OpenAI-assisted draft',
      'source_url': null, 'license': 'AI-generated; reuse terms not verified',
      'content_type': 'ai_generated', 'is_packaged': 1, 'content': content, 'review_status': 'unverified',
    });
  }

  Future<bool> deleteGeneratedResource(String id) async {
    final db = await database;
    return db.transaction((txn) async {
      final removed = await txn.delete('resources',
          where: 'id = ? AND content_type = ? AND remote_managed = 0',
          whereArgs: [id, 'ai_generated']);
      if (removed == 0) return false;
      await txn.delete('reading_progress', where: 'resource_id = ?', whereArgs: [id]);
      await txn.delete('sync_queue', where: 'resource_id = ?', whereArgs: [id]);
      return true;
    });
  }

  Future<String?> approvedAccountId(String? signedInUserId) async {
    if (signedInUserId == null || await preference('cloud_sync_consent') != 'true') return null;
    return await preference('cloud_sync_user_id') == signedInUserId ? signedInUserId : null;
  }

  Future<String?> preference(String key) async {
    final rows = await (await database).query('preferences', columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setPreference(String key, String value) async {
    await (await database).insert('preferences', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> progressFor(String id) async {
    final rows = await (await database).query('reading_progress', where: 'resource_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveProgress(String id, int position, double percent, {String? ownerUserId}) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    final previous = await progressFor(id);
    final previousPercent = (previous?['percent'] as num?)?.toDouble() ?? -1;
    final previousAt = DateTime.tryParse(previous?['updated_at'] as String? ?? '');
    final meaningfulChange = previous == null || (percent - previousPercent).abs() >= 5 ||
        previousAt == null || DateTime.now().difference(previousAt).inMinutes >= 2;
    await db.transaction((txn) async {
      await txn.insert('reading_progress', {
        'resource_id': id, 'position': position, 'percent': percent, 'updated_at': now,
        'sync_status': 'local', 'operation_id': const Uuid().v4(), 'owner_user_id': ownerUserId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (meaningfulChange) {
        await txn.insert('activities', {
          'id': const Uuid().v4(), 'resource_id': id, 'activity_type': 'reading_progress',
          'payload': jsonEncode({'local_resource_id': id, 'position': position, 'percent': percent}), 'created_at': now, 'owner_user_id': ownerUserId,
        });
      }
    });
  }
}
