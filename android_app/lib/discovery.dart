import 'dart:async';
import 'dart:io';

const int beaconPort = 54320;
const String beaconPrefix = 'CLIPSYNC:';

/// Listens for UDP broadcast beacons from the Windows PC.
/// Returns a stream of discovered [PcInfo] (IP + WS port).
class Discovery {
  RawDatagramSocket? _socket;

  Stream<PcInfo> start() async* {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      beaconPort,
      reuseAddress: true,
      reusePort: false,
    );
    _socket!.broadcastEnabled = true;

    await for (final event in _socket!) {
      if (event != RawSocketEvent.read) continue;
      final datagram = _socket!.receive();
      if (datagram == null) continue;

      final message = String.fromCharCodes(datagram.data).trim();
      if (!message.startsWith(beaconPrefix)) continue;

      final portStr = message.substring(beaconPrefix.length);
      final wsPort = int.tryParse(portStr);
      if (wsPort == null) continue;

      yield PcInfo(
        ip: datagram.address.address,
        wsPort: wsPort,
      );
    }
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}

class PcInfo {
  final String ip;
  final int wsPort;
  const PcInfo({required this.ip, required this.wsPort});

  String get wsUrl => 'ws://$ip:$wsPort';

  @override
  String toString() => '$ip:$wsPort';
}
