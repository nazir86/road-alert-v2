import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Affiche une photo locale sur Android ou une photo
/// encodee en base64 dans le navigateur Chrome.
class ReportPhoto extends StatelessWidget {
  final String path;
  final double width;
  final double height;

  const ReportPhoto({
    super.key,
    required this.path,
    required this.width,
    required this.height,
  });

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 32,
        color: Color(0xFF64748B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Photos locales en base64, utilisees par Chrome.
    if (path.startsWith('data:image/') && path.contains(',')) {
      try {
        final encoded = path.substring(path.indexOf(',') + 1);
        final bytes = base64Decode(encoded);

        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => _fallback(),
        );
      } catch (_) {
        return _fallback();
      }
    }

    // Photos distantes HTTP ou HTTPS.
    if (path.startsWith('https://') ||
        path.startsWith('http://') ||
        (kIsWeb && path.startsWith('blob:'))) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => _fallback(),
      );
    }

    // Le navigateur ne sait pas lire File(path).
    if (kIsWeb) {
      return _fallback();
    }

    // Android : photo stockee dans le dossier de l'application.
    final file = File(path);

    if (!file.existsSync()) {
      return _fallback();
    }

    return Image.file(
      file,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stack) => _fallback(),
    );
  }
}
