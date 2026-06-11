import 'package:flutter/material.dart';

class AuthService {
  /// Show PIN entry dialog, returns entered PIN or null if cancelled
  static Future<String?> showPinDialog(BuildContext context, {String title = 'Masukkan PIN'}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'PIN',
              hintText: 'Masukkan PIN (4-6 digit)',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.length >= 4) {
                  Navigator.of(ctx).pop(controller.text);
                }
              },
              child: const Text('Konfirmasi'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  /// Show PIN creation dialog, returns new PIN or null
  static Future<String?> showCreatePinDialog(BuildContext context) async {
    final controller1 = TextEditingController();
    final controller2 = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Buat PIN Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller1,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN Baru',
                      hintText: '4-6 digit',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller2,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi PIN',
                      hintText: 'Ulangi PIN',
                      counterText: '',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller1.text.length < 4) {
                      setDialogState(() => error = 'PIN minimal 4 digit');
                      return;
                    }
                    if (controller1.text != controller2.text) {
                      setDialogState(() => error = 'PIN tidak cocok');
                      return;
                    }
                    Navigator.of(ctx).pop(controller1.text);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
    controller1.dispose();
    controller2.dispose();
    return result;
  }
}
