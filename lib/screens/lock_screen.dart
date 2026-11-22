import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ticket.dart';

/// Pavé numérique de déverrouillage (et de création de PIN si [onPinChosen]).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.onUnlocked, this.onPinChosen, this.title});

  final VoidCallback? onUnlocked;
  final ValueChanged<String>? onPinChosen;
  final String? title;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const _length = 4;
  String _pin = '';
  String? _first;
  String? _error;

  bool get _choosing => widget.onPinChosen != null;

  @override
  void initState() {
    super.initState();
    if (!_choosing) WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final sec = context.read<AppState>().security;
    if (!sec.biometricEnabled) return;
    if (await sec.authenticateBiometric()) widget.onUnlocked?.call();
  }

  void _tap(String d) {
    if (_pin.length >= _length) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == _length) _submit();
  }

  void _submit() {
    if (_choosing) {
      if (_first == null) {
        setState(() {
          _first = _pin;
          _pin = '';
        });
      } else if (_first == _pin) {
        widget.onPinChosen!(_pin);
      } else {
        setState(() {
          _first = null;
          _pin = '';
          _error = 'Les codes ne correspondent pas';
        });
      }
      return;
    }
    if (context.read<AppState>().security.verifyPin(_pin)) {
      widget.onUnlocked?.call();
    } else {
      setState(() {
        _pin = '';
        _error = 'Code incorrect';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sec = context.read<AppState>().security;
    final title = widget.title ??
        (_choosing ? (_first == null ? 'Choisissez un code PIN' : 'Confirmez le code PIN') : 'Entrez votre code PIN');
    return Scaffold(
      backgroundColor: AppColors.blueDeep,
      appBar: _choosing ? AppBar(foregroundColor: Colors.white) : null,
      body: BlueScaffoldBody(
        child: SafeArea(
          child: Column(children: [
            const Spacer(),
            ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.asset('assets/icon/icon.png', width: 76)),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? AppColors.lime : Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 34,
              child: Center(child: Text(_error ?? '', style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w600))),
            ),
            const Spacer(),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              _row(row.map((d) => _key(d)).toList()),
            _row([
              (!_choosing && sec.biometricEnabled)
                  ? _iconKey(Icons.fingerprint, _tryBiometric)
                  : const SizedBox(width: 76, height: 76),
              _key('0'),
              _iconKey(Icons.backspace_outlined, () {
                if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
              }),
            ]),
            const SizedBox(height: 28),
          ]),
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: children),
      );

  Widget _key(String d) => _DigitKey(label: d, onTap: () => _tap(d));

  Widget _iconKey(IconData icon, VoidCallback onTap) => RoundIconButton(
        icon: icon,
        onTap: onTap,
        size: 76,
        background: Colors.white.withValues(alpha: 0.12),
      );
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          height: 76,
          child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }
}
