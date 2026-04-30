import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/auth_service.dart';
import '../../../core/theme/app_theme.dart';

/// 잠금 해제 화면. 다음 시점에서 노출:
/// - 앱 실행 시 PIN 설정되어 있고 세션 만료 (5분 이상 background)
/// - 민감 액션(데이터 삭제/내보내기) 직전 fresh auth 필요
///
/// 흐름:
/// 1) 시작 시 생체 ON 이면 자동으로 prompt
/// 2) 실패하거나 PIN으로 입력 누르면 키패드
/// 3) 5회 실패 → 5분 잠금 + 카운트다운
/// 4) 10회 실패 + auto-wipe ON → 5초 카운트다운 후 SecureStorage.wipe(),
///    auto-wipe OFF → 30분 잠금
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({this.onUnlocked, super.key});

  final VoidCallback? onUnlocked;

  static const routeName = '/auth/lock';

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _currentPin = '';
  bool _shake = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _wipeImminent = false;
  Timer? _wipeTicker;
  int _wipeCountdown = 5;
  late List<int> _digits;

  @override
  void initState() {
    super.initState();
    _digits = _shuffled();
    _startTicker();
    _refreshState();
    // 자동 생체 prompt — 잠금 안 걸려있을 때만.
    Future.microtask(_tryBiometric);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _wipeTicker?.cancel();
    super.dispose();
  }

  Future<void> _refreshState() async {
    final attempts = await AuthService.instance.getFailedAttempts();
    final lockUntil = await AuthService.instance.getLockoutUntil();
    if (!mounted) return;
    setState(() {
      _failedAttempts = attempts;
      _lockoutUntil = lockUntil;
      _updateRemaining();
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_updateRemaining);
    });
  }

  void _updateRemaining() {
    final until = _lockoutUntil;
    if (until == null) {
      _remaining = Duration.zero;
      return;
    }
    final left = until.difference(DateTime.now().toUtc());
    _remaining = left.isNegative ? Duration.zero : left;
    if (_remaining == Duration.zero) {
      _lockoutUntil = null;
    }
  }

  Future<void> _tryBiometric() async {
    if (await AuthService.instance.isLockedOut()) return;
    if (!await AuthService.instance.isBiometricEnabled()) return;
    final ok = await AuthService.instance.authenticateWithBiometric();
    if (ok && mounted) _onUnlocked();
  }

  List<int> _shuffled() {
    final list = List<int>.generate(10, (i) => i);
    list.shuffle(math.Random.secure());
    return list;
  }

  void _onKey(int d) async {
    if (_lockoutDisabledNow()) return;
    if (_currentPin.length >= AuthService.pinLength) return;
    HapticFeedback.lightImpact();
    setState(() => _currentPin += d.toString());
    if (_currentPin.length == AuthService.pinLength) {
      await _verify();
    }
  }

  void _onBackspace() {
    if (_currentPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(
      () => _currentPin = _currentPin.substring(0, _currentPin.length - 1),
    );
  }

  bool _lockoutDisabledNow() => _remaining > Duration.zero;

  Future<void> _verify() async {
    final pin = _currentPin;
    final ok = await AuthService.instance.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      _onUnlocked();
      return;
    }
    setState(() {
      _shake = true;
      _currentPin = '';
      _digits = _shuffled();
    });
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _shake = false);
    await _refreshState();

    // 10회 도달 시 자동 삭제 분기.
    if (_failedAttempts >= AuthService.wipeOnFailedAttempts) {
      final autoWipe = await AuthService.instance.isAutoWipeEnabled();
      if (autoWipe) _startWipeCountdown();
    }
  }

  void _onUnlocked() {
    if (widget.onUnlocked != null) {
      widget.onUnlocked!();
      return;
    }
    if (mounted) context.go('/home');
  }

  void _startWipeCountdown() {
    if (_wipeImminent) return;
    setState(() {
      _wipeImminent = true;
      _wipeCountdown = 5;
    });
    _wipeTicker = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _wipeCountdown -= 1);
      if (_wipeCountdown <= 0) {
        t.cancel();
        await AuthService.instance.handleMaxFailures();
        if (!mounted) return;
        context.go('/privacy-consent');
      }
    });
  }

  void _cancelWipe() {
    _wipeTicker?.cancel();
    setState(() => _wipeImminent = false);
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_wipeImminent) return _wipeScreen();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Text(
                'PIN을 입력해주세요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusLine(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _failedAttempts > 0
                      ? AppTheme.danger
                      : AppTheme.subtle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              AnimatedSlide(
                offset: _shake ? const Offset(0.04, 0) : Offset.zero,
                duration: const Duration(milliseconds: 100),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(AuthService.pinLength, (i) {
                    final filled = i < _currentPin.length;
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
              if (_lockoutDisabledNow())
                Text(
                  '${_formatRemaining(_remaining)} 후 다시 시도해주세요',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                _Numpad(
                  digits: _digits,
                  onKey: _onKey,
                  onBackspace: _onBackspace,
                ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint, size: 18),
                label: const Text('생체 인증으로 잠금 해제'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.subtle),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLine() {
    if (_lockoutDisabledNow()) {
      return _failedAttempts >= AuthService.wipeOnFailedAttempts
          ? 'PIN을 ${AuthService.wipeOnFailedAttempts}번 틀리셨어요'
          : 'PIN을 ${AuthService.maxFailedAttempts}번 틀리셨어요';
    }
    if (_failedAttempts == 0) return '안전을 위해 잠금 해제가 필요해요';
    return 'PIN이 틀렸어요 ($_failedAttempts/${AuthService.maxFailedAttempts})';
  }

  Widget _wipeScreen() {
    return Scaffold(
      backgroundColor: AppTheme.danger,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 60),
              const SizedBox(height: 16),
              const Text(
                '보안을 위해 데이터를 삭제할게요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '$_wipeCountdown초 후 모든 데이터가 사라집니다',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.danger,
                  ),
                  onPressed: () async {
                    _wipeTicker?.cancel();
                    await AuthService.instance.handleMaxFailures();
                    if (!mounted) return;
                    context.go('/privacy-consent');
                  },
                  child: const Text('지금 삭제'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: _cancelWipe,
                  child: const Text('취소'),
                ),
              ),
            ],
          ),
        ),
      ),
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
        InkWell(
          onTap: onBackspace,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Icon(
              Icons.backspace_outlined,
              size: 24,
              color: AppTheme.subtle,
            ),
          ),
        ),
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
}
