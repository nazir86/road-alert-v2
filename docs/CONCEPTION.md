# ROAD ALERT — Conception Licence 3

## Problématique
Une collecte mobile hors ligne peut-elle améliorer la rapidité et la précision des signalements de dégradations routières dans un quartier pilote à Madagascar ?

## Acteurs
- **Citoyen** : crée un rapport, consulte sa progression, consulte la carte.
- **Agent** : consulte tous les rapports, change le statut, exporte des données.
- **Admin** : gère les rôles et les utilisateurs via une interface sécurisée.

## Architecture
```text
Flutter Android (UI Material 3)
          |
       Provider
          |
    Repositories / Services
       /          \
 SQLite local      GPS / appareil photo
       |
  SyncService <---- réseau vérifié
       |
 Supabase Auth + PostgreSQL + Storage (RLS)
```

## Relations serveur
```text
auth.users (1) ---- (1) profiles
profiles   (1) ---- (N) reports
reports    (1) ---- (N) status_history
profiles   (1) ---- (N) status_history (changed_by)
Storage photos/<user_id>/<report_id>.jpg
```

## Table SQLite
- `local_reports.id` est un UUID généré sur le téléphone ; clé primaire.
- `photo_path` est un chemin local, pas un blob.
- `status_local` : brouillon / en_attente / envoye / erreur.
- `created_at`, `duration_seconds`, `gps_accuracy` sont conservés pour le mémoire.

## Cycle de vie
1. Saisie photo et GPS.
2. Compression et copie photo dans le dossier privé de l'application.
3. Création UUID et écriture SQLite ; fonctionne hors ligne.
4. À la synchronisation, vérifier la session utilisateur et l'accès au serveur.
5. Upload Storage sous un nom déterministe.
6. Upsert dans reports avec la même clé primaire.
7. Marquer localement `envoye` seulement après succès confirmé.
8. Erreur : conserver l'élément, augmenter `retry_count`, permettre un nouvel essai.

## Règles de sécurité
RLS sur les trois tables. `profiles.role` n'est jamais modifiable par les utilisateurs ordinaires.
Les changements de statut sont journalisés par trigger PostgreSQL.
La clé publishable n'est pas un secret ; la clé `service_role` ne va **jamais** dans Flutter.

## Limites de cette livraison
Le socle inclut le formulaire, photo, GPS, SQLite, liste, carte, authentification simple et synchronisation manuelle.
Il reste à développer : gestion de sessions hors ligne sans connexion initiale, synchronisation automatique au retour du réseau et backoff temporel, regroupement/filtres de carte, espace agent/admin Flutter, export CSV et graphiques, parcours complet de réinitialisation du mot de passe, batteries de tests automatisés, APK testé.
La compatibilité des paquets n'a pas été validée par compilation dans cet environnement.
