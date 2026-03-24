import 'package:flutter/material.dart';
import '../services/device_identity_service.dart';

class LiveSessionSheet extends StatefulWidget {
  final DeviceIdentityService identity;
  const LiveSessionSheet({super.key, required this.identity});

  @override
  State<LiveSessionSheet> createState() => _LiveSessionSheetState();
}

class _LiveSessionSheetState extends State<LiveSessionSheet> {
  final _codeController = TextEditingController();
  bool _showJoinField = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Live Drawing',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Start Session
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, {'action': 'create'}),
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text('Start Session',
                style: TextStyle(color: Colors.black, fontSize: 16)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Join Session
          if (!_showJoinField)
            OutlinedButton.icon(
              onPressed: () => setState(() => _showJoinField = true),
              icon: const Icon(Icons.login, color: Colors.black),
              label: const Text('Join Session',
                  style: TextStyle(color: Colors.black, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

          if (_showJoinField) ...[
            TextField(
              controller: _codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'ABCD92',
                counterText: '',
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              onSubmitted: (code) {
                if (code.length == 6) {
                  Navigator.pop(context, {
                    'action': 'join',
                    'code': code.toUpperCase()
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final code = _codeController.text.toUpperCase();
                if (code.length == 6) {
                  Navigator.pop(context, {'action': 'join', 'code': code});
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Join', style: TextStyle(fontSize: 16)),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
