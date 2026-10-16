import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/local_database.dart';

/// Synchronisation offline-first vers Supabase.
/// Les donnees restent dans SQLite en cas d'echec.
class SyncService {
  static bool _busy = false;

  Future<int> synchronize() async {
    if (_busy) return 0;

    _busy = true;
    int sent = 0;
    int failures = 0;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw Exception('Connectez-vous avant la synchronisation.');
      }

      // Verifier la presence d'un reseau.
      final connections = await Connectivity().checkConnectivity();

      if (connections.contains(ConnectivityResult.none)) {
        throw Exception('Aucune connexion reseau disponible.');
      }

      // Verifier un vrai acces au serveur.
      final profile = await client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        throw Exception(
          'Profil utilisateur introuvable dans Supabase.',
        );
      }

      final reports = await LocalDatabase.instance.all();

      for (final item in reports) {
        // Seuls les signalements non synchronises sont traites.
        if (item.localStatus != 'en_attente' && item.localStatus != 'erreur') {
          continue;
        }

        try {
          if (item.userId != null && item.userId != user.id) {
            throw Exception(
              'Ce signalement appartient a un autre compte.',
            );
          }

          final photo = File(item.photoPath);

          if (!await photo.exists()) {
            throw Exception('Photo locale introuvable.');
          }

          // Limite du bucket : 5 Mo.
          if (await photo.length() > 5 * 1024 * 1024) {
            throw Exception('Photo trop volumineuse (maximum 5 Mo).');
          }

          // Chemin fixe : evite les doublons de photos.
          final storagePath = '${user.id}/${item.id}.jpg';

          // 1. Envoyer la photo dans le bucket prive.
          await client.storage.from('road-alert-photos').upload(
                storagePath,
                photo,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'image/jpeg',
                ),
              );

          // Titre automatique selon le type de degradation.
          final String title;

          switch (item.type) {
            case 'nid_de_poule':
              title = 'Nid-de-poule';
            case 'fissure':
              title = 'Fissure';
            case 'affaissement':
              title = 'Affaissement';
            default:
              title = 'Degradation routiere';
          }

          // 2. Enregistrer dans la vraie table Supabase.
          //
          // ignoreDuplicates evite de remplacer un statut
          // deja modifie par un agent lors d'une nouvelle tentative.
          await client.from('signalements').upsert(
            {
              'id': item.id,
              'user_id': user.id,
              'titre': title,
              'type': item.type,
              'description': item.comment.trim().isEmpty
                  ? 'Sans commentaire'
                  : item.comment.trim(),
              'lieu': 'Lieu non renseigne - coordonnees GPS disponibles',
              'latitude': item.latitude,
              'longitude': item.longitude,
              'gravite': item.severity,
              'photo_path': storagePath,
              'gps_accuracy': item.gpsAccuracy,
              'duration_seconds': item.durationSeconds,
              'created_at': item.createdAt,
            },
            onConflict: 'id',
            ignoreDuplicates: true,
          );

          // 3. Confirmer que le signalement existe sur le serveur.
          final remote = await client
              .from('signalements')
              .select('id,user_id,photo_path')
              .eq('id', item.id)
              .maybeSingle();

          if (remote == null ||
              remote['user_id'] != user.id ||
              remote['photo_path'] != storagePath) {
            throw Exception(
              'Confirmation serveur impossible.',
            );
          }

          // 4. Marquer comme envoye uniquement apres confirmation.
          await LocalDatabase.instance.save(
            item.withStatus(
              'envoye',
              owner: user.id,
              remoteTime: DateTime.now().toUtc().toIso8601String(),
            ),
          );

          sent++;
        } catch (error) {
          failures++;

          // Conserver les donnees locales pour une prochaine tentative.
          await LocalDatabase.instance.save(
            item.withStatus(
              'erreur',
              error: error.toString(),
              attempts: item.retryCount + 1,
            ),
          );
        }
      }

      if (failures > 0) {
        throw Exception(
          '$failures signalement(s) non synchronise(s). '
          '$sent envoye(s). Consultez Mes signalements.',
        );
      }

      return sent;
    } finally {
      _busy = false;
    }
  }
}
