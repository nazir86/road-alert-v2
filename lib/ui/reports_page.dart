import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/report.dart';
import 'report_photo.dart';
import '../providers/reports_provider.dart';

const _primary = Color(0xFF1F4E79);
const _success = Color(0xFF2E8B57);
const _warning = Color(0xFFF4A62A);
const _danger = Color(0xFFD64545);
const _ink = Color(0xFF1E293B);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String query = '';

  Future<void> _deleteReport(RoadReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce signalement ?'),
        content: Text(
          '${_labelType(report.type)} • ${_labelSeverity(report.severity)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (ok == true) {
      if (!mounted) return;
      await context.read<ReportsProvider>().remove(report.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signalement supprimé du téléphone.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();

    final rows = provider.reports.where((r) {
      final text =
          '${r.type} ${r.severity} ${r.comment} ${r.localStatus}'.toLowerCase();
      return text.contains(query.toLowerCase());
    }).toList();

    final pendingCount =
        provider.reports.where((e) => e.localStatus == 'en_attente').length;
    final errorCount =
        provider.reports.where((e) => e.localStatus == 'erreur').length;
    final sentCount =
        provider.reports.where((e) => e.localStatus == 'envoye').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes signalements'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historique local',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Retrouvez vos signalements sauvegardés sur cet appareil.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MiniStat(
                        icon: Icons.assignment_rounded,
                        color: _primary,
                        label: 'Total',
                        value: '${provider.reports.length}',
                      ),
                      _MiniStat(
                        icon: Icons.schedule_rounded,
                        color: _warning,
                        label: 'En attente',
                        value: '$pendingCount',
                      ),
                      _MiniStat(
                        icon: Icons.error_outline_rounded,
                        color: _danger,
                        label: 'Erreurs',
                        value: '$errorCount',
                      ),
                      _MiniStat(
                        icon: Icons.check_circle_outline_rounded,
                        color: _success,
                        label: 'Envoyés',
                        value: '$sentCount',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Rechercher un signalement',
                      hintText: 'Type, gravité, commentaire, statut...',
                    ),
                    onChanged: (value) {
                      setState(() => query = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  if (provider.loading)
                    const Center(child: CircularProgressIndicator())
                  else if (rows.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: Colors.black26,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Aucun signalement trouvé.',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...rows.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ReportCard(
                          report: r,
                          onDelete: () => _deleteReport(r),
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

  String _labelType(String value) {
    switch (value) {
      case 'nid_de_poule':
        return 'Nid-de-poule';
      case 'fissure':
        return 'Fissure';
      case 'affaissement':
        return 'Affaissement';
      default:
        return 'Autre';
    }
  }

  String _labelSeverity(String value) {
    switch (value) {
      case 'faible':
        return 'Faible';
      case 'moyenne':
        return 'Moyenne';
      case 'grave':
        return 'Grave';
      default:
        return value;
    }
  }
}

class _ReportCard extends StatelessWidget {
  final RoadReport report;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.onDelete,
  });

  Color get severityColor {
    switch (report.severity) {
      case 'grave':
        return _danger;
      case 'moyenne':
        return _warning;
      default:
        return _success;
    }
  }

  String get severityLabel {
    switch (report.severity) {
      case 'grave':
        return 'Grave';
      case 'moyenne':
        return 'Moyenne';
      default:
        return 'Faible';
    }
  }

  String get typeLabel {
    switch (report.type) {
      case 'nid_de_poule':
        return 'Nid-de-poule';
      case 'fissure':
        return 'Fissure';
      case 'affaissement':
        return 'Affaissement';
      default:
        return 'Autre';
    }
  }

  String get statusLabel {
    switch (report.localStatus) {
      case 'envoye':
        return 'Envoyé';
      case 'erreur':
        return 'Erreur';
      case 'brouillon':
        return 'Brouillon';
      default:
        return 'En attente';
    }
  }

  Color get statusColor {
    switch (report.localStatus) {
      case 'envoye':
        return _success;
      case 'erreur':
        return _danger;
      case 'brouillon':
        return Colors.blueGrey;
      default:
        return _warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ReportPhoto(
                path: report.photoPath,
                width: 88,
                height: 88,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      _ChipLabel(
                        text: severityLabel,
                        color: severityColor,
                      ),
                      _ChipLabel(
                        text: statusLabel,
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'GPS ±${report.gpsAccuracy.toStringAsFixed(1)} m',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat ${report.latitude.toStringAsFixed(5)} • Lon ${report.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (report.comment.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      report.comment,
                      style: const TextStyle(
                        color: _ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (report.lastError != null &&
                      report.lastError!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Erreur : ${report.lastError}',
                      style: const TextStyle(
                        color: _danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer du téléphone'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _ChipLabel({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
