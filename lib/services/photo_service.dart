import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoService {
  static Future<String?> capture() =>
      _pick(kIsWeb ? ImageSource.gallery : ImageSource.camera);

  static Future<String?> importFromGallery() => _pick(ImageSource.gallery);

  static Future<String?> _pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 960,
      imageQuality: 65,
    );

    if (image == null) return null;

    // Chrome : stocker une petite image encodee en base64.
    if (kIsWeb) {
      final bytes = await image.readAsBytes();

      if (bytes.length > 900 * 1024) {
        throw Exception(
            'Image trop volumineuse. Choisissez une photo plus petite.');
      }

      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    // Android : conserver un vrai fichier photo dans l'application.
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(documents.path, 'photos'));

    await folder.create(recursive: true);

    final destination = p.join(
      folder.path,
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      image.path,
      destination,
      quality: 70,
      minWidth: 1280,
      minHeight: 720,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      throw Exception('Compression impossible.');
    }

    return result.path;
  }
}
