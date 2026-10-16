# ROAD ALERT V2 — Flutter Android offline-first

Projet Licence 3 : signalement des dégradations routières même sans Internet.
**Cette archive contient un socle source, pas encore un APK certifié prêt à installer.**

## 1. Prérequis
Flutter SDK, Android SDK, VS Code, téléphone Android avec débogage USB.
Sur Windows :
```powershell
& "C:\src\flutter\bin\flutter.bat" doctor -v
```

## 2. Créer le projet Flutter standard (avec les dossiers Android générés)
Dans un **nouveau dossier** `road_alert_v2` : extraire ce ZIP.
Ensuite, dans ce dossier :
```powershell
& "C:\src\flutter\bin\flutter.bat" create --platforms=android --org mg.roadalert .
& "C:\src\flutter\bin\flutter.bat" pub get
```
`flutter create .` génère les fichiers Android Gradle. Si Flutter vous demande de remplacer un fichier source existant, conservez celui de cette archive.

## 3. Permissions Android
Éditer `android/app/src/main/AndroidManifest.xml` et ajouter, immédiatement sous `<manifest ...>` :
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
```
Android 13+ demande des autorisations caméra/localisation à l'exécution.
Le module utilise `image_picker` et `geolocator` pour gérer les demandes pertinentes.

## 4. Premier test Android hors ligne
```powershell
& "C:\src\flutter\bin\flutter.bat" devices
& "C:\src\flutter\bin\flutter.bat" run -d <ID_TELEPHONE>
```
1. Prendre une photo, attendre le GPS, choisir type et gravité.
2. Activer le mode avion **après obtention de la position GPS**, ou garder la localisation active si disponible.
3. Appuyer « Enregistrer hors ligne » ; vérifier la liste.
4. Fermer puis rouvrir l'application ; le signalement doit être toujours présent.

**Attention :** `sqflite` dans cette configuration cible Android/iOS, pas Chrome.

## 5. Supabase
Créer un **nouveau projet Supabase** pour V2 ou préparer une migration contrôlée.
Exécuter `supabase/schema.sql` dans le SQL Editor d'un projet vide.
Activer Email Auth, créer un utilisateur confirmé et s'y connecter dans ROAD ALERT.
Configuration du lancement (PowerShell, valeurs dans les variables d'environnement) :
```powershell
$env:SUPABASE_URL = 'https://VOTRE-PROJET.supabase.co'
$env:SUPABASE_PUBLISHABLE_KEY = Read-Host 'Clé publishable Supabase'
& "C:\src\flutter\bin\flutter.bat" run -d <ID_TELEPHONE> `
  --dart-define="SUPABASE_URL=$env:SUPABASE_URL" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY"
```
Ne mettez JAMAIS la clé `service_role` dans le mobile.

## 6. Structure
```text
road_alert_v2/
  lib/
    main.dart
    models/report.dart
    repositories/local_database.dart
    providers/reports_provider.dart
    services/{gps_service,photo_service,sync_service}.dart
    ui/{auth_page,new_report_page,reports_page,map_page}.dart
  supabase/schema.sql
  docs/CONCEPTION.md
  pubspec.yaml
```

## 7. Ce qui est livré / à finaliser
- Inclus : accueil, formulaire photo + GPS, précision GPS, SQLite, liste, recherche simple,
  carte OSM avec marqueurs colorés, compte Supabase simple, synchronisation **manuelle** idempotente.
- Restant : gestion avancée des statuts et des rôles dans Flutter, synchronisation automatique,
  traitement des erreurs à délai croissant, regroupement des marqueurs, filtres avancés,
  statistiques, CSV, vrai parcours de récupération de mot de passe, tests sur téléphone réel.

**Ne remplacez pas votre ancien dossier `road_alert` sans sauvegarde.**
