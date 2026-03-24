import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void startListening(void Function(bool isOnline) onChange) {
    _subscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final online =
            results.isNotEmpty && !results.contains(ConnectivityResult.none);
        if (online != _isOnline) {
          _isOnline = online;
          onChange(online);
        }
      },
    );
  }

  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
