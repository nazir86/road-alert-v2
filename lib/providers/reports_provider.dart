import 'package:flutter/foundation.dart';
import '../models/report.dart';
import '../repositories/local_database.dart';

class ReportsProvider extends ChangeNotifier {
  List<RoadReport> reports = [];
  bool loading = false;
  String? error;
  int get pending => reports.where((e) => e.localStatus != 'envoye').length;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      reports = await LocalDatabase.instance.all();
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> add(RoadReport item) async {
    await LocalDatabase.instance.save(item);
    await refresh();
  }

  Future<void> remove(String id) async {
    await LocalDatabase.instance.delete(id);
    await refresh();
  }
}
