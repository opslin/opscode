import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';

/// Bumped whenever the server says "something changed for this vendor" (a new order, repair
/// request, sell offer / chat message, notification) and, as a safety net, now and then.
/// List providers `ref.watch` it, so what is on screen refetches by itself - no manual refresh.
final liveTickProvider = NotifierProvider<LiveTick, int>(LiveTick.new);

class LiveTick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

/// Latest push-style event (title/body) so the shell can show a banner. Null until one arrives.
final liveEventProvider =
    NotifierProvider<LiveEvent, Map<String, dynamic>?>(LiveEvent.new);

class LiveEvent extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() => null;
  void set(Map<String, dynamic> e) => state = e;
  void clear() => state = null;
}

/// True while the Partner Hub (home) is the screen the vendor is looking at. The home stays mounted underneath
/// every screen opened from it, so without this it kept refetching ~10 calls on every tick while hidden.
final homeVisibleProvider =
    NotifierProvider<HomeVisible, bool>(HomeVisible.new);

class HomeVisible extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool v) {
    if (state != v) state = v;
  }
}

/// [liveTickProvider], but only while the home is visible. A tick that arrives while the home is covered is
/// remembered and applied the moment the vendor comes back (and a long absence refreshes too), so what they see
/// is current when they see it - without spending requests on a screen nobody is looking at.
final homeLiveTickProvider =
    NotifierProvider<HomeLiveTick, int>(HomeLiveTick.new);

class HomeLiveTick extends Notifier<int> {
  /// Coming back after at least this long refreshes even if no event arrived meanwhile.
  static const staleAfter = Duration(seconds: 20);

  bool _dirty = false;
  DateTime? _hiddenAt;

  @override
  int build() {
    ref.listen<int>(liveTickProvider, (_, __) {
      if (ref.read(homeVisibleProvider)) {
        state++;
      } else {
        _dirty = true;
      }
    });
    ref.listen<bool>(homeVisibleProvider, (_, visible) {
      if (!visible) {
        _hiddenAt = DateTime.now();
        return;
      }
      final away = _hiddenAt == null
          ? Duration.zero
          : DateTime.now().difference(_hiddenAt!);
      _hiddenAt = null;
      if (_dirty || away >= staleAfter) {
        _dirty = false;
        state++;
      }
    });
    return 0;
  }
}

/// One Socket.IO connection for the whole signed-in session. Watch it once near the app root.
final liveServiceProvider = Provider<LiveService>((ref) {
  final service = LiveService(ref);
  ref.onDispose(service.dispose);
  ref.listen<bool>(
    authControllerProvider.select((s) => s.isSignedIn),
    (_, signedIn) => signedIn ? service.start() : service.stop(),
    fireImmediately: true,
  );
  return service;
});

