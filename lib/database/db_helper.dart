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

/// A central class for managing Hero Pet's local (SQLite) database
/// All CRUD operations for every table go through here for easier development and maintenance.
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

  /// When upgrading an existing database (an older app version installed on the device)
  /// we only add new tables/columns without touching any existing data.
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
      // Add the client-added date column for previously registered clients (stays empty for them)
      final columns = await db.rawQuery('PRAGMA table_info(Clients)');
      final hasCreatedAt = columns.any((c) => c['name'] == 'created_at');
      if (!hasCreatedAt) {
        await db.execute('ALTER TABLE Clients ADD COLUMN created_at TEXT');
      }
    }
    if (oldVersion < 4) {
      // Add a "balance" column for each client (defaults to zero for all previously registered clients)
      final columns = await db.rawQuery('PRAGMA table_info(Clients)');
      final hasBalance = columns.any((c) => c['name'] == 'balance');
      if (!hasBalance) {
        await db.execute('ALTER TABLE Clients ADD COLUMN balance REAL NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 5) {
      // Civil ID (optional) + archiving for clients
      final clientColumns = await db.rawQuery('PRAGMA table_info(Clients)');
      if (!clientColumns.any((c) => c['name'] == 'civil_id')) {
        await db.execute('ALTER TABLE Clients ADD COLUMN civil_id TEXT');
      }
      if (!clientColumns.any((c) => c['name'] == 'archived')) {
        await db.execute('ALTER TABLE Clients ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
      }

      // Microchip + archiving for pets
      final petColumns = await db.rawQuery('PRAGMA table_info(Pets)');
      if (!petColumns.any((c) => c['name'] == 'microchip')) {
        await db.execute('ALTER TABLE Pets ADD COLUMN microchip TEXT');
      }
      if (!petColumns.any((c) => c['name'] == 'archived')) {
        await db.execute('ALTER TABLE Pets ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
      }

      // Appointment status
      final apptColumns = await db.rawQuery('PRAGMA table_info(Appointments)');
      if (!apptColumns.any((c) => c['name'] == 'status')) {
        await db.execute("ALTER TABLE Appointments ADD COLUMN status TEXT NOT NULL DEFAULT 'Pending'");
      }

      // Vaccination package tables
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
      // Detailed clinic visit fields (examination/notes previously existed as description)
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

      // Link a vaccination package to a specific pet (instead of being a generic reusable package)
      final packageColumns = await db.rawQuery('PRAGMA table_info(VaccinationPackages)');
      if (!packageColumns.any((c) => c['name'] == 'pet_id')) {
        await db.execute('ALTER TABLE VaccinationPackages ADD COLUMN pet_id INTEGER');
      }

      // Status of each vaccine within the package: whether it was given, when, and in which visit
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

      // A master list of vaccine names available for selection when creating a package
      // (starts completely empty - staff add their own vaccines themselves)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS MasterVaccines (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE
        )
      ''');
    }
    if (oldVersion < 7) {
      // Remove the default vaccines that used to be added automatically in a previous
      // app version - the list now starts empty and staff add their own vaccines only
      const oldDefaultVaccines = [
        'DHPP (5-way)', 'DHLPP (6-way)', 'Rabies', 'Viral Hepatitis',
        'Parvo', 'Calicivirus', 'Rhinotracheitis', 'Leukemia',
      ];
      for (final v in oldDefaultVaccines) {
        await db.delete('MasterVaccines', where: 'name = ?', whereArgs: [v]);
      }
    }
    if (oldVersion < 8) {
      // Electronic forms system: templates fully customizable from the app
      // (with no default content - the admin creates them from "Manage Forms")
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
      // Split the "medical procedure" form into two separate forms: check-in and check-out
      // (previously it was one shared form used only at check-in)
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
      // Grooming & bathing department: an independent service record for each pet
      await db.execute('''
        CREATE TABLE IF NOT EXISTS GroomingServices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          pet_id INTEGER NOT NULL,
          services TEXT NOT NULL,
          counts_as_shower INTEGER NOT NULL DEFAULT 0,
          is_free_shower INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'Pending',
          created_at TEXT NOT NULL,
          completed_at TEXT,
          FOREIGN KEY (pet_id) REFERENCES Pets (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 11) {
      // Free-text notes for each grooming/bathing service (such as the requested haircut style)
      final columns = await db.rawQuery('PRAGMA table_info(GroomingServices)');
      if (!columns.any((c) => c['name'] == 'notes')) {
        await db.execute('ALTER TABLE GroomingServices ADD COLUMN notes TEXT');
      }
    }
    if (oldVersion < 12) {
      // The bath counter is now a stored, manually editable number instead of being
      // calculated automatically from the record alone - so staff can add previous
      // baths for a pet from before the app was installed (or correct the counter manually at any time)
      final petColumns = await db.rawQuery('PRAGMA table_info(Pets)');
      if (!petColumns.any((c) => c['name'] == 'shower_count')) {
        await db.execute('ALTER TABLE Pets ADD COLUMN shower_count INTEGER NOT NULL DEFAULT 0');
      }

      // Populate the counter for each pet from its current record so no client loses their previous progress
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
        status TEXT NOT NULL DEFAULT 'Normal',
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
        status TEXT NOT NULL DEFAULT 'Pending',
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
    // Note: the list starts intentionally empty - staff add their own vaccines themselves

    // Electronic forms system (with no default content)
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
        status TEXT NOT NULL DEFAULT 'Pending',
        created_at TEXT NOT NULL,
        completed_at TEXT,
        notes TEXT,
        FOREIGN KEY (pet_id) REFERENCES Pets (id) ON DELETE CASCADE
      )
    ''');

    // Index the phone number to speed up search since it's the system's primary key
    await db.execute('CREATE INDEX idx_clients_phone ON Clients (phone)');
  }

  // ==================== Clients ====================

  Future<int> insertClient(Client client) async {
    final db = await database;
    final map = client.toMap()..remove('id');
    map['created_at'] ??= _nowStamp();
    return db.insert('Clients', map);
  }

  /// A unified timestamp in yyyy-MM-dd HH:mm format (without relying on intl here to keep the database layer independent)
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

  // ==================== Archive ====================

  /// Archive a client: disappears from the main lists and search, but their data and records remain fully saved
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

  /// Archive a pet: disappears from the main lists but its medical records remain fully saved
  Future<int> archivePet(int petId) async {
    final db = await database;
    return db.update('Pets', {'archived': 1}, where: 'id = ?', whereArgs: [petId]);
  }

  Future<int> restorePet(int petId) async {
    final db = await database;
    return db.update('Pets', {'archived': 0}, where: 'id = ?', whereArgs: [petId]);
  }

  /// All archived pets with their client's name, for display in the archive screen
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

  // ==================== Balance ====================

  /// Update a specific client's balance (replace the value entirely)
  Future<int> setClientBalance(int clientId, double balance) async {
    final db = await database;
    return db.update('Clients', {'balance': balance}, where: 'id = ?', whereArgs: [clientId]);
  }

  /// Only clients with an actual (non-zero) balance, ordered from the highest balance down
  Future<List<Client>> getClientsWithBalance() async {
    final db = await database;
    final res = await db.query(
      'Clients',
      where: 'balance != 0 AND archived = 0',
      orderBy: 'balance DESC',
    );
    return res.map((e) => Client.fromMap(e)).toList();
  }

  // ==================== Dashboard ====================

  /// The most recently added clients with the pet count for each client
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

  /// The most recent hotel/medical procedure check-ins (any status), ordered by entry date
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

  /// The most recent deliveries (status "Delivered"), ordered by actual exit date
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

  /// Pets that have passed their expected exit date and are still actually present (overdue for exit)
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
    // Delete the related reminders first (if any), then the appointment itself
    await db.delete('Reminders', where: 'appointment_id = ?', whereArgs: [id]);
    return db.delete('Appointments', where: 'id = ?', whereArgs: [id]);
  }

  /// All appointments (from today onward) with pet and client details - used in
  /// the appointments screen and the reminders screen
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

  /// All appointments with pet and client data (Join), for display in the appointments screen
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

  /// All upcoming reminders with client, pet, and appointment details
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

  // ==================== Admissions (boarding / medical procedure) ====================

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

  /// The most recent active Admission (not yet checked out/delivered) for a given pet
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

  /// All pets currently present in the hotel, with client and pet data
  Future<List<Map<String, dynamic>>> getCurrentlyInHotelWithDetails() async {
    final db = await database;
    return db.rawQuery('''
      SELECT ad.*, p.name AS pet_name, p.type AS pet_type, p.gender AS pet_gender, c.name AS client_name, c.phone AS client_phone
      FROM Admissions ad
      JOIN Pets p ON ad.pet_id = p.id
      JOIN Clients c ON p.client_id = c.id
      WHERE ad.type = 'hotel' AND ad.status = 'In Hotel'
      ORDER BY ad.entry_date ASC
    ''');
  }

  /// All pets currently present (regular/treatment boarding or medical procedure), with client and pet data
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

  /// Pets due for delivery today (expected exit date = today) and still actually present
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

  /// All currently active pets (boarding/procedure) belonging to a given client by their phone number - used in the check-out screen
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

  // ==================== Admission Notes (notes during the pet's stay) ====================

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

  // ==================== Full client profile (for the search page) ====================

  Future<Map<String, dynamic>?> getClientFullProfile(String phone) async {
    final client = await getClientByPhone(phone);
    if (client == null) return null;

    final pets = await getPetsByClientId(client.id!);
    final List<Map<String, dynamic>> petsWithDetails = [];

    for (final pet in pets) {
      final visits = await getVisitsByPetId(pet.id!);
      final appointments = await getAppointmentsByPetId(pet.id!);
      final admissions = await getAdmissionsByPetId(pet.id!);

      // Fetch the notes for each admission (boarding/medical procedure) for this pet
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

  // ==================== Vaccination Packages ====================
  // Each package is linked to one specific pet (not a generic reusable template)

  /// The master list of vaccine names available for selection
  Future<List<Map<String, dynamic>>> getMasterVaccines() async {
    final db = await database;
    return db.query('MasterVaccines', orderBy: 'name ASC');
  }

  Future<int> addMasterVaccine(String name) async {
    final db = await database;
    return db.insert('MasterVaccines', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Create a new vaccination package for a specific pet, with the list of vaccine names selected for it
  Future<int> createVaccinationPackageForPet({
    required int petId,
    required List<String> vaccineNames,
    String name = 'Vaccination Package',
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
    // Delete the package's items first, then the package itself
    await db.delete('VaccinationPackageItems', where: 'package_id = ?', whereArgs: [id]);
    return db.delete('VaccinationPackages', where: 'id = ?', whereArgs: [id]);
  }

  /// All packages with the name of the client and pet they belong to, for display in the packages screen
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

  /// The vaccination package for a given pet (if any) - used in the clinic visit screen
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

  /// Mark that a given vaccine was administered (or undo that), and link it to the visit if one exists
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

  // ==================== Electronic Forms System (Forms) ====================

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

  /// The current active template for a given service type (if any) - the form does not
  /// appear automatically unless there is at least one active template for that type
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

  /// Links a form filled out before the admission record was created to the actual
  /// record once it exists - used in the "form first, then check-in" flow
  Future<int> updateFormSubmissionAdmissionId(int submissionId, int admissionId) async {
    final db = await database;
    return db.update('FormSubmissions', {'admission_id': admissionId}, where: 'id = ?', whereArgs: [submissionId]);
  }

  Future<List<Map<String, dynamic>>> getFormSubmissionsForClient(int clientId) async {
    final db = await database;
    return db.query('FormSubmissions', where: 'client_id = ?', whereArgs: [clientId], orderBy: 'id DESC');
  }

  /// All forms ever saved - used to regenerate old PDF files
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

  // ==================== Grooming & Bathing (Grooming) ====================

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

  /// All grooming & bathing services logged today, with pet and client data
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

  /// The pet's current bath counter (0-3) and whether it has earned a free bath - read
  /// directly from the pet's own column (a stored number, not just calculated), so
  /// staff can manually adjust it at any time (for example, for a pet with previous baths from
  /// before the app was installed).
  Future<Map<String, dynamic>> getPetShowerProgress(int petId) async {
    final pet = await getPetById(petId);
    final count = pet?.showerCount ?? 0;
    return {
      'paidCount': count > 3 ? 3 : count,
      'freeEligible': count >= 3,
    };
  }

  /// Increase the bath counter by one (called automatically when a paid bath service is logged)
  Future<int> incrementPetShowerCount(int petId) async {
    final db = await database;
    final pet = await getPetById(petId);
    final newCount = (pet?.showerCount ?? 0) + 1;
    return db.update('Pets', {'shower_count': newCount}, where: 'id = ?', whereArgs: [petId]);
  }

  /// Reset the bath counter to zero (called automatically when the free bath is used)
  Future<int> resetPetShowerCount(int petId) async {
    final db = await database;
    return db.update('Pets', {'shower_count': 0}, where: 'id = ?', whereArgs: [petId]);
  }

  /// A direct manual adjustment of the bath counter by staff (for example, to add
  /// previous baths for a pet from before the app was installed)
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
