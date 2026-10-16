import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/report.dart';
import 'report_photo.dart';
import '../providers/reports_provider.dart';
import '../services/gps_service.dart';
import '../services/photo_service.dart';

const _primary = Color(0xFF1F4E79);
const _success = Color(0xFF2E8B57);
const _warning = Color(0xFFF4A62A);
const _danger = Color(0xFFD64545);
const _ink = Color(0xFF1E293B);

class NewReportPage extends StatefulWidget {
  const NewReportPage({super.key});

  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  @override
  void initState() {
    super.initState();

    // Demander la localisation apres ouverture de la page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        locate();
      }
    });
  }

  final comment = TextEditingController();
  final watch = Stopwatch()..start();

  String type = 'nid_de_poule';
  String severity = 'moyenne';
  String? photoPath;
  Position? position;
  bool busy = false;
  String? message;

  Future<void> takePhoto() => selectPhoto(fromGallery: false);

  Future<void> importPhoto() => selectPhoto(fromGallery: true);

  Future<void> selectPhoto({required bool fromGallery}) async {
    setState(() {
      busy = true;
      message = null;
    });

    try {
      final path = fromGallery
          ? await PhotoService.importFromGallery()
          : await PhotoService.capture();

      if (!mounted) return;

      if (path == null) {
        setState(() => message = 'Aucune photo sélectionnée.');
      } else {
        setState(() => photoPath = path);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Photo impossible : $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> locate() async {
    setState(() {
      busy = true;
      message = null;
    });

    try {
      final p = await GpsService.locate();

      if (!mounted) return;

      if (p.accuracy > 30) {
        setState(() {
          position = p;
          message =
              'Précision GPS faible : ${p.accuracy.toStringAsFixed(1)} m. '
              'Vous pouvez enregistrer, mais il est conseillé de réessayer.';
        });
      } else {
        setState(() {
          position = p;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => message = '$e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    if (photoPath == null || position == null || busy) return;

    setState(() => busy = true);

    try {
      watch.stop();

      final item = RoadReport(
        id: const Uuid().v4(),
        latitude: position!.latitude,
        longitude: position!.longitude,
        gpsAccuracy: position!.accuracy,
        type: type,
        severity: severity,
        comment: comment.text.trim(),
        photoPath: photoPath!,
        localStatus: 'en_attente',
        createdAt: DateTime.now().toUtc().toIso8601String(),
        durationSeconds: watch.elapsed.inSeconds,
      );

      await context.read<ReportsProvider>().add(item);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Enregistrement impossible : $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  void dispose() {
    comment.dispose();
    watch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !busy && photoPath != null && position != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau signalement'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Créer un signalement',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ajoutez une photo, récupérez votre position GPS, puis enregistrez localement.',
                    style: TextStyle(
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: '1. Photo',
                    icon: Icons.photo_camera_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photoPath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: ReportPhoto(
                              path: photoPath!,
                              width: double.infinity,
                              height: 220,
                            ),
                          )
                        else
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FAFD),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFDDE6F0),
                              ),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 46,
                                    color: Colors.black26,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Aucune photo sélectionnée',
                                    style: TextStyle(color: Colors.black45),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: busy ? null : takePhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            kIsWeb ? 'Choisir une photo' : 'Prendre une photo',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: busy ? null : importPhoto,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Importer depuis la galerie'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: '2. Position GPS',
                    icon: Icons.my_location_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (position != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FAFD),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFDDE6F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Latitude : ${position!.latitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Longitude : ${position!.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Précision : ${position!.accuracy.toStringAsFixed(1)} m',
                                  style: TextStyle(
                                    color: position!.accuracy > 30
                                        ? _warning
                                        : _success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const Text(
                            'Aucune position récupérée pour le moment.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: busy ? null : locate,
                          icon: const Icon(Icons.gps_fixed_rounded),
                          label: const Text('Obtenir ma position'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: '3. Détails du signalement',
                    icon: Icons.assignment_outlined,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(
                            labelText: 'Type de dégradation',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'nid_de_poule',
                              child: Text('Nid-de-poule'),
                            ),
                            DropdownMenuItem(
                              value: 'fissure',
                              child: Text('Fissure'),
                            ),
                            DropdownMenuItem(
                              value: 'affaissement',
                              child: Text('Affaissement'),
                            ),
                            DropdownMenuItem(
                              value: 'autre',
                              child: Text('Autre'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => type = v);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: severity,
                          decoration: const InputDecoration(
                            labelText: 'Gravité',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'faible',
                              child: Text('Faible'),
                            ),
                            DropdownMenuItem(
                              value: 'moyenne',
                              child: Text('Moyenne'),
                            ),
                            DropdownMenuItem(
                              value: 'grave',
                              child: Text('Grave'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => severity = v);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: comment,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Commentaire (facultatif)',
                            hintText:
                                'Exemple : route très abîmée devant l’école',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (message != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: message!.toLowerCase().contains('précision') ||
                                message!.toLowerCase().contains('precision')
                            ? const Color(0xFFFFF7E8)
                            : const Color(0xFFFFF4F4),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: message!.toLowerCase().contains('précision') ||
                                  message!.toLowerCase().contains('precision')
                              ? const Color(0xFFF5D38D)
                              : const Color(0xFFFFD7D7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            message!.toLowerCase().contains('précision') ||
                                    message!.toLowerCase().contains('precision')
                                ? Icons.warning_amber_rounded
                                : Icons.error_outline_rounded,
                            color: message!
                                        .toLowerCase()
                                        .contains('précision') ||
                                    message!.toLowerCase().contains('precision')
                                ? _warning
                                : _danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message!,
                              style: TextStyle(
                                color: message!
                                            .toLowerCase()
                                            .contains('précision') ||
                                        message!
                                            .toLowerCase()
                                            .contains('precision')
                                    ? const Color(0xFF946200)
                                    : _danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message != null) const SizedBox(height: 16),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  FilledButton.icon(
                    onPressed: canSave ? save : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Enregistrer hors ligne'),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Le signalement est d’abord sauvegardé localement avant toute synchronisation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _primary),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
