import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionService with WidgetsBindingObserver {
  static final SessionService _instance = SessionService._();
  factory SessionService() => _instance;
  SessionService._();

  Timer? _timer;
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);

    // Initial touch
    _touch();

    // Every 45 seconds
    _timer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _touch(),
    );
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _touch();
    }
  }

  Future<void> _touch() async {
    final me = _supabase.auth.currentUser?.id;
    if (me == null) return;

    try {
      await _supabase.rpc('touch_last_seen');
    } catch (_) {
      // Silently ignore — this is not critical
    }
  }
}
