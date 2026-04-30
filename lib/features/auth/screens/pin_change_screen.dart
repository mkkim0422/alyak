import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/security/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/pin_numpad.dart';

/// PIN 변경. 3 단계: 현재 PIN → 새 PIN → 새 PIN 확인.
///
/// 현재 PIN 검증은 [AuthService.changePin] 이 처리한다 (잠금 카운터까지 같이).
/// PIN 자체를 비활성화하는 흐름은 의도적으로 제공하지 않는다 — 의료 데이터
/// 보호를 위한 보호망이므로, 해제하려면 [SettingsScreen] 의 "데이터 삭제" 로
/// 전체 wipe 후 재시작해야 한다.
class PinChangeScreen extends StatefulWidget {
  const PinChangeScreen({super.key});

  static const routeName = '/auth/pin-change';

  @override
  State<PinChangeScreen> createState() => _PinChangeScreenState();
}

enum _Step { current, newPin, confirmPin, done }

class _PinChangeScreenState extends State<PinChangeScreen> {
  _Step _step = _Step.current;
  String _currentEntry = '';
  String _newPin = '';
  String _verifiedCurrentPin = '';
  bool _shake = false;
  bool _saving = false;
  bool _shuffleKeys = true;
  late List<int> _digits;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _digits = shuffledDigits();
  }

  void _onKey(int d) {
    if (_currentEntry.length >= AuthService.pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentEntry += d.toString();
      _errorText = null;
    });
    if (_currentEntry.length == AuthService.pinLength) _onComplete();
  }

  void _onBackspace() {
    if (_currentEntry.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(
      () => _currentEntry = _currentEntry.substring(0, _currentEntry.length - 1),
    );
  }

  Future<void> _onComplete() async {
    switch (_step) {
      case _Step.current:
        setState(() => _saving = true);
        final ok = await AuthService.instance.verifyPin(_currentEntry);
        if (!mounted) return;
        if (ok) {
          _verifiedCurrentPin = _currentEntry;
          setState(() {
            _saving = false;
            _step = _Step.newPin;
            _currentEntry = '';
            _digits = _shuffleKeys ? shuffledDigits() : _digits;
          });
        } else {
          await _shakeAndReset(error: 'PIN이 맞지 않아요');
        }
        break;
      case _Step.newPin:
        _newPin = _currentEntry;
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        setState(() {
          _step = _Step.confirmPin;
          _currentEntry = '';
          _digits = _shuffleKeys ? shuffledDigits() : _digits;
        });
        break;
      case _Step.confirmPin:
        if (_currentEntry == _newPin) {
          setState(() => _saving = true);
          await AuthService.instance
              .changePin(_verifiedCurrentPin, _newPin);
          if (!mounted) return;
          setState(() {
            _saving = false;
            _step = _Step.done;
          });
          await Future.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN이 변경됐어요'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        } else {
          await _shakeAndReset(
            error: '새 PIN이 일치하지 않아요. 다시 입력해주세요',
            backTo: _Step.newPin,
          );
        }
        break;
      case _Step.done:
        break;
    }
  }

  Future<void> _shakeAndReset({
    required String error,
    _Step? backTo,
  }) async {
    setState(() {
      _shake = true;
      _saving = false;
      _errorText = error;
    });
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _shake = false;
      _step = backTo ?? _step;
      _currentEntry = '';
      _newPin = backTo == _Step.newPin ? '' : _newPin;
      _digits = _shuffleKeys ? shuffledDigits() : _digits;
    });
  }

  String _title() {
    switch (_step) {
      case _Step.current:
        return '현재 PIN을 입력해주세요';
      case _Step.newPin:
        return '새 PIN 4자리를 정해주세요';
      case _Step.confirmPin:
        return '새 PIN을 한 번 더 입력해주세요';
      case _Step.done:
        return '✅ PIN 변경 완료';
    }
  }

  String _subtitle() {
    switch (_step) {
      case _Step.current:
        return '본인 확인 후 새 PIN을 설정해요';
      case _Step.newPin:
        return '4자리 숫자를 입력해주세요';
      case _Step.confirmPin:
        return '같은 PIN을 다시 입력해주세요';
      case _Step.done:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.ink,
        title: const Text('PIN 변경'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(
                _title(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.subtle),
              ),
              const SizedBox(height: 24),
              AnimatedSlide(
                offset: _shake ? const Offset(0.04, 0) : Offset.zero,
                duration: const Duration(milliseconds: 100),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(AuthService.pinLength, (i) {
                    final filled = i < _currentEntry.length;
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
              const SizedBox(height: 12),
              if (_errorText != null)
                Text(
                  _errorText!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              if (_step != _Step.done && !_saving)
                PinNumpad(
                  digits: _digits,
                  onKey: _onKey,
                  onBackspace: _onBackspace,
                ),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              const SizedBox(height: 8),
              PinShuffleToggle(
                shuffleEnabled: _shuffleKeys,
                onToggle: () => setState(() {
                  _shuffleKeys = !_shuffleKeys;
                  _digits = _shuffleKeys ? shuffledDigits() : orderedDigits();
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
