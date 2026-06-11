import 'package:flutter/material.dart';

class LockScreen extends StatefulWidget {
  final String pinCode;
  final VoidCallback onUnlocked;

  const LockScreen({
    super.key,
    required this.pinCode,
    required this.onUnlocked,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  String? _error;

  void _onKeyPress(String key) {
    if (_enteredPin.length >= 6) return;

    setState(() {
      _enteredPin += key;
      _error = null;
    });

    if (_enteredPin.length >= 4) {
      // Auto-check when 4+ digits entered
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        if (_enteredPin == widget.pinCode) {
          widget.onUnlocked();
        } else if (_enteredPin.length >= widget.pinCode.length) {
          setState(() {
            _error = 'PIN salah, coba lagi';
            _enteredPin = '';
          });
        }
      });
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Lock icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Aplikasi Terkunci',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan PIN untuk membuka',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),

                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.pinCode.length, (index) {
                    final filled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                  ),
                ],
                const SizedBox(height: 32),

                // Number pad
                _buildNumberPad(),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((k) => _buildKey(k)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((k) => _buildKey(k)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((k) => _buildKey(k)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 64, height: 64),
            _buildKey('0'),
            _buildDeleteKey(),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String key) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _onKeyPress(key),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          key,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return GestureDetector(
      onTap: _onDelete,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined, size: 24),
      ),
    );
  }
}
