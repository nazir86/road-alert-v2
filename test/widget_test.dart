import 'package:flutter_test/flutter_test.dart';
import 'package:road_alert/models/report.dart';

void main() {
  test('Un signalement conserve ses données hors ligne', () {
    const report = RoadReport(
      id: 'test-001',
      latitude: -18.8792,
      longitude: 47.5079,
      gpsAccuracy: 12.5,
      type: 'nid_de_poule',
      severity: 'grave',
      comment: 'Route endommagée',
      photoPath: '/photos/test.jpg',
      localStatus: 'en_attente',
      createdAt: '2026-10-16T09:00:00',
      durationSeconds: 45,
    );

    expect(report.id, 'test-001');
    expect(report.localStatus, 'en_attente');
    expect(report.gpsAccuracy, 12.5);
    expect(report.toMap()['duration_seconds'], 45);
  });
}
