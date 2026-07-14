import 'dart:async';
import 'package:flutter/material.dart';
import 'discovery.dart';
import 'sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SyncState _state = SyncState.searching;
  String _pcAddress = '';

  final _discovery = Discovery();
  late final SyncService _sync;
  StreamSubscription? _discoverySub;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _sync = SyncService(onStateChange: _handleStateChange);
    _startDiscovery();
  }

  void _handleStateChange(SyncState state, String? address) {
    if (!mounted) return;
    setState(() {
      _state = state;
      if (address != null) _pcAddress = address;
    });

    // If disconnected, restart discovery to find PC again
    if (state == SyncState.disconnected) {
      _sync.disconnect();
      _connecting = false;
      _startDiscovery();
    }
  }

  void _startDiscovery() {
    _discoverySub?.cancel();
    setState(() => _state = SyncState.searching);

    _discoverySub = _discovery.start().listen((pc) async {
      if (_connecting || _state == SyncState.connected) return;
      _connecting = true;

      // Stop listening for more beacons once we find one
      _discoverySub?.cancel();
      _discovery.stop();

      await _sync.connect(pc);
    });
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    _discovery.stop();
    _sync.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              _buildIcon(),
              const SizedBox(height: 32),

              // App title
              const Text(
                'ClipSync',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 40),

              // Status card
              _buildStatusCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final isConnected = _state == SyncState.connected;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isConnected ? Colors.green : Colors.blueGrey).withOpacity(0.15),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.blueGrey,
          width: 2,
        ),
      ),
      child: Icon(
        Icons.content_paste_rounded,
        size: 44,
        color: isConnected ? Colors.green : Colors.blueGrey,
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _buildStatusRow(),
          if (_state == SyncState.connected) ...[
            const SizedBox(height: 12),
            Text(
              _pcAddress,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    switch (_state) {
      case SyncState.searching:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blueGrey.shade300,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Searching for PC...',
              style: TextStyle(
                color: Colors.blueGrey.shade300,
                fontSize: 16,
              ),
            ),
          ],
        );

      case SyncState.connecting:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange.shade300,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Connecting...',
              style: TextStyle(
                color: Colors.orange.shade300,
                fontSize: 16,
              ),
            ),
          ],
        );

      case SyncState.connected:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 10),
            Text(
              'Connected',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );

      case SyncState.disconnected:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blueGrey.shade300,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Reconnecting...',
              style: TextStyle(
                color: Colors.blueGrey.shade300,
                fontSize: 16,
              ),
            ),
          ],
        );
    }
  }
}
