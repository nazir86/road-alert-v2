import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});
  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportsProvider>().reports;
    return Scaffold(
        appBar: AppBar(title: const Text('Carte des signalements')),
        body: Stack(children: [
          FlutterMap(
              options: MapOptions(
                  initialCenter: reports.isNotEmpty
                      ? LatLng(reports.first.latitude, reports.first.longitude)
                      : const LatLng(-18.8792, 47.5079),
                  initialZoom: reports.isNotEmpty ? 13 : 11),
              children: [
                TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'mg.roadalert.app'),
                MarkerLayer(
                    markers: reports
                        .map((r) => Marker(
                            point: LatLng(r.latitude, r.longitude),
                            width: 48,
                            height: 48,
                            child: IconButton(
                              icon: Icon(Icons.location_pin,
                                  size: 38,
                                  color: r.severity == 'grave'
                                      ? Colors.red
                                      : r.severity == 'moyenne'
                                          ? Colors.orange
                                          : Colors.green),
                              onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      AlertDialog(
                                          title:
                                              Text(r.type.replaceAll('_', ' ')),
                                          content: Text(
                                              'Gravité : ${r.severity}\n${r.comment}\nGPS : ±${r.gpsAccuracy.toStringAsFixed(0)} m'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Fermer'))
                                          ])),
                            )))
                        .toList()),
                const RichAttributionWidget(attributions: [
                  TextSourceAttribution('OpenStreetMap contributors')
                ]),
              ]),
          const Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Card(
                  child: Padding(
                      padding: EdgeInsets.all(9),
                      child: Text(
                          'Le fond de carte nécessite Internet. Les points enregistrés restent accessibles.')))),
        ]));
  }
}
