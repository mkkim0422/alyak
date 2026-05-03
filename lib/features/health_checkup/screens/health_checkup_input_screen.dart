import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/providers/family_members_provider.dart';
import '../../family/services/family_service.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../notifications/providers/notification_settings_provider.dart';
import '../../recommendation/engine/health_checkup.dart';

/// 토스 스타일 챗 형태의 검진 결과 입력 화면.
///
/// 흐름:
///   1) 인트로: "결과지가 있으세요?" → 있어요 / 없어요
///   2) 날짜 선택
///   3) 항목별 숫자 입력 (각 항목마다 [건너뛰기] 버튼 + 정상 범위 힌트)
///   4) 모든 항목 끝나면 [✅ 입력 완료] → save → pop
///
/// 라우트: `/health-checkup/:memberId`
class HealthCheckupInputScreen extends ConsumerStatefulWidget {
  const HealthCheckupInputScreen({super.key, required this.memberId});

  final String memberId;

  static const routeName = '/health-checkup';
  static String pathFor(String id) => '/health-checkup/$id';

  @override
  ConsumerState<HealthCheckupInputScreen> createState() =>
      _HealthCheckupInputScreenState();
}

enum _Phase { intro, date, fields, done, declined }

class _HealthCheckupInputScreenState
    extends ConsumerState<HealthCheckupInputScreen> {
  _Phase _phase = _Phase.intro;

  DateTime? _date;
  // 항목별 입력 값 — null 이면 미입력 (건너뛰기 포함).
  double? _cholTotal;
  double? _cholLdl;
  double? _cholHdl;
  double? _bloodSugar;
  double? _hemoglobin;
  double? _alt;
  double? _ast;
  double? _vitaminD;
  double? _bpSystolic;
  double? _bpDiastolic;
  bool _saving = false;
  int _activeFieldIdx = 0;

  late final List<_FieldDef> _fields = [
    _FieldDef(
      label: AppStrings.checkupCholTotal,
      hint: AppStrings.checkupCholTotalHint,
      onSave: (v) => _cholTotal = v,
    ),
    _FieldDef(
      label: AppStrings.checkupCholLdl,
      hint: AppStrings.checkupCholLdlHint,
      onSave: (v) => _cholLdl = v,
    ),
    _FieldDef(
      label: AppStrings.checkupCholHdl,
      hint: AppStrings.checkupCholHdlHint,
      onSave: (v) => _cholHdl = v,
    ),
    _FieldDef(
      label: AppStrings.checkupBloodSugar,
      hint: AppStrings.checkupBloodSugarHint,
      onSave: (v) => _bloodSugar = v,
    ),
    _FieldDef(
      label: AppStrings.checkupHemoglobin,
      hint: AppStrings.checkupHemoglobinHint,
      decimal: true,
      onSave: (v) => _hemoglobin = v,
    ),
    _FieldDef(
      label: AppStrings.checkupAlt,
      hint: AppStrings.checkupAltHint,
      onSave: (v) => _alt = v,
    ),
    _FieldDef(
      label: AppStrings.checkupAst,
      hint: AppStrings.checkupAstHint,
      onSave: (v) => _ast = v,
    ),
    _FieldDef(
      label: AppStrings.checkupVitaminD,
      hint: AppStrings.checkupVitaminDHint,
      decimal: true,
      onSave: (v) => _vitaminD = v,
    ),
    _FieldDef(
      label: AppStrings.checkupBpSystolic,
      hint: AppStrings.checkupBpSystolicHint,
      onSave: (v) => _bpSystolic = v,
    ),
    _FieldDef(
      label: AppStrings.checkupBpDiastolic,
      hint: AppStrings.checkupBpDiastolicHint,
      onSave: (v) => _bpDiastolic = v,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.checkupTitle)),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: _buildPhase(),
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _Phase.intro:
        return _buildIntro();
      case _Phase.date:
        return _buildDate();
      case _Phase.fields:
        return _buildFields();
      case _Phase.done:
        return _buildSummary();
      case _Phase.declined:
        return _buildDeclined();
    }
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BotBubble(
          text: AppStrings.checkupBotIntro,
          subText: AppStrings.checkupBotIntroSub,
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _phase = _Phase.declined),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppTheme.line),
                  foregroundColor: AppTheme.subtle,
                ),
                child: const Text(AppStrings.checkupLater),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => setState(() => _phase = _Phase.date),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(AppStrings.checkupYes),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeclined() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        const Text(
          '검진 결과 없이도 추천을 받을 수 있어요.\n언제든 다시 입력하실 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.6, color: AppTheme.ink),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('닫기'),
          ),
        ),
      ],
    );
  }

  Widget _buildDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BotBubble(text: AppStrings.checkupBotDate),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.event, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _date == null
                      ? '날짜 선택'
                      : '${_date!.year}년 ${_date!.month}월 ${_date!.day}일',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _pickDate,
                child: const Text('선택'),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _date == null
                ? null
                : () => setState(() => _phase = _Phase.fields),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text(AppStrings.checkupNext),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BotBubble(text: AppStrings.checkupBotFields),
        const SizedBox(height: 8),
        // 진행도 (1/10).
        Row(
          children: [
            Text(
              '${_activeFieldIdx + 1} / ${_fields.length}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.subtle,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (_activeFieldIdx + 1) / _fields.length,
          minHeight: 3,
          backgroundColor: AppTheme.line,
          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _NumberFieldStep(
            key: ValueKey(_activeFieldIdx),
            def: _fields[_activeFieldIdx],
            onSubmit: (v) {
              _fields[_activeFieldIdx].onSave(v);
              _advanceField();
            },
            onSkip: _advanceField,
          ),
        ),
      ],
    );
  }

  void _advanceField() {
    if (_activeFieldIdx + 1 >= _fields.length) {
      setState(() => _phase = _Phase.done);
      return;
    }
    setState(() => _activeFieldIdx += 1);
  }

  Widget _buildSummary() {
    final filled = _filledCount();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.checkupDone,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_fields.length}개 항목 중 $filled개 입력',
                style: const TextStyle(fontSize: 13, color: AppTheme.subtle),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryRow(
                  label: AppStrings.checkupCholTotal,
                  value: _cholTotal,
                ),
                _SummaryRow(label: AppStrings.checkupCholLdl, value: _cholLdl),
                _SummaryRow(label: AppStrings.checkupCholHdl, value: _cholHdl),
                _SummaryRow(
                  label: AppStrings.checkupBloodSugar,
                  value: _bloodSugar,
                ),
                _SummaryRow(
                  label: AppStrings.checkupHemoglobin,
                  value: _hemoglobin,
                ),
                _SummaryRow(label: AppStrings.checkupAlt, value: _alt),
                _SummaryRow(label: AppStrings.checkupAst, value: _ast),
                _SummaryRow(
                  label: AppStrings.checkupVitaminD,
                  value: _vitaminD,
                ),
                _SummaryRow(
                  label: AppStrings.checkupBpSystolic,
                  value: _bpSystolic,
                ),
                _SummaryRow(
                  label: AppStrings.checkupBpDiastolic,
                  value: _bpDiastolic,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('저장'),
          ),
        ),
      ],
    );
  }

  int _filledCount() {
    var n = 0;
    for (final v in [
      _cholTotal,
      _cholLdl,
      _cholHdl,
      _bloodSugar,
      _hemoglobin,
      _alt,
      _ast,
      _vitaminD,
      _bpSystolic,
      _bpDiastolic,
    ]) {
      if (v != null) n++;
    }
    return n;
  }

  Future<void> _save() async {
    final date = _date;
    if (date == null) return;
    setState(() => _saving = true);
    try {
      final checkup = HealthCheckup(
        checkupDate: date,
        cholesterolTotal: _cholTotal,
        cholesterolLdl: _cholLdl,
        cholesterolHdl: _cholHdl,
        bloodSugar: _bloodSugar,
        hemoglobin: _hemoglobin,
        alt: _alt,
        ast: _ast,
        vitaminD: _vitaminD,
        bloodPressureSystolic: _bpSystolic,
        bloodPressureDiastolic: _bpDiastolic,
      );

      final membersAsync = ref.read(familyMembersProvider);
      final members = membersAsync.hasValue ? membersAsync.value : null;
      if (members != null) {
        final m = members.firstWhere(
          (x) => x.id == widget.memberId,
          orElse: () => members.first,
        );
        final updated = m.input.copyWith(lastCheckup: checkup);
        await FamilyService.updateMember(m.id, updated);

        // 검진 1년 뒤 재검 알림 — 기존 알림 취소 후 새로 예약 (덮어쓰기).
        // 설정에서 토글 OFF 면 예약 자체를 스킵 (취소만 한다).
        await NotificationService.cancelCheckupReminder(m.id);
        final notif = ref.read(notificationSettingsProvider);
        if (notif.checkupEnabled) {
          await NotificationService.scheduleCheckupReminder(
            memberId: m.id,
            lastCheckupDate: checkup.checkupDate,
          );
        }

        ref.invalidate(familyMembersProvider);
        ref.invalidate(homeFeedProvider);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.checkupSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _BotBubble extends StatelessWidget {
  const _BotBubble({required this.text, this.subText});
  final String text;
  final String? subText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (subText != null) ...[
            const SizedBox(height: 4),
            Text(
              subText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.subtle,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldDef {
  _FieldDef({
    required this.label,
    required this.hint,
    required this.onSave,
    this.decimal = false,
  });
  final String label;
  final String hint;
  final ValueChanged<double> onSave;
  final bool decimal;
}

class _NumberFieldStep extends StatefulWidget {
  const _NumberFieldStep({
    super.key,
    required this.def,
    required this.onSubmit,
    required this.onSkip,
  });

  final _FieldDef def;
  final ValueChanged<double> onSubmit;
  final VoidCallback onSkip;

  @override
  State<_NumberFieldStep> createState() => _NumberFieldStepState();
}

class _NumberFieldStepState extends State<_NumberFieldStep> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      widget.onSkip();
      return;
    }
    final v = double.tryParse(raw);
    if (v == null) return;
    widget.onSubmit(v);
  }

  @override
  Widget build(BuildContext context) {
    final formatters = widget.def.decimal
        ? <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ]
        : <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.def.label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.def.hint,
          style: const TextStyle(fontSize: 12, color: AppTheme.subtle),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: widget.def.decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          textInputAction: TextInputAction.send,
          inputFormatters: formatters,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.background,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primary,
                width: 2,
              ),
            ),
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onSkip,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppTheme.line),
                  foregroundColor: AppTheme.subtle,
                ),
                child: const Text(AppStrings.checkupSkip),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(AppStrings.checkupNext),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.subtle),
            ),
          ),
          Text(
            v == null
                ? '미입력'
                : (v == v.truncateToDouble()
                    ? v.toInt().toString()
                    : v.toStringAsFixed(1)),
            style: TextStyle(
              fontSize: 14,
              fontWeight: v == null ? FontWeight.w500 : FontWeight.w800,
              color: v == null ? AppTheme.subtle : AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}
