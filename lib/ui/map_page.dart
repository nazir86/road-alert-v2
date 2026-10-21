import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/reports_provider.dart';

const mapTilerKey = String.fromEnvironment('MAPTILER_API_KEY');

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  bool satellite = false;

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
                  key: ValueKey(satellite ? 'satellite' : 'plan'),
                  urlTemplate: satellite
                      ? 'https://api.maptiler.com/maps/satellite-v4/{z}/{x}/{y}@2x.jpg?key=$mapTilerKey'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileSize: 256.0,
                  zoomOffset: 0.0,
                  retinaMode: false,
                  userAgentPackageName: 'mg.roadalert.app',
                ),
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
                RichAttributionWidget(
                  attributions: [
                    if (satellite) ...[
                      LogoSourceAttribution(
                        Image.network(
                          'https://media.maptiler.com/old/mediakit/logo/maptiler-logo.png',
                          height: 22,
                        ),
                        tooltip: 'MapTiler',
                        onTap: () async {
                          await launchUrl(
                            Uri.parse('https://www.maptiler.com/'),
                          );
                        },
                      ),
                      TextSourceAttribution(
                        'MapTiler',
                        onTap: () async {
                          await launchUrl(
                            Uri.parse('https://www.maptiler.com/copyright/'),
                          );
                        },
                      ),
                    ],
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () async {
                        await launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        );
                      },
                    ),
                  ],
                ),
              ]),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Plan'),
                          selected: !satellite,
                          onSelected: (_) {
                            setState(() => satellite = false);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Satellite HD'),
                          selected: satellite,
                          onSelected: mapTilerKey.isEmpty
                              ? null
                              : (_) {
                                  setState(() => satellite = true);
                                },
                        ),
                      ],
                    ),
                    Text(
                      mapTilerKey.isEmpty
                          ? 'Cle MapTiler manquante.'
                          : 'Fond de carte : Internet necessaire.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]));
  }
}