class LiveService with WidgetsBindingObserver {
  LiveService(this._ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  io.Socket? _socket;
  Timer? _debounce;
  Timer? _heartbeat;
  Timer? _reconnect;
  bool _running = false;
  bool _foreground = true;

  /// A tick was wanted while the app was in the background; deliver one when it comes back.
  bool _owedWhileAway = false;
  DateTime _lastTick = DateTime.now();
  int _failures = 0;
  String? _lastBannerKey;
  DateTime _lastBannerAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// With a healthy socket the server tells us about changes, so the heartbeat is only a slow backstop.
  static const heartbeatConnected = Duration(seconds: 120);

  /// Without a socket there is nothing to tell us, so poll the way the app always did.
  static const heartbeatOffline = Duration(seconds: 25);

  static const _debounceFor = Duration(milliseconds: 600);

  /// Not about this vendor's work: connection chatter and storefront/admin broadcasts. Treating these as "something
  /// changed" made every admin theme edit refetch every screen on every vendor's phone.
  static bool isNoise(String event) =>
      event == 'ping' ||
      event == 'pong' ||
      event == 'connect' ||
      event == 'disconnect' ||
      event == 'error' ||
      event.startsWith('theme:') ||
      event.startsWith('section:') ||
      event.startsWith('dashboard:') ||
      event.startsWith('rider:');

  bool get connected => _socket?.connected ?? false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _failures = 0;
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => _beat());
    await _connect();
  }

  void stop() {
    _running = false;
    _heartbeat?.cancel();
    _reconnect?.cancel();
    _debounce?.cancel();
    _disposeSocket();
  }

  void dispose() {
    stop();
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Runs every 15 s but only acts when the quiet period for the current connection state has passed.
  void _beat() {
    if (!_running || !_foreground) return;
    final quiet = DateTime.now().difference(_lastTick);
    final due = connected ? heartbeatConnected : heartbeatOffline;
    if (quiet >= due) _bump(immediate: true);
  }

  Future<void> _connect() async {
    if (!_running) return;
    final url = dotenv.env['SOCKET_URL'] ?? '';
    final token = await _ref.read(secureStorageProvider).getAccessToken();
    if (!_running) return;
    if (url.isEmpty || token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }
    _disposeSocket();
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          // `app: vendor` tells the server this client has no storefront, so it is left out of theme broadcasts.
          .setAuth(<String, dynamic>{'token': token, 'app': 'vendor'})
          .disableAutoConnect()
          .disableReconnection() // we reconnect ourselves so a refreshed token is used
          .build(),
    );
    _socket = socket;
    socket
      ..onConnect((_) {
        _failures = 0;
        _bump(); // catch up on anything missed while offline
      })
      ..onDisconnect((_) => _scheduleReconnect())
      ..onConnectError((_) => _scheduleReconnect())
      ..onAny((String event, dynamic data) {
        if (isNoise(event)) return;
        if (data is Map && (data['title'] != null || data['body'] != null)) {
          _banner(Map<String, dynamic>.from(data));
        }
        _bump();
      })
      ..connect();
  }

  /// One banner per distinct message: the same alert can reach us as both a `vendor:refresh` and a `notification`.
  void _banner(Map<String, dynamic> e) {
    final key = '${e['title']}|${e['body']}';
    final now = DateTime.now();
    if (key == _lastBannerKey && now.difference(_lastBannerAt).inSeconds < 4) {
      return;
    }
    _lastBannerKey = key;
    _lastBannerAt = now;
    _ref.read(liveEventProvider.notifier).set(e);
  }

  /// 4 s, 8 s, 16 s ... capped at 60 s, so a server that is down is not hammered by every vendor phone.
  void _scheduleReconnect() {
    if (!_running) return;
    _reconnect?.cancel();
    final secs = (4 << _failures.clamp(0, 4)).clamp(4, 60);
    _failures++;
    _reconnect = Timer(Duration(seconds: secs), _connect);
  }

  void _disposeSocket() {
    final s = _socket;
    _socket = null;
    if (s != null) {
      s.clearListeners();
      s.dispose();
    }
  }

  /// Coalesce bursts (an order creates several events) into one refetch.
  void _bump({bool immediate = false}) {
    if (!_running) return;
    if (!_foreground) {
      _owedWhileAway = true;
      return;
    }
    _debounce?.cancel();
    if (immediate) {
      _fire();
    } else {
      _debounce = Timer(_debounceFor, _fire);
    }
  }

  void _fire() {
    if (!_running || !_foreground) {
      _owedWhileAway = _owedWhileAway || _running;
      return;
    }
    _lastTick = DateTime.now();
    _ref.read(liveTickProvider.notifier).bump();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nowForeground = state == AppLifecycleState.resumed;
    if (nowForeground == _foreground) return;
    _foreground = nowForeground;
    if (!nowForeground || !_running) return;
    // Back in the foreground: reconnect if the OS dropped the socket, and refresh once.
    _failures = 0;
    if (!connected) _connect();
    if (_owedWhileAway || DateTime.now().difference(_lastTick) > const Duration(seconds: 20)) {
      _owedWhileAway = false;
      _bump();
    }
  }
}
