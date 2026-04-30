import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/auth_service.dart';
import '../../../core/theme/app_theme.dart';

/// PIN 4자리 설정 (4단계). 토스 스타일 흰 배경 + 봇 메시지 + 숫자 키패드.
///
/// 단계:
///   1) PIN 입력 (●●●○ 게이지)
///   2) PIN 재입력 → 일치 시 다음, 불일치 시 1단계로 + shake
///   3) 생체 인증 사용 여부 (디바이스 지원 시)
///   4) auto-wipe 옵션 (10회 틀리면 전체 데이터 삭제)
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  static const routeName = '/auth/pin-setup';

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Step { setPin, confirmPin, biometric, autoWipe, done }

class _PinSetupScreenState extends State<PinSetupScreen> {
  _Step _step = _Step.setPin;
  String _firstPin = '';
  String _currentPin = '';
  bool _shake = false;
  bool _biometricAvailable = false;
  bool _saving = false;
  bool _shuffleKeys = true;
  late List<int> _digits;

  @override
  void initState() {
    super.initState();
    _digits = _shuffleKeys ? _shuffled() : List<int>.generate(10, (i) => i);
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await AuthService.instance.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  List<int> _shuffled() {
    final list = List<int>.generate(10, (i) => i);
    list.shuffle(math.Random.secure());
    return list;
  }

  void _onKey(int d) {
    if (_currentPin.length >= AuthService.pinLength) return;
    HapticFeedback.lightImpact();
    setState(() => _currentPin += d.toString());
    if (_currentPin.length == AuthService.pinLength) _onComplete();
  }

  void _onBackspace() {
    if (_currentPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(
      () => _currentPin = _currentPin.substring(0, _currentPin.length - 1),
    );
  }

  Future<void> _onComplete() async {
    switch (_step) {
      case _Step.setPin:
        _firstPin = _currentPin;
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        setState(() {
          _step = _Step.confirmPin;
          _currentPin = '';
          _digits = _shuffleKeys ? _shuffled() : _digits;
        });
        break;
      case _Step.confirmPin:
        if (_currentPin == _firstPin) {
          setState(() => _saving = true);
          await AuthService.instance.setPin(_firstPin);
          if (!mounted) return;
          setState(() {
            _saving = false;
            _step = _biometricAvailable ? _Step.biometric : _Step.autoWipe;
          });
        } else {
          await _shakeAndReset();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _shakeAndReset() async {
    setState(() => _shake = true);
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _shake = false;
      _step = _Step.setPin;
      _firstPin = '';
      _currentPin = '';
      _digits = _shuffleKeys ? _shuffled() : _digits;
    });
  }

  Future<void> _onBiometricYes() async {
    setState(() => _saving = true);
    final ok =
        await AuthService.instance.enableBiometric(_firstPin);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = _Step.autoWipe;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('생체 인증을 켜지 못했어요. 설정에서 다시 시도해주세요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onAutoWipe(bool enabled) async {
    setState(() => _saving = true);
    await AuthService.instance.setAutoWipeEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _step = _Step.done;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    context.go('/onboarding/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: _stepContent(),
        ),
      ),
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case _Step.setPin:
        return _PinInput(
          title: '안전을 위해 PIN을 설정해주세요 🔒',
          subtitle: '가족 건강 정보를 보호하는 4자리 비밀번호예요',
          currentLength: _currentPin.length,
          shake: _shake,
          digits: _digits,
          onKey: _onKey,
          onBackspace: _onBackspace,
          shuffleEnabled: _shuffleKeys,
          onToggleShuffle: () => setState(() {
            _shuffleKeys = !_shuffleKeys;
            _digits = _shuffleKeys
                ? _shuffled()
                : List<int>.generate(10, (i) => i);
          }),
        );
      case _Step.confirmPin:
        return _PinInput(
          title: '한 번 더 입력해주세요',
          subtitle: '같은 4자리를 똑같이 입력해주세요',
          currentLength: _currentPin.length,
          shake: _shake,
          digits: _digits,
          onKey: _onKey,
          onBackspace: _onBackspace,
          shuffleEnabled: _shuffleKeys,
          onToggleShuffle: () => setState(() {
            _shuffleKeys = !_shuffleKeys;
            _digits = _shuffleKeys
                ? _shuffled()
                : List<int>.generate(10, (i) => i);
          }),
        );
      case _Step.biometric:
        return _ChoiceStep(
          title: '생체 인증도 사용하시겠어요?',
          subtitle: 'Face ID / 지문으로 빠르게 잠금 해제',
          primaryLabel: '네, 사용할게요',
          secondaryLabel: 'PIN만 사용할게요',
          loading: _saving,
          onPrimary: _onBiometricYes,
          onSecondary: () => setState(() => _step = _Step.autoWipe),
        );
      case _Step.autoWipe:
        return _ChoiceStep(
          title: 'PIN을 10번 틀리면 데이터를 자동 삭제할까요?',
          subtitle: '분실 시 강력한 보호 옵션이에요. 기본은 사용 안 함이에요',
          primaryLabel: '네, 자동 삭제 사용',
          secondaryLabel: '아니오, 사용 안 함',
          loading: _saving,
          onPrimary: () => _onAutoWipe(true),
          onSecondary: () => _onAutoWipe(false),
        );
      case _Step.done:
        return const Center(
          child: Text(
            '✅ 보안 설정 완료',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
        );
    }
  }
}

class _PinInput extends StatelessWidget {
  const _PinInput({
    required this.title,
    required this.subtitle,
    required this.currentLength,
    required this.shake,
    required this.digits,
    required this.onKey,
    required this.onBackspace,
    required this.shuffleEnabled,
    required this.onToggleShuffle,
  });

  final String title;
  final String subtitle;
  final int currentLength;
  final bool shake;
  final List<int> digits;
  final void Function(int) onKey;
  final VoidCallback onBackspace;
  final bool shuffleEnabled;
  final VoidCallback onToggleShuffle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.subtle,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 40),
        AnimatedSlide(
          offset: shake ? const Offset(0.04, 0) : Offset.zero,
          duration: const Duration(milliseconds: 100),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(AuthService.pinLength, (i) {
              final filled = i < currentLength;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: filled ? AppTheme.primary : Colors.transparent,
                  border: Border.all(
                    color: filled ? AppTheme.primary : AppTheme.line,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
        const Spacer(),
        _Numpad(
          digits: digits,
          onKey: onKey,
          onBackspace: onBackspace,
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onToggleShuffle,
          icon: Icon(
            shuffleEnabled ? Icons.shuffle : Icons.grid_view_outlined,
            size: 16,
          ),
          label: Text(
            shuffleEnabled ? '보안 키패드 (랜덤)' : '일반 키패드',
            style: const TextStyle(fontSize: 13),
          ),
          style: TextButton.styleFrom(foregroundColor: AppTheme.subtle),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Numpad extends StatelessWidget {
  const _Numpad({
    required this.digits,
    required this.onKey,
    required this.onBackspace,
  });

  final List<int> digits;
  final void Function(int) onKey;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    // 9-key + bottom row (empty / 0 / backspace).
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 0; i < 9; i++) _key(digits[i]),
        const SizedBox.shrink(),
        _key(digits[9]),
        _backspaceKey(),
      ],
    );
  }

  Widget _key(int d) {
    return Material(
      color: AppTheme.cream,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onKey(d),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            d.toString(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _backspaceKey() {
    return InkWell(
      onTap: onBackspace,
      borderRadius: BorderRadius.circular(16),
      child: const Center(
        child: Icon(
          Icons.backspace_outlined,
          size: 24,
          color: AppTheme.subtle,
        ),
      ),
    );
  }
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.loading,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.subtle,
            height: 1.45,
          ),
        ),
        const Spacer(flex: 3),
        FilledButton(
          onPressed: loading ? null : onPrimary,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(primaryLabel),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: loading ? null : onSecondary,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.subtle,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(
            secondaryLabel,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
