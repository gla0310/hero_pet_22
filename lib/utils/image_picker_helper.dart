import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A unified tool for capturing images (from camera or gallery) and saving them
/// inside the app's private folder, returning the path to store in SQLite.
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Shows the user a source picker (camera or gallery), then saves the image
  /// inside the images folder within the app's data directory and returns the full path.
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

  /// Saves image bytes (such as a signature exported as PNG) inside the app's
  /// images folder and returns the full path - used with data that did not
  /// come directly from the camera/gallery.
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
