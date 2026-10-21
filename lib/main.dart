import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/reports_provider.dart';
import 'services/sync_service.dart';
import 'ui/auth_page.dart';
import 'ui/map_page.dart';
import 'ui/new_report_page.dart';
import 'ui/reports_page.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

const _primary = Color(0xFF1F4E79);
const _primaryDark = Color(0xFF163B5D);
const _accent = Color(0xFF3D84C6);
const _success = Color(0xFF2E8B57);
const _warning = Color(0xFFF4A62A);
const _danger = Color(0xFFD64545);
const _bg = Color(0xFFF4F7FB);
const _ink = Color(0xFF1E293B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ReportsProvider()..refresh(),
      child: const RoadAlertApp(),
    ),
  );
}

class RoadAlertApp extends StatelessWidget {
  const RoadAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROAD ALERT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          primary: _primary,
          secondary: _accent,
          error: _danger,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE7EDF5)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD5DFEA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD5DFEA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _primary, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: Color(0xFFD5DFEA)),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool syncing = false;

  Future<void> _navigate(Widget page) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );

    if (!mounted) return;

    await context.read<ReportsProvider>().refresh();

    if (result == true) {
      _message('Signalement enregistré avec succès sur cet appareil.');
    }
  }

  Future<void> _shareReports() async {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      _message('Configuration Supabase manquante.');
      return;
    }

    final client = Supabase.instance.client;

    if (client.auth.currentUser == null) {
      final connected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );

      if (!mounted || connected != true || client.auth.currentUser == null) {
        return;
      }
    }

    if (!mounted) return;
    setState(() {});

    if (kIsWeb) {
      _message(
        'Compte connecté. Le partage communautaire sera '
        'activé après configuration de la synchronisation Web.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Envoyer mes signalements'),
        content: const Text(
          'Envoyer les signalements en attente vers Supabase ? '
          'Ils ne seront pas encore publiés sur la carte '
          'communautaire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await _sync();
  }

  Future<void> _sync() async {
    if (kIsWeb) {
      _message(
        'La synchronisation complète des photos est surtout prévue pour Android. '
        'Le mode Web sert principalement à la démonstration.',
      );
      return;
    }

    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      _message(
        'Configurez SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY avant la synchronisation.',
      );
      return;
    }

    if (Supabase.instance.client.auth.currentUser == null) {
      final connected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );

      if (!mounted ||
          connected != true ||
          Supabase.instance.client.auth.currentUser == null) {
        return;
      }
    }

    if (!mounted) return;
    setState(() => syncing = true);

    try {
      final sent = await SyncService().synchronize();
      if (!mounted) return;

      await context.read<ReportsProvider>().refresh();

      if (sent == 0) {
        _message('Aucun nouveau signalement synchronisé.');
      } else {
        _message('$sent signalement(s) synchronisé(s) avec succès.');
      }
    } catch (e) {
      _message('Erreur de synchronisation : $e');
    } finally {
      if (mounted) {
        setState(() => syncing = false);
      }
    }
  }

  Future<void> _account() async {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      _message('Supabase n’est pas encore configuré pour la connexion.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    } else {
      await Supabase.instance.client.auth.signOut();
      _message('Déconnexion effectuée.');
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _showAlerts({
    required int pendingCount,
    required int errorCount,
    required int sentCount,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Centre des alertes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _AlertRow(
                  color: _warning,
                  icon: Icons.schedule_rounded,
                  title: 'En attente',
                  value: '$pendingCount',
                  subtitle: 'Signalements enregistrés mais non envoyés.',
                ),
                const SizedBox(height: 10),
                _AlertRow(
                  color: _danger,
                  icon: Icons.error_outline_rounded,
                  title: 'Erreurs',
                  value: '$errorCount',
                  subtitle: 'Signalements à revoir ou à renvoyer.',
                ),
                const SizedBox(height: 10),
                _AlertRow(
                  color: _success,
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Synchronisés',
                  value: '$sentCount',
                  subtitle: 'Signalements déjà envoyés au serveur.',
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: syncing ? null : _shareReports,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(
                    syncing
                        ? 'Synchronisation...'
                        : 'Partager mes signalements',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportsProvider>();
    final reports = provider.reports;
    final user = (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty)
        ? Supabase.instance.client.auth.currentUser
        : null;

    final pendingCount =
        reports.where((e) => e.localStatus == 'en_attente').length;
    final errorCount = reports.where((e) => e.localStatus == 'erreur').length;
    final sentCount = reports.where((e) => e.localStatus == 'envoye').length;
    final alertCount = pendingCount + errorCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final medium = constraints.maxWidth >= 640;

        return Scaffold(
          drawer: wide
              ? null
              : _HomeDrawer(
                  alertCount: alertCount,
                  onNewReport: () {
                    Navigator.pop(context);
                    _navigate(const NewReportPage());
                  },
                  onReports: () {
                    Navigator.pop(context);
                    _navigate(const ReportsPage());
                  },
                  onMap: () {
                    Navigator.pop(context);
                    _navigate(const MapPage());
                  },
                  onSync: () {
                    Navigator.pop(context);
                    _shareReports();
                  },
                  onAccount: () {
                    Navigator.pop(context);
                    _account();
                  },
                ),
          appBar: AppBar(
            title: Row(
              children: const [
                Icon(Icons.route_rounded, color: _primary),
                SizedBox(width: 10),
                Text(
                  'ROAD ALERT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Alertes',
                onPressed: () => _showAlerts(
                  pendingCount: pendingCount,
                  errorCount: errorCount,
                  sentCount: sentCount,
                ),
                icon: _BadgeIcon(
                  icon: Icons.notifications_none_rounded,
                  count: alertCount,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 16,
                18,
                wide ? 32 : 16,
                24,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCard(
                          userEmail: user?.email,
                          pendingCount: pendingCount,
                          onNewReport: () => _navigate(const NewReportPage()),
                        ),
                        const SizedBox(height: 18),
                        _NetworkCard(),
                        const SizedBox(height: 22),
                        const Text(
                          'Vue d’ensemble',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: medium
                                  ? (wide
                                      ? 350
                                      : (constraints.maxWidth - 46) / 3)
                                  : double.infinity,
                              child: _StatCard(
                                icon: Icons.assignment_rounded,
                                color: _primary,
                                label: 'Signalements',
                                value: '${reports.length}',
                              ),
                            ),
                            SizedBox(
                              width: medium
                                  ? (wide
                                      ? 350
                                      : (constraints.maxWidth - 46) / 3)
                                  : double.infinity,
                              child: _StatCard(
                                icon: Icons.schedule_rounded,
                                color: _warning,
                                label: 'En attente',
                                value: '$pendingCount',
                              ),
                            ),
                            SizedBox(
                              width: medium
                                  ? (wide
                                      ? 350
                                      : (constraints.maxWidth - 46) / 3)
                                  : double.infinity,
                              child: _StatCard(
                                icon: Icons.check_circle_outline_rounded,
                                color: _success,
                                label: 'Envoyés',
                                value: '$sentCount',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        const Text(
                          'Actions rapides',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            SizedBox(
                              width: medium
                                  ? (wide
                                      ? 520
                                      : (constraints.maxWidth - 46) / 2)
                                  : double.infinity,
                              child: _ActionCard(
                                title: 'Nouveau signalement',
                                subtitle: 'Photo, GPS, gravité et commentaire',
                                icon: Icons.add_a_photo_outlined,
                                highlight: true,
                                onTap: () => _navigate(const NewReportPage()),
                              ),
                            ),
                            SizedBox(
                              width: medium
                                  ? (wide
                                      ? 520
                                      : (constraints.maxWidth - 46) / 2)
                                  : double.infinity,
                              child: _ActionCard(
                                title: 'Mes signalements',
                                subtitle: 'Historique, recherche et suivi',
                                icon: Icons.list_alt_rounded,
                                badge: reports.length,
                                onTap: () => _navigate(const ReportsPage()),
                              ),
                            ),
                            SizedBox(
                              width: medium
                                  ? (wide
                                      ? 520
                                      : (constraints.maxWidth - 46) / 2)
                                  : double.infinity,
                              child: _ActionCard(
                                title: 'Carte GPS',
                                subtitle: 'Voir les points enregistrés',
                                icon: Icons.map_outlined,
                                onTap: () => _navigate(const MapPage()),
                              ),
                            ),
                            SizedBox(
                              width: medium
                                  ? (wide
                                      ? 520
                                      : (constraints.maxWidth - 46) / 2)
                                  : double.infinity,
                              child: _ActionCard(
                                title: syncing
                                    ? 'Synchronisation...'
                                    : 'Partager mes signalements',
                                subtitle: 'Envoyer les données vers Supabase',
                                icon: Icons.cloud_upload_outlined,
                                badge: alertCount,
                                onTap: syncing ? null : _shareReports,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (provider.error != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4F4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFFD9D9),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: _danger,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Erreur de stockage : ${provider.error}',
                                    style: const TextStyle(
                                      color: _danger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (provider.error != null) const SizedBox(height: 18),
                        _StorageCard(
                          email: user?.email,
                          mode: kIsWeb
                              ? 'Mode Web • SharedPreferences'
                              : 'Mode Android • SQLite',
                        ),
                        const SizedBox(height: 18),
                        const Center(
                          child: Text(
                            'ROAD ALERT • Projet L3 • Version offline-first',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String? userEmail;
  final int pendingCount;
  final VoidCallback onNewReport;

  const _HeroCard({
    required this.userEmail,
    required this.pendingCount,
    required this.onNewReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  userEmail == null
                      ? 'Mode hors ligne / démonstration'
                      : userEmail!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Signaler rapidement les dégradations routières',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Les données sont d’abord enregistrées localement, puis synchronisées plus tard si Internet est disponible.',
                style: TextStyle(
                  color: Color(0xFFE7F0FA),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              if (compact) ...[
                _HeroMiniInfo(
                  icon: Icons.notifications_active_outlined,
                  value: '$pendingCount',
                  label: 'élément(s) à synchroniser',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primaryDark,
                  ),
                  onPressed: onNewReport,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nouveau signalement'),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _HeroMiniInfo(
                        icon: Icons.notifications_active_outlined,
                        value: '$pendingCount',
                        label: 'élément(s) à synchroniser',
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 240,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _primaryDark,
                        ),
                        onPressed: onNewReport,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nouveau signalement'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroMiniInfo extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeroMiniInfo({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE7F0FA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      initialData: const [ConnectivityResult.none],
      builder: (context, snapshot) {
        final links = snapshot.data ?? const [ConnectivityResult.none];
        final online = links.any((e) => e != ConnectivityResult.none);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: online
                        ? const Color(0xFFEAF7EF)
                        : const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: online ? _success : _warning,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        online ? 'Réseau détecté' : 'Mode hors ligne',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        online
                            ? 'Le réseau est disponible, mais cela ne garantit pas toujours l’accès réel au serveur.'
                            : 'Aucun réseau détecté. Les données restent sauvegardées localement.',
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StorageCard extends StatelessWidget {
  final String? email;
  final String mode;

  const _StorageCard({
    required this.email,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF5FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.shield_outlined, color: _primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email ?? 'Compte non connecté',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
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
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool highlight;
  final int? badge;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.highlight = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? _primary : Colors.white;
    final fg = highlight ? Colors.white : _ink;
    final sub = highlight ? Colors.white70 : Colors.black54;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: highlight ? _primary : const Color(0xFFE7EDF5),
          ),
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: highlight
                    ? Colors.white.withValues(alpha: 0.14)
                    : const Color(0xFFF0F5FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: highlight ? Colors.white : _primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (badge != null && badge! > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _danger,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$badge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: sub,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: highlight ? Colors.white : Colors.black38,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  final int alertCount;
  final VoidCallback onNewReport;
  final VoidCallback onReports;
  final VoidCallback onMap;
  final VoidCallback onSync;
  final VoidCallback onAccount;

  const _HomeDrawer({
    required this.alertCount,
    required this.onNewReport,
    required this.onReports,
    required this.onMap,
    required this.onSync,
    required this.onAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _primaryDark],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: const [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.route_rounded, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ROAD ALERT\nMenu principal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _DrawerItem(
              icon: Icons.add_a_photo_outlined,
              title: 'Nouveau signalement',
              onTap: onNewReport,
            ),
            _DrawerItem(
              icon: Icons.list_alt_rounded,
              title: 'Mes signalements',
              onTap: onReports,
            ),
            _DrawerItem(
              icon: Icons.map_outlined,
              title: 'Carte GPS',
              onTap: onMap,
            ),
            _DrawerItem(
              icon: Icons.cloud_upload_outlined,
              title: 'Partager mes signalements',
              badge: alertCount,
              onTap: onSync,
            ),
            _DrawerItem(
              icon: Icons.person_outline_rounded,
              title: 'Compte',
              onTap: onAccount,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? badge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _primary),
      title: Row(
        children: [
          Expanded(child: Text(title)),
          if (badge != null && badge! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _danger,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _BadgeIcon({
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(icon)),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _AlertRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EDF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title • $value',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
