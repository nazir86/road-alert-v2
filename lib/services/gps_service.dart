import 'package:geolocator/geolocator.dart';

class GpsService {
  static Future<Position> locate() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Activez la localisation sur votre appareil puis reessayez.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Autorisation de localisation refusee.');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return last;
      }
      rethrow;
    }
  }

  static bool isInMadagascar(Position p) {
    return p.latitude >= -26.5 &&
        p.latitude <= -11.0 &&
        p.longitude >= 42.0 &&
        p.longitude <= 51.8;
  }
}
