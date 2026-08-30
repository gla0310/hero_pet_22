import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/client.dart';
import '../models/pet.dart';
import '../models/visit.dart';
import '../models/appointment.dart';
import '../models/reminder.dart';
import '../models/admission.dart';
import '../models/admission_note.dart';
import '../models/grooming_service.dart';

/// كلاس مركزي لإدارة قاعدة البيانات المحلية (SQLite) الخاصة بتطبيق Hero Pet
/// كل العمليات (CRUD) لجميع الجداول تمر من هنا حتى يسهل التطوير والصيانة.
class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<String> get dbPath async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'hero_pet.db');
  }

  Future<Database> _initDB() async {
    final path = await dbPath;
    return openDatabase(
      path,
      version: 12,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// عند ترقية قاعدة بيانات موجودة مسبقاً (نسخة قديمة من التطبيق مثبتة على الجهاز)
  /// نضيف فقط الجداول/الأعمدة الجديدة دون المساس بأي بيانات موجودة.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS AdmissionNotes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          admission_id INTEGER NOT NULL,
          date_time TEXT NOT NULL,
          text TEXT NOT NULL,
          FOREIGN KEY (admission_id) REFERENCES Admissions (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      // نضيف عمود تاريخ إضافة العميل للعملاء المسجلين مسبقاً (يبقى فارغاً لهم)
      final columns = await db.rawQuery('PRAGMA table_info(Clients)');
      final hasCreatedAt = columns.any((c) => c['name'] == 'created_at');
      if (!hasCreatedAt) {
        await db.execute('ALTER TABLE Clients ADD COLUMN created_at TEXT');
      }
    }
    if (oldVersion < 4) {
      // نضيف عمود "الرصيد" لكل عميل (افتراضياً صفر لكل العملاء المسجلين مسبقاً)
      final columns = await db.rawQuery('PRAGMA table_info(Clients)');
      final hasBalance = columns.any((c) => c['name'] == 'balance');
      if (!hasBalance) {
        await db.execute('ALTER TABLE Clients ADD COLUMN balance REAL NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 5) {
      // السجل المدني (اختياري) + الأرشفة للعملاء
      final clientColumns = await db.rawQuery('PRAGMA table_info(Clients)');
      if (!clientColumns.any((c) => c['name'] == 'civil_id')) {
        await db.execute('ALTER TABLE Clients ADD COLUMN civil_id TEXT');
      }
      if (!clientColumns.any((c) => c['name'] == 'archived')) {
        await db.execute('ALTER TABLE Clients ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
      }

      // المايكروشيب + الأرشفة للأليفات
      final petColumns = await db.rawQuery('PRAGMA table_info(Pets)');
      if (!petColumns.any((c) => c['name'] == 'microchip')) {
        await db.execute('ALTER TABLE Pets ADD COLUMN microchip TEXT');
      }
      if (!petColumns.any((c) => c['name'] == 'archived')) {
        await db.execute('ALTER TABLE Pets ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
      }

      // حالة الموعد
      final apptColumns = await db.rawQuery('PRAGMA table_info(Appointments)');
      if (!apptColumns.any((c) => c['name'] == 'status')) {
        await db.execute("ALTER TABLE Appointments ADD COLUMN status TEXT NOT NULL DEFAULT 'بانتظار'");
      }

      // جداول باقات التطعيمات
      await db.execute('''
        CREATE TABLE IF NOT EXISTS VaccinationPackages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS VaccinationPackageItems (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          package_id INTEGER NOT NULL,
          vaccine_name TEXT NOT NULL,
          dose_offset_days INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (package_id) REFERENCES VaccinationPackages (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      // حقول تفصيلية لزيارة العيادة (الفحص/الملاحظات كانت موجودة مسبقاً كـ description)
      final visitColumns = await db.rawQuery('PRAGMA table_info(Visits)');
      if (!visitColumns.any((c) => c['name'] == 'diagnosis')) {
        await db.execute('ALTER TABLE Visits ADD COLUMN diagnosis TEXT');
      }
      if (!visitColumns.any((c) => c['name'] == 'treatment')) {
        await db.execute('ALTER TABLE Visits ADD COLUMN treatment TEXT');
      }
      if (!visitColumns.any((c) => c['name'] == 'recommendations')) {
        await db.execute('ALTER TABLE Visits ADD COLUMN recommendations TEXT');
      }
      if (!visitColumns.any((c) => c['name'] == 'appointment_id')) {
        await db.execute('ALTER TABLE Visits ADD COLUMN appointment_id INTEGER');
      }

      // ربط باقة التطعيمات بأليفة محددة (بدل كونها باقة عامة قابلة لإعادة الاستخدام)
      final packageColumns = await db.rawQuery('PRAGMA table_info(VaccinationPackages)');
      if (!packageColumns.any((c) => c['name'] == 'pet_id')) {
        await db.execute('ALTER TABLE VaccinationPackages ADD COLUMN pet_id INTEGER');
      }

      // حالة كل تطعيمة داخل الباقة: هل أُعطيت أم لا، ومتى، وفي أي زيارة
      final itemColumns = await db.rawQuery('PRAGMA table_info(VaccinationPackageItems)');
      if (!itemColumns.any((c) => c['name'] == 'given')) {
        await db.execute('ALTER TABLE VaccinationPackageItems ADD COLUMN given INTEGER NOT NULL DEFAULT 0');
      }
      if (!itemColumns.any((c) => c['name'] == 'given_date')) {
        await db.execute('ALTER TABLE VaccinationPackageItems ADD COLUMN given_date TEXT');
      }
      if (!itemColumns.any((c) => c['name'] == 'given_visit_id')) {
        await db.execute('ALTER TABLE VaccinationPackageItems ADD COLUMN given_visit_id INTEGER');
      }

      // قائمة رئيسية بأسماء التطعيمات المتاحة للاختيار منها عند إنشاء باقة
      // (تبدأ فارغة تماماً - الموظف يضيف تطعيماته الخاصة بنفسه)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS MasterVaccines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
    }
    if (oldVersion < 7) {
      // إزالة التطعيمات الافتراضية التي كانت تُضاف تلقائياً في نسخة سابقة من
      // التطبيق - القائمة الآن تبدأ فارغة والموظف يضيف تطعيماته بنفسه فقط
      const oldDefaultVaccines = [
        'خماسي', 'سداسي', 'داء الكلب', 'التهاب الكبد الفيروسي',
        'البارفو', 'الكاليسي', 'التهاب الأنف والقصبة', 'اللوكيميا',
      ];
      for (final v in oldDefaultVaccines) {
        await db.delete('MasterVaccines', where: 'name = ?', whereArgs: [v]);
      }
    }
    if (oldVersion < 8) {
      // نظام الاستمارات الإلكترونية: قوالب قابلة للتخصيص بالكامل من التطبيق
      // (بدون أي محتوى افتراضي - المسؤول ينشئها بنفسه من "إدارة الاستمارات")
      await db.execute('''
        CREATE TABLE IF NOT EXISTS FormTemplates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          service_type TEXT NOT NULL,
          terms_text TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS FormFields (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          template_id INTEGER NOT NULL,
          field_type TEXT NOT NULL,
          label TEXT NOT NULL,
          required INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (template_id) REFERENCES FormTemplates (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS FormSubmissions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          template_id INTEGER NOT NULL,
          template_name TEXT NOT NULL,
          service_type TEXT NOT NULL,
          client_id INTEGER NOT NULL,
          pet_id INTEGER,
          admission_id INTEGER,
          visit_id INTEGER,
          civil_id TEXT,
          staff_name TEXT,
          answers_json TEXT NOT NULL,
          signature_path TEXT NOT NULL,
          pdf_path TEXT,
          submitted_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS FormAttachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          submission_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (submission_id) REFERENCES FormSubmissions (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 9) {
      // فصل استمارة "الإجراء الطبي" إلى استمارتين منفصلتين: دخول وخروج
      // (سابقاً كانت استمارة واحدة مشتركة تُستخدم فقط عند الدخول)
      await db.update(
        'FormTemplates',
        {'service_type': 'checkin_procedure'},
        where: 'service_type = ?',
        whereArgs: ['procedure'],
      );
      await db.update(
        'FormSubmissions',
        {'service_type': 'checkin_procedure'},
        where: 'service_type = ?',
        whereArgs: ['procedure'],
      );
    }
    if (oldVersion < 10) {
      // قسم الشاور والحلاقة: سجل خدمة مستقل لكل أليفة
      await db.execute('''
        CREATE TABLE IF NOT EXISTS GroomingServices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pet_id INTEGER NOT NULL,
          services TEXT NOT NULL,
          counts_as_shower INTEGER NOT NULL DEFAULT 0,
          is_free_shower INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'انتظار',
          created_at TEXT NOT NULL,
          completed_at TEXT,
          FOREIGN KEY (pet_id) REFERENCES Pets (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 11) {
      // ملاحظات حرة لكل خدمة شاور/حلاقة (مثل نوع القصة المطلوبة)
      final columns = await db.rawQuery('PRAGMA table_info(GroomingServices)');
      if (!columns.any((c) => c['name'] == 'notes')) {
        await db.execute('ALTER TABLE GroomingServices ADD COLUMN notes TEXT');
      }
    }
    if (oldVersion < 12) {
      // عداد الشاور أصبح رقماً مخزَّناً وقابلاً للتعديل اليدوي بدل حسابه
      // تلقائياً فقط من السجل - حتى يقدر الموظف يضيف شاورات سابقة للأليفة
      // من قبل تركيب التطبيق (أو يصحّح العداد يدوياً في أي وقت)
      final petColumns = await db.rawQuery('PRAGMA table_info(Pets)');
      if (!petColumns.any((c) => c['name'] == 'shower_count')) {
        await db.execute('ALTER TABLE Pets ADD COLUMN shower_count INTEGER NOT NULL DEFAULT 0');
      }

      // تعبئة العداد لكل أليفة من سجلها الحالي حتى لا يفقد أي عميل تقدّمه السابق
      final pets = await db.query('Pets');
      for (final pet in pets) {
        final petId = pet['id'] as int;
        final lastFree = await db.rawQuery('''
          SELECT MAX(created_at) AS last_free FROM GroomingServices
          WHERE pet_id = ? AND is_free_shower = 1
        ''', [petId]);
        final lastFreeDate = lastFree.first['last_free'] as String?;

        final countRes = lastFreeDate != null
            ? await db.rawQuery('''
                SELECT COUNT(*) AS c FROM GroomingServices
                WHERE pet_id = ? AND counts_as_shower = 1 AND is_free_shower = 0 AND created_at > ?
              ''', [petId, lastFreeDate])
            : await db.rawQuery('''
                SELECT COUNT(*) AS c FROM GroomingServices
                WHERE pet_id = ? AND counts_as_shower = 1 AND is_free_shower = 0
              ''', [petId]);

        final paidCount = (countRes.first['c'] as int?) ?? 0;
        if (paidCount > 0) {
          await db.update('Pets', {'shower_count': paidCount > 3 ? 3 : paidCount}, where: 'id = ?', whereArgs: [petId]);
        }
      }
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        notes TEXT,
        created_at TEXT,
        balance REAL NOT NULL DEFAULT 0,
        civil_id TEXT,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE Pets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        breed TEXT,
        gender TEXT,
        birth_date TEXT,
        weight REAL,
        color TEXT,
        image_path TEXT,
        microchip TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'طبيعي',
        archived INTEGER NOT NULL DEFAULT 0,
        shower_count INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (client_id) REFERENCES Clients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        reason TEXT NOT NULL,
        description TEXT,
        diagnosis TEXT,
        treatment TEXT,
        recommendations TEXT,
        appointment_id INTEGER,
        FOREIGN KEY (pet_id) REFERENCES Pets (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        reason TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'بانتظار',
        FOREIGN KEY (pet_id) REFERENCES Pets (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        message TEXT NOT NULL,
        FOREIGN KEY (appointment_id) REFERENCES Appointments (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Admissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        boarding_type TEXT,
        procedure_name TEXT,
        entry_date TEXT NOT NULL,
        expected_exit_date TEXT,
        actual_exit_date TEXT,
        entry_contract_image TEXT,
        exit_contract_image TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (pet_id) REFERENCES Pets (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE AdmissionNotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        admission_id INTEGER NOT NULL,
        date_time TEXT NOT NULL,
        text TEXT NOT NULL,
        FOREIGN KEY (admission_id) REFERENCES Admissions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE VaccinationPackages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pet_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE VaccinationPackageItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_id INTEGER NOT NULL,
        vaccine_name TEXT NOT NULL,
        dose_offset_days INTEGER NOT NULL DEFAULT 0,
        given INTEGER NOT NULL DEFAULT 0,
        given_date TEXT,
        given_visit_id INTEGER,
        FOREIGN KEY (package_id) REFERENCES VaccinationPackages (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE MasterVaccines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    // ملاحظة: القائمة تبدأ فارغة عمداً - الموظف يضيف تطعيماته الخاصة بنفسه

    // نظام الاستمارات الإلكترونية (بدون محتوى افتراضي)
    await db.execute('''
      CREATE TABLE FormTemplates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        service_type TEXT NOT NULL,
        terms_text TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE FormFields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        field_type TEXT NOT NULL,
        label TEXT NOT NULL,
        required INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (template_id) REFERENCES FormTemplates (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE FormSubmissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        template_name TEXT NOT NULL,
        service_type TEXT NOT NULL,
        client_id INTEGER NOT NULL,
        pet_id INTEGER,
        admission_id INTEGER,
        visit_id INTEGER,
        civil_id TEXT,
        staff_name TEXT,
        answers_json TEXT NOT NULL,
        signature_path TEXT NOT NULL,
        pdf_path TEXT,
        submitted_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE FormAttachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        submission_id INTEGER NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (submission_id) REFERENCES FormSubmissions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE GroomingServices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id INTEGER NOT NULL,
        services TEXT NOT NULL,
        counts_as_shower INTEGER NOT NULL DEFAULT 0,
        is_free_shower INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'انتظار',
        created_at TEXT NOT NULL,
        completed_at TEXT,
        notes TEXT,
        FOREIGN KEY (pet_id) REFERENCES Pets (id) ON DELETE CASCADE
      )
    ''');

    // فهرسة رقم الجوال لتسريع البحث لأنه المفتاح الأساسي للنظام
    await db.execute('CREATE INDEX idx_clients_phone ON Clients (phone)');
  }

  // ==================== Clients ====================

  Future<int> insertClient(Client client) async {
    final db = await database;
    final map = client.toMap()..remove('id');
    map['created_at'] ??= _nowStamp();
    return db.insert('Clients', map);
  }

  /// طابع زمني موحّد بصيغة yyyy-MM-dd HH:mm (بدون الاعتماد على intl هنا لإبقاء طبقة قاعدة البيانات مستقلة)
  String _nowStamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
  }

  Future<Client?> getClientByPhone(String phone) async {
    final db = await database;
    final res = await db.query('Clients', where: 'phone = ?', whereArgs: [phone]);
    if (res.isEmpty) return null;
    return Client.fromMap(res.first);
  }

  Future<Client?> getClientById(int id) async {
    final db = await database;
    final res = await db.query('Clients', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return Client.fromMap(res.first);
  }

  Future<List<Client>> searchClientsByPhone(String query) async {
    final db = await database;
    final res = await db.query(
      'Clients',
      where: '(phone LIKE ? OR name LIKE ?) AND archived = 0',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return res.map((e) => Client.fromMap(e)).toList();
  }

  Future<int> updateClient(Client client) async {
    final db = await database;
    return db.update('Clients', client.toMap(), where: 'id = ?', whereArgs: [client.id]);
  }

  // ==================== الأرشفة (Archive) ====================

  /// أرشفة عميل: يختفي من القوائم الرئيسية والبحث لكن بياناته وسجلاته تبقى محفوظة بالكامل
  Future<int> archiveClient(int clientId) async {
    final db = await database;
    return db.update('Clients', {'archived': 1}, where: 'id = ?', whereArgs: [clientId]);
  }

  Future<int> restoreClient(int clientId) async {
    final db = await database;
    return db.update('Clients', {'archived': 0}, where: 'id = ?', whereArgs: [clientId]);
  }

  Future<List<Client>> getArchivedClients() async {
    final db = await database;
    final res = await db.query('Clients', where: 'archived = 1', orderBy: 'name ASC');
    return res.map((e) => Client.fromMap(e)).toList();
  }

  /// أرشفة أليفة: تختفي من القوائم الرئيسية لكن سجلاتها الطبية تبقى محفوظة بالكامل
  Future<int> archivePet(int petId) async {
    final db = await database;
    return db.update('Pets', {'archived': 1}, where: 'id = ?', whereArgs: [petId]);
  }

  Future<int> restorePet(int petId) async {
    final db = await database;
    return db.update('Pets', {'archived': 0}, where: 'id = ?', whereArgs: [petId]);
  }

  /// كل الأليفات المؤرشفة مع اسم العميل التابعة له لعرضها في شاشة الأرشيف
  Future<List<Map<String, dynamic>>> getArchivedPetsWithClient() async {
    final db = await database;
    return db.rawQuery('''
      SELECT p.*, c.name AS client_name, c.phone AS client_phone
      FROM Pets p
      JOIN Clients c ON p.client_id = c.id
      WHERE p.archived = 1
      ORDER BY p.name ASC
    ''');
  }

  // ==================== الرصيد (Balance) ====================

  /// تحديث رصيد عميل معيّن (استبدال القيمة بالكامل)
  Future<int> setClientBalance(int clientId, double balance) async {
    final db = await database;
    return db.update('Clients', {'balance': balance}, where: 'id = ?', whereArgs: [clientId]);
  }

  /// كل العملاء الذين لديهم رصيد فعلي (غير صفر) فقط، مرتّبين من الأكبر رصيداً
  Future<List<Client>> getClientsWithBalance() async {
    final db = await database;
    final res = await db.query(
      'Clients',
      where: 'balance != 0 AND archived = 0',
      orderBy: 'balance DESC',
    );
    return res.map((e) => Client.fromMap(e)).toList();
  }

  // ==================== لوحة المعلومات (Dashboard) ====================

  /// آخر العملاء الذين تمت إضافتهم مع عدد الأليفات التابعة لكل عميل
  Future<List<Map<String, dynamic>>> getRecentClientsWithPetCount({int? limit}) async {
    final db = await database;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    return db.rawQuery('''
      SELECT c.*, (SELECT COUNT(*) FROM Pets p WHERE p.client_id = c.id AND p.archived = 0) AS pet_count
      FROM Clients c
      WHERE c.archived = 0
      ORDER BY c.id DESC
      $limitClause
    ''');
  }

  /// آخر عمليات دخول الفندقة/الإجراء الطبي (أي حالة) مرتبة بتاريخ الدخول
  Future<List<Map<String, dynamic>>> getRecentAdmissionCheckins({int? limit}) async {
    final db = await database;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    return db.rawQuery('''
      SELECT ad.*, p.name AS pet_name, c.name AS client_name, c.phone AS client_phone
      FROM Admissions ad
      JOIN Pets p ON ad.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      ORDER BY ad.id DESC
      $limitClause
    ''');
  }

  /// آخر عمليات التسليم (الحالة "تم التسليم") مرتبة بتاريخ الخروج الفعلي
  Future<List<Map<String, dynamic>>> getRecentDeliveries({int? limit}) async {
    final db = await database;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    return db.rawQuery('''
      SELECT ad.*, p.name AS pet_name, c.name AS client_name, c.phone AS client_phone
      FROM Admissions ad
      JOIN Pets p ON ad.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE ad.status = ?
      ORDER BY ad.id DESC
      $limitClause
    ''', [PetStatus.delivered]);
  }

  /// الأليفات التي تجاوزت تاريخ الخروج المتوقع وما زالت موجودة فعلياً (متأخرة عن الخروج)
  Future<List<Map<String, dynamic>>> getOverdueAdmissionsWithDetails() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT ad.*, p.name AS pet_name, p.gender AS pet_gender, c.name AS client_name, c.phone AS client_phone
      FROM Admissions ad
      JOIN Pets p ON ad.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE ad.status IN (?, ?)
        AND ad.expected_exit_date IS NOT NULL
        AND ad.expected_exit_date < ?
      ORDER BY ad.expected_exit_date ASC
    ''', [PetStatus.inHotel, PetStatus.inClinic, today]);
  }

  // ==================== Pets ====================

  Future<int> insertPet(Pet pet) async {
    final db = await database;
    return db.insert('Pets', pet.toMap()..remove('id'));
  }

  Future<List<Pet>> getPetsByClientId(int clientId, {bool includeArchived = false}) async {
    final db = await database;
    final where = includeArchived ? 'client_id = ?' : 'client_id = ? AND archived = 0';
    final res = await db.query('Pets', where: where, whereArgs: [clientId]);
    return res.map((e) => Pet.fromMap(e)).toList();
  }

  Future<Pet?> getPetById(int id) async {
    final db = await database;
    final res = await db.query('Pets', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return Pet.fromMap(res.first);
  }

  Future<int> updatePetStatus(int petId, String status) async {
    final db = await database;
    return db.update('Pets', {'status': status}, where: 'id = ?', whereArgs: [petId]);
  }

  Future<int> updatePet(Pet pet) async {
    final db = await database;
    return db.update('Pets', pet.toMap(), where: 'id = ?', whereArgs: [pet.id]);
  }

  // ==================== Visits ====================

  Future<int> insertVisit(Visit visit) async {
    final db = await database;
    return db.insert('Visits', visit.toMap()..remove('id'));
  }

  Future<List<Visit>> getVisitsByPetId(int petId) async {
    final db = await database;
    final res = await db.query('Visits', where: 'pet_id = ?', whereArgs: [petId], orderBy: 'date DESC');
    return res.map((e) => Visit.fromMap(e)).toList();
  }

  // ==================== Appointments ====================

  Future<int> insertAppointment(Appointment appt) async {
    final db = await database;
    return db.insert('Appointments', appt.toMap()..remove('id'));
  }

  Future<List<Appointment>> getAppointmentsByPetId(int petId) async {
    final db = await database;
    final res = await db.query('Appointments', where: 'pet_id = ?', whereArgs: [petId], orderBy: 'date DESC');
    return res.map((e) => Appointment.fromMap(e)).toList();
  }

  Future<Appointment?> getAppointmentById(int id) async {
    final db = await database;
    final res = await db.query('Appointments', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return Appointment.fromMap(res.first);
  }

  Future<int> updateAppointment(Appointment appt) async {
    final db = await database;
    return db.update('Appointments', appt.toMap(), where: 'id = ?', whereArgs: [appt.id]);
  }

  Future<int> updateAppointmentStatus(int appointmentId, String status) async {
    final db = await database;
    return db.update('Appointments', {'status': status}, where: 'id = ?', whereArgs: [appointmentId]);
  }

  Future<int> deleteAppointment(int id) async {
    final db = await database;
    // نحذف التذكيرات المرتبطة أولاً (إن وجدت) ثم الموعد نفسه
    await db.delete('Reminders', where: 'appointment_id = ?', whereArgs: [id]);
    return db.delete('Appointments', where: 'id = ?', whereArgs: [id]);
  }

  /// كل المواعيد (من اليوم فصاعداً) مع تفاصيل الأليفة والعميل - تُستخدم في
  /// شاشة المواعيد وشاشة التذكيرات
  Future<List<Map<String, dynamic>>> getUpcomingAppointmentsWithDetails() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT a.*, p.name AS pet_name, p.gender AS pet_gender, c.name AS client_name, c.phone AS client_phone
      FROM Appointments a
      JOIN Pets p ON a.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE a.date >= ?
      ORDER BY a.date ASC, a.time ASC
    ''', [today]);
  }

  /// جميع المواعيد مع بيانات الأليفة والعميل (Join) لعرضها في شاشة المواعيد
  Future<List<Map<String, dynamic>>> getAllAppointmentsWithDetails({String? forDate}) async {
    final db = await database;
    final where = forDate != null ? "WHERE a.date = '$forDate'" : '';
    return db.rawQuery('''
      SELECT a.*, p.name AS pet_name, c.name AS client_name, c.phone AS client_phone
      FROM Appointments a
      JOIN Pets p ON a.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      $where
      ORDER BY a.date ASC, a.time ASC
    ''');
  }

  // ==================== Reminders ====================

  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return db.insert('Reminders', reminder.toMap()..remove('id'));
  }

  /// كل التذكيرات القادمة مع تفاصيل العميل والأليفة والموعد
  Future<List<Map<String, dynamic>>> getUpcomingRemindersWithDetails() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT r.*, a.date AS appointment_date, a.time AS appointment_time,
             p.name AS pet_name, c.name AS client_name, c.phone AS client_phone
      FROM Reminders r
      JOIN Appointments a ON r.appointment_id = a.id
      JOIN Pets p ON a.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE a.date >= ?
      ORDER BY a.date ASC, a.time ASC
    ''', [today]);
  }

  // ==================== Admissions (فندقة / إجراء طبي) ====================

  Future<int> insertAdmission(Admission admission) async {
    final db = await database;
    return db.insert('Admissions', admission.toMap()..remove('id'));
  }

  Future<int> updateAdmission(Admission admission) async {
    final db = await database;
    return db.update('Admissions', admission.toMap(), where: 'id = ?', whereArgs: [admission.id]);
  }

  Future<List<Admission>> getAdmissionsByPetId(int petId) async {
    final db = await database;
    final res = await db.query('Admissions', where: 'pet_id = ?', whereArgs: [petId], orderBy: 'entry_date DESC');
    return res.map((e) => Admission.fromMap(e)).toList();
  }

  /// آخر Admission نشط (لم يخرج/يسلَّم بعد) لأليفة معينة
  Future<Admission?> getActiveAdmissionForPet(int petId) async {
    final db = await database;
    final res = await db.query(
      'Admissions',
      where: 'pet_id = ? AND status IN (?, ?)',
      whereArgs: [petId, PetStatus.inHotel, PetStatus.inClinic],
      orderBy: 'entry_date DESC',
      limit: 1,
    );
    if (res.isEmpty) return null;
    return Admission.fromMap(res.first);
  }

  /// كل الأليفات الموجودة حالياً في الفندقة مع بيانات العميل والأليفة
  Future<List<Map<String, dynamic>>> getCurrentlyInHotelWithDetails() async {
    final db = await database;
    return db.rawQuery('''
      SELECT ad.*, p.name AS pet_name, p.type AS pet_type, p.gender AS pet_gender, c.name AS client_name, c.phone AS client_phone
      FROM Admissions ad
      JOIN Pets p ON ad.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE ad.type = 'hotel' AND ad.status = 'موجودة في الفندقة'
      ORDER BY ad.entry_date ASC
    ''');
  }

  /// كل الأليفات الموجودة حالياً (فندقة عادية/علاجية أو إجراء طبي) مع بيانات العميل والأليفة
  Future<List<Map<String, dynamic>>> getCurrentlyPresentWithDetails() async {
    final db = await database;
    return db.rawQuery('''
      SELECT ad.*, p.name AS pet_name, p.type AS pet_type, p.gender AS pet_gender, c.name AS client_name, c.phone AS client_phone
      FROM Admissions ad
      JOIN Pets p ON ad.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE ad.status IN (?, ?)
      ORDER BY ad.entry_date ASC
    ''', [PetStatus.inHotel, PetStatus.inClinic]);
  }

  /// الأليفات المستحق تسليمها اليوم (تاريخ الخروج المتوقع = اليوم) وما زالت موجودة فعلياً
  Future<List<Map<String, dynamic>>> getAdmissionsDueTodayWithDetails() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT ad.*, p.name AS pet_name, p.gender AS pet_gender, c.name AS client_name, c.phone AS client_phone
      FROM Admissions ad
      JOIN Pets p ON ad.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE ad.status IN (?, ?) AND ad.expected_exit_date = ?
      ORDER BY ad.entry_date ASC
    ''', [PetStatus.inHotel, PetStatus.inClinic, today]);
  }

  /// كل الأليفات النشطة حالياً (فندقة/إجراء) الخاصة بعميل معين حسب رقم جواله - تُستخدم في شاشة تسجيل الخروج
  Future<List<Map<String, dynamic>>> getActiveAdmissionsByPhone(String phone) async {
    final db = await database;
    return db.rawQuery('''
      SELECT ad.*, p.name AS pet_name
      FROM Admissions ad
      JOIN Pets p ON ad.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE c.phone = ? AND ad.status IN (?, ?)
      ORDER BY ad.entry_date DESC
    ''', [phone, PetStatus.inHotel, PetStatus.inClinic]);
  }

  // ==================== Admission Notes (ملاحظات أثناء وجود الأليفة) ====================

  Future<int> insertAdmissionNote(AdmissionNote note) async {
    final db = await database;
    return db.insert('AdmissionNotes', note.toMap()..remove('id'));
  }

  Future<int> updateAdmissionNote(AdmissionNote note) async {
    final db = await database;
    return db.update('AdmissionNotes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteAdmissionNote(int id) async {
    final db = await database;
    return db.delete('AdmissionNotes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AdmissionNote>> getNotesForAdmission(int admissionId) async {
    final db = await database;
    final res = await db.query(
      'AdmissionNotes',
      where: 'admission_id = ?',
      whereArgs: [admissionId],
      orderBy: 'date_time DESC',
    );
    return res.map((e) => AdmissionNote.fromMap(e)).toList();
  }

  // ==================== ملف العميل الكامل (لصفحة البحث) ====================

  Future<Map<String, dynamic>?> getClientFullProfile(String phone) async {
    final client = await getClientByPhone(phone);
    if (client == null) return null;

    final pets = await getPetsByClientId(client.id!);
    final List<Map<String, dynamic>> petsWithDetails = [];

    for (final pet in pets) {
      final visits = await getVisitsByPetId(pet.id!);
      final appointments = await getAppointmentsByPetId(pet.id!);
      final admissions = await getAdmissionsByPetId(pet.id!);

      // جلب ملاحظات كل عملية دخول (فندقة/إجراء طبي) الخاصة بهذه الأليفة
      final Map<int, List<AdmissionNote>> notesByAdmission = {};
      for (final admission in admissions) {
        if (admission.id != null) {
          notesByAdmission[admission.id!] = await getNotesForAdmission(admission.id!);
        }
      }

      petsWithDetails.add({
        'pet': pet,
        'visits': visits,
        'appointments': appointments,
        'admissions': admissions,
        'notesByAdmission': notesByAdmission,
      });
    }

    return {
      'client': client,
      'pets': petsWithDetails,
    };
  }

  // ==================== باقات التطعيمات (Vaccination Packages) ====================
  // كل باقة مرتبطة بأليفة واحدة محددة (وليست قالباً عاماً قابلاً لإعادة الاستخدام)

  /// القائمة الرئيسية بأسماء التطعيمات المتاحة للاختيار منها
  Future<List<Map<String, dynamic>>> getMasterVaccines() async {
    final db = await database;
    return db.query('MasterVaccines', orderBy: 'name ASC');
  }

  Future<int> addMasterVaccine(String name) async {
    final db = await database;
    return db.insert('MasterVaccines', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// إنشاء باقة تطعيمات جديدة لأليفة محددة، مع قائمة أسماء التطعيمات المختارة لها
  Future<int> createVaccinationPackageForPet({
    required int petId,
    required List<String> vaccineNames,
    String name = 'باقة تطعيمات',
  }) async {
    final db = await database;
    final packageId = await db.insert('VaccinationPackages', {'name': name, 'pet_id': petId});
    for (final vaccineName in vaccineNames) {
      await db.insert('VaccinationPackageItems', {
        'package_id': packageId,
        'vaccine_name': vaccineName,
        'dose_offset_days': 0,
        'given': 0,
      });
    }
    return packageId;
  }

  Future<int> deleteVaccinationPackage(int id) async {
    final db = await database;
    // نحذف عناصر الباقة أولاً ثم الباقة نفسها
    await db.delete('VaccinationPackageItems', where: 'package_id = ?', whereArgs: [id]);
    return db.delete('VaccinationPackages', where: 'id = ?', whereArgs: [id]);
  }

  /// كل الباقات مع اسم العميل والأليفة التابعة لهم لعرضها في شاشة الباقات
  Future<List<Map<String, dynamic>>> getVaccinationPackagesWithDetails() async {
    final db = await database;
    return db.rawQuery('''
      SELECT vp.*, p.name AS pet_name, c.name AS client_name, c.phone AS client_phone
      FROM VaccinationPackages vp
      JOIN Pets p ON vp.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      ORDER BY vp.id DESC
    ''');
  }

  /// باقة التطعيمات الخاصة بأليفة معينة (إن وجدت) - تُستخدم في شاشة زيارة العيادة
  Future<Map<String, dynamic>?> getVaccinationPackageForPet(int petId) async {
    final db = await database;
    final res = await db.query('VaccinationPackages', where: 'pet_id = ?', whereArgs: [petId], orderBy: 'id DESC', limit: 1);
    if (res.isEmpty) return null;
    return res.first;
  }

  Future<int> addVaccinationPackageItem({
    required int packageId,
    required String vaccineName,
    int doseOffsetDays = 0,
  }) async {
    final db = await database;
    return db.insert('VaccinationPackageItems', {
      'package_id': packageId,
      'vaccine_name': vaccineName,
      'dose_offset_days': doseOffsetDays,
      'given': 0,
    });
  }

  Future<int> deleteVaccinationPackageItem(int itemId) async {
    final db = await database;
    return db.delete('VaccinationPackageItems', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<List<Map<String, dynamic>>> getVaccinationPackageItems(int packageId) async {
    final db = await database;
    return db.query(
      'VaccinationPackageItems',
      where: 'package_id = ?',
      whereArgs: [packageId],
      orderBy: 'id ASC',
    );
  }

  /// تحديد أن تطعيمة معينة أُعطيت (أو التراجع عن ذلك)، وربطها بالزيارة إن وُجدت
  Future<int> setVaccineItemGiven({
    required int itemId,
    required bool given,
    String? date,
    int? visitId,
  }) async {
    final db = await database;
    return db.update(
      'VaccinationPackageItems',
      {
        'given': given ? 1 : 0,
        'given_date': given ? date : null,
        'given_visit_id': given ? visitId : null,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  // ==================== نظام الاستمارات الإلكترونية (Forms) ====================

  Future<List<Map<String, dynamic>>> getFormTemplates() async {
    final db = await database;
    return db.query('FormTemplates', orderBy: 'id DESC');
  }

  Future<Map<String, dynamic>?> getFormTemplateById(int id) async {
    final db = await database;
    final res = await db.query('FormTemplates', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return res.first;
  }

  /// القالب النشط الحالي لنوع خدمة معيّن (إن وُجد) - لا تظهر الاستمارة تلقائياً
  /// إلا إذا كان هناك قالب نشط واحد على الأقل لهذا النوع
  Future<Map<String, dynamic>?> getActiveTemplateForServiceType(String serviceType) async {
    final db = await database;
    final res = await db.query(
      'FormTemplates',
      where: 'service_type = ? AND active = 1',
      whereArgs: [serviceType],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first;
  }

  Future<int> insertFormTemplate({
    required String name,
    required String serviceType,
    String? termsText,
    bool active = true,
  }) async {
    final db = await database;
    return db.insert('FormTemplates', {
      'name': name,
      'service_type': serviceType,
      'terms_text': termsText,
      'active': active ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateFormTemplate({
    required int id,
    required String name,
    required String serviceType,
    String? termsText,
    required bool active,
  }) async {
    final db = await database;
    return db.update(
      'FormTemplates',
      {
        'name': name,
        'service_type': serviceType,
        'terms_text': termsText,
        'active': active ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFormTemplate(int id) async {
    final db = await database;
    await db.delete('FormFields', where: 'template_id = ?', whereArgs: [id]);
    return db.delete('FormTemplates', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getFormFields(int templateId) async {
    final db = await database;
    return db.query('FormFields', where: 'template_id = ?', whereArgs: [templateId], orderBy: 'sort_order ASC, id ASC');
  }

  Future<int> addFormField({
    required int templateId,
    required String fieldType,
    required String label,
    bool required = false,
  }) async {
    final db = await database;
    final existing = await getFormFields(templateId);
    return db.insert('FormFields', {
      'template_id': templateId,
      'field_type': fieldType,
      'label': label,
      'required': required ? 1 : 0,
      'sort_order': existing.length,
    });
  }

  Future<int> deleteFormField(int fieldId) async {
    final db = await database;
    return db.delete('FormFields', where: 'id = ?', whereArgs: [fieldId]);
  }

  Future<int> insertFormSubmission({
    required int templateId,
    required String templateName,
    required String serviceType,
    required int clientId,
    int? petId,
    int? admissionId,
    int? visitId,
    String? civilId,
    String? staffName,
    required String answersJson,
    required String signaturePath,
    String? pdfPath,
  }) async {
    final db = await database;
    return db.insert('FormSubmissions', {
      'template_id': templateId,
      'template_name': templateName,
      'service_type': serviceType,
      'client_id': clientId,
      'pet_id': petId,
      'admission_id': admissionId,
      'visit_id': visitId,
      'civil_id': civilId,
      'staff_name': staffName,
      'answers_json': answersJson,
      'signature_path': signaturePath,
      'pdf_path': pdfPath,
      'submitted_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateFormSubmissionPdfPath(int submissionId, String pdfPath) async {
    final db = await database;
    return db.update('FormSubmissions', {'pdf_path': pdfPath}, where: 'id = ?', whereArgs: [submissionId]);
  }

  /// يربط استمارة تمت تعبئتها قبل إنشاء سجل الدخول (Admission) بالسجل الفعلي
  /// بعد إنشائه - يُستخدم في تدفق "الاستمارة أولاً ثم تسجيل الدخول"
  Future<int> updateFormSubmissionAdmissionId(int submissionId, int admissionId) async {
    final db = await database;
    return db.update('FormSubmissions', {'admission_id': admissionId}, where: 'id = ?', whereArgs: [submissionId]);
  }

  Future<List<Map<String, dynamic>>> getFormSubmissionsForClient(int clientId) async {
    final db = await database;
    return db.query('FormSubmissions', where: 'client_id = ?', whereArgs: [clientId], orderBy: 'id DESC');
  }

  /// كل الاستمارات المحفوظة على الإطلاق - تُستخدم لإعادة إنشاء ملفات PDF القديمة
  Future<List<Map<String, dynamic>>> getAllFormSubmissions() async {
    final db = await database;
    return db.query('FormSubmissions', orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> getFormSubmissionsForPet(int petId) async {
    final db = await database;
    return db.query('FormSubmissions', where: 'pet_id = ?', whereArgs: [petId], orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getFormAttachments(int submissionId) async {
    final db = await database;
    return db.query('FormAttachments', where: 'submission_id = ?', whereArgs: [submissionId], orderBy: 'id ASC');
  }

  Future<int> addFormAttachment(int submissionId, String filePath) async {
    final db = await database;
    return db.insert('FormAttachments', {
      'submission_id': submissionId,
      'file_path': filePath,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================== الشاور والحلاقة (Grooming) ====================

  Future<int> insertGroomingService(GroomingService service) async {
    final db = await database;
    return db.insert('GroomingServices', service.toMap());
  }

  Future<int> updateGroomingServiceStatus(int id, String status) async {
    final db = await database;
    return db.update(
      'GroomingServices',
      {
        'status': status,
        'completed_at': status == GroomingStatus.completed ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<GroomingService>> getGroomingServicesForPet(int petId) async {
    final db = await database;
    final res = await db.query('GroomingServices', where: 'pet_id = ?', whereArgs: [petId], orderBy: 'created_at DESC');
    return res.map((e) => GroomingService.fromMap(e)).toList();
  }

  /// كل خدمات الشاور والحلاقة المسجّلة اليوم مع بيانات الأليفة والعميل
  Future<List<Map<String, dynamic>>> getTodayGroomingServicesWithDetails() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return db.rawQuery('''
      SELECT g.*, p.name AS pet_name, p.image_path AS pet_image, p.gender AS pet_gender,
             c.name AS client_name, c.phone AS client_phone
      FROM GroomingServices g
      JOIN Pets p ON g.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE date(g.created_at) = ?
      ORDER BY g.created_at DESC
    ''', [today]);
  }

  /// عداد الشاور الحالي للأليفة (0-3) وهل استحقت الشاور المجاني - يُقرأ
  /// مباشرة من عمود الأليفة نفسه (رقم مخزَّن وليس محسوباً فقط)، حتى يقدر
  /// الموظف يعدّله يدوياً في أي وقت (مثلاً لأليفة لديها شاورات سابقة قبل
  /// تركيب التطبيق).
  Future<Map<String, dynamic>> getPetShowerProgress(int petId) async {
    final pet = await getPetById(petId);
    final count = pet?.showerCount ?? 0;
    return {
      'paidCount': count > 3 ? 3 : count,
      'freeEligible': count >= 3,
    };
  }

  /// زيادة عداد الشاور بواحد (تُستدعى تلقائياً عند تسجيل خدمة شاور مدفوعة)
  Future<int> incrementPetShowerCount(int petId) async {
    final db = await database;
    final pet = await getPetById(petId);
    final newCount = (pet?.showerCount ?? 0) + 1;
    return db.update('Pets', {'shower_count': newCount}, where: 'id = ?', whereArgs: [petId]);
  }

  /// تصفير عداد الشاور (تُستدعى تلقائياً عند استخدام الشاور المجاني)
  Future<int> resetPetShowerCount(int petId) async {
    final db = await database;
    return db.update('Pets', {'shower_count': 0}, where: 'id = ?', whereArgs: [petId]);
  }

  /// تعديل يدوي مباشر لعداد الشاور من قِبل الموظف (مثلاً لإضافة شاورات
  /// سابقة للأليفة من قبل تركيب التطبيق)
  Future<int> setPetShowerCount(int petId, int count) async {
    final db = await database;
    return db.update('Pets', {'shower_count': count}, where: 'id = ?', whereArgs: [petId]);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
