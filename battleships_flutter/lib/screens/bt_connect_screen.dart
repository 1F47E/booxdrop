// lib/screens/bt_connect_screen.dart
//
// Bluetooth device discovery screen for Battleships.
//
// Scans for nearby classic Bluetooth devices using flutter_bluetooth_serial.
// The user taps a discovered device and this screen pops with the chosen
// BluetoothDevice as its result, so the caller can call connectBtGuest().
//
// E-ink rules:
//   - 16px+ fonts throughout
//   - 48dp+ touch targets
//   - High-contrast black-on-white only

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../services/bt_permissions.dart';

class BtConnectScreen extends StatefulWidget {
  const BtConnectScreen({super.key});

  @override
  State<BtConnectScreen> createState() => _BtConnectScreenState();
}

class _BtConnectScreenState extends State<BtConnectScreen> {
  static const _scanTimeout = 12;

  final List<BluetoothDevice> _devices = [];
  bool _scanning = false;
  bool _btUnavailable = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _scanning = true;
      _btUnavailable = false;
      _statusMessage = null;
    });

    final enabled = await BtPermissions.isBluetoothEnabled();
    if (!enabled) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _btUnavailable = true;
        _statusMessage = 'Bluetooth is off. Enable it in Settings and try again.';
      });
      return;
    }

    // Run scan, collecting results incrementally via a stream.
    try {
      final completer = Completer<void>();
      StreamSubscription? sub;

      sub = FlutterBluetoothSerial.instance.startDiscovery().listen(
        (result) {
          if (mounted) {
            setState(() {
              // De-duplicate by address.
              final existing = _devices.indexWhere(
                (d) => d.address == result.device.address,
              );
              if (existing >= 0) {
                _devices[existing] = result.device;
              } else {
                _devices.add(result.device);
              }
            });
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      // Enforce the timeout.
      Future.delayed(const Duration(seconds: _scanTimeout), () {
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;
      await sub.cancel();
      try {
        await FlutterBluetoothSerial.instance.cancelDiscovery();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Scan error: $e';
        });
      }
    }

    if (mounted) {
      setState(() {
        _scanning = false;
        if (_devices.isEmpty) {
          _statusMessage =
              'No devices found. Make sure the other tablet is hosting a game and is discoverable.';
        }
      });
    }
  }

  void _onDeviceTapped(BluetoothDevice device) {
    Navigator.of(context).pop(device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1565C0)),
          onPressed: () => Navigator.of(context).pop(null),
          tooltip: 'Back',
        ),
        title: const Text(
          'Find Nearby Game',
          style: TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_scanning)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1565C0)),
              onPressed: _startScan,
              tooltip: 'Scan again',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Helper text
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Both tablets must have Bluetooth on.\n'
                'If Android asks to pair, tap "Pair" on both tablets.',
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),

            // Scan indicator
            if (_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: _ScanningIndicator(),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_searching,
                        color: Color(0xFF1565C0), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '${_devices.length} device${_devices.length == 1 ? '' : 's'} found',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF444444),
                      ),
                    ),
                  ],
                ),
              ),

            // Status message
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: _btUnavailable
                            ? const Color(0xFFCC0000)
                            : const Color(0xFF444444),
                        width: 4,
                      ),
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 16,
                      color: _btUnavailable
                          ? const Color(0xFFCC0000)
                          : const Color(0xFF444444),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Device list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _devices.length,
                separatorBuilder: (ctx, i) => const Divider(
                  height: 1,
                  color: Color(0xFFDDDDDD),
                ),
                itemBuilder: (context, i) {
                  final device = _devices[i];
                  return _DeviceRow(
                    device: device,
                    onTap: () => _onDeviceTapped(device),
                  );
                },
              ),
            ),

            // Bottom: Scan again button
            if (!_scanning)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Scan Again',
                      style: TextStyle(fontSize: 17),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0), width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scanning indicator
// ---------------------------------------------------------------------------

class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF1565C0),
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Scanning for nearby games...',
          style: TextStyle(fontSize: 16, color: Color(0xFF444444)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Device row
// ---------------------------------------------------------------------------

class _DeviceRow extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onTap;

  const _DeviceRow({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = device.name?.isNotEmpty == true ? device.name! : 'Unknown device';
    final address = device.address;
    final isPaired = device.isBonded;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1565C0), width: 2),
              ),
              child: Icon(
                isPaired ? Icons.bluetooth_connected : Icons.bluetooth,
                color: const Color(0xFF1565C0),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),

            // Name + address
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  if (isPaired)
                    const Text(
                      'Paired',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // Connect arrow
            const Icon(Icons.chevron_right, color: Color(0xFF1565C0), size: 32),
          ],
        ),
      ),
    );
  }
}
