import 'dart:async';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'discovery.dart';

enum SyncState { searching, connecting, connected, disconnected }

/// Manages WebSocket connection and clipboard sync with the Windows PC.
class SyncService {
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  String _lastClip = '';

  // Notifies the UI of state changes
  final void Function(SyncState state, String? pcAddress) onStateChange;

  SyncService({required this.onStateChange});

  Future<void> connect(PcInfo pc) async {
    onStateChange(SyncState.connecting, pc.toString());
    try {
      _channel = WebSocketChannel.connect(Uri.parse(pc.wsUrl));
      await _channel!.ready;
    } catch (e) {
      onStateChange(SyncState.disconnected, null);
      return;
    }

    onStateChange(SyncState.connected, pc.ip);

    // Listen for clipboard text from Windows
    _wsSub = _channel!.stream.listen(
      (data) async {
        final text = data.toString();
        if (text.isEmpty || text == _lastClip) return;
        _lastClip = text;
        await Clipboard.setData(ClipboardData(text: text));
      },
      onDone: () => onStateChange(SyncState.disconnected, null),
      onError: (_) => onStateChange(SyncState.disconnected, null),
      cancelOnError: true,
    );

    // Poll Android clipboard and send changes to Windows
    _startClipboardPoller();
  }

  Timer? _pollTimer;

  void _startClipboardPoller() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_channel == null) return;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty || text == _lastClip) return;
      _lastClip = text;
      try {
        _channel!.sink.add(text);
      } catch (_) {}
    });
  }

  void disconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
    _lastClip = '';
  }
}
