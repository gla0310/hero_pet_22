import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// أداة موحّدة لالتقاط الصور (من الكاميرا أو المعرض) وحفظها داخل
/// مجلد التطبيق الخاص، مع إرجاع المسار لحفظه في SQLite.
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  /// يعرض للمستخدم اختيار المصدر (كاميرا أو معرض) ثم يحفظ الصورة
  /// داخل مجلد images داخل مجلد بيانات التطبيق ويرجع المسار الكامل.
  static Future<String?> pickAndSaveImage({required ImageSource source}) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docsDir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final ext = p.extension(picked.path);
    final fileName = '${_uuid.v4()}$ext';
    final savedPath = p.join(imagesDir.path, fileName);

    await File(picked.path).copy(savedPath);
    return savedPath;
  }

  /// يحفظ بايتات صورة (مثل توقيع مُصدَّر كـ PNG) داخل مجلد images
  /// الخاص بالتطبيق ويرجع المسار الكامل - يُستخدم مع بيانات لم تأتِ
  /// من الكاميرا/المعرض مباشرة.
  static Future<String> saveBytesAsImage(List<int> bytes, {String prefix = 'image'}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docsDir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final fileName = '${prefix}_${_uuid.v4()}.png';
    final savedPath = p.join(imagesDir.path, fileName);
    await File(savedPath).writeAsBytes(bytes);
    return savedPath;
  }
}
