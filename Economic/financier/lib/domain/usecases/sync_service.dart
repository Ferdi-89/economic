import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

/// Handles online/offline sync logic.
/// Future: queue offline mutations, replay when online.
class SyncService {
  final Connectivity _connectivity;
  final log = Logger();

  SyncService(this._connectivity);

  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged
          .map((results) => results.any((r) => r != ConnectivityResult.none));

  Future<void> sync() async {
    if (!await isOnline) {
      log.w('Offline — skip sync');
      return;
    }
    // TODO: Implement full sync logic:
    // 1. Pull latest from Supabase
    // 2. Push local queued mutations
    // 3. Resolve conflicts (last-write-wins)
    log.i('Sync completed');
  }
}
