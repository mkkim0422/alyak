import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/nutrient_targets.dart';
import '../../../core/data/product_repository.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../notifications/providers/notification_settings_provider.dart';
import '../models/family_member.dart';
import '../providers/family_members_provider.dart';
import '../services/family_service.dart';

/// 큐레이션 DB / 식약처 / 네이버 검색 결과에 없는 영양제를 사용자가
/// 라벨을 보고 직접 추가하는 화면.
///
/// - 필수: 제품명, 카테고리, 1일 복용량, 한 통 사이즈
/// - 선택: 가격, 영양 성분 행 (성분명 + 수치 + 단위)
///
/// 영양 성분이 비어 있어도 등록은 가능하다 — 다만 부족 영양소 분석에는
/// 포함되지 않는다는 안내를 띄운다.
///
/// 저장 후 자동으로:
///   1) 멤버 input 의 `currentProductIds` 에 새 id 를 추가
///   2) 재구매 알림을 예약 (package_size / daily_dose 기준)
class ManualSupplementInputScreen extends ConsumerStatefulWidget {
  const ManualSupplementInputScreen({required this.memberId, super.key});

  final String memberId;

  static const routeName = '/supplement/manual-input';
  static String pathFor(String memberId) =>
      '$routeName?member_id=$memberId';

  @override
  ConsumerState<ManualSupplementInputScreen> createState() =>
      _ManualSupplementInputScreenState();
}

class _ManualSupplementInputScreenState
    extends ConsumerState<ManualSupplementInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _dailyDose = TextEditingController();
  final _packageSize = TextEditingController();
  final _price = TextEditingController();

  String _category = 'multivitamin';
  String _unit = '정';
  bool _saving = false;

  final List<_IngredientRow> _ingredients = [];

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _dailyDose.dispose();
    _packageSize.dispose();
    _price.dispose();
    for (final r in _ingredients) {
      r.dispose();
    }
    super.dispose();
  }

  static final List<MapEntry<String, String>> _categories = [
    ...productCategoryDisplayName.entries,
    const MapEntry('other', '기타'),
  ];

  static const _units = ['정', '캡슐', '포', 'ml', 'g'];

  /// 성분 입력 행이 가질 수 있는 영양소 키 — `nutrient_targets.dart` 의
  /// 키 명을 그대로 따른다 (분석 엔진이 동일 키로 합산).
  static const Map<String, String> _ingredientChoices = {
    'vitamin_a_mcg': '비타민A (mcg)',
    'vitamin_c_mg': '비타민C (mg)',
    'vitamin_d_iu': '비타민D (IU)',
    'vitamin_e_mg': '비타민E (mg)',
    'vitamin_k_mcg': '비타민K (mcg)',
    'vitamin_b1_mg': '비타민B1 (mg)',
    'vitamin_b2_mg': '비타민B2 (mg)',
    'vitamin_b3_mg': '비타민B3 (mg)',
    'vitamin_b5_mg': '비타민B5 (mg)',
    'vitamin_b6_mg': '비타민B6 (mg)',
    'vitamin_b7_mcg': '비오틴 (mcg)',
    'vitamin_b9_mcg': '엽산 (mcg)',
    'vitamin_b12_mcg': '비타민B12 (mcg)',
    'calcium_mg': '칼슘 (mg)',
    'magnesium_mg': '마그네슘 (mg)',
    'iron_mg': '철분 (mg)',
    'zinc_mg': '아연 (mg)',
    'omega3_total_mg': '오메가3 (mg)',
    'epa_mg': 'EPA (mg)',
    'dha_mg': 'DHA (mg)',
    'probiotics_cfu_billion': '유산균 (10억 CFU)',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('영양제 직접 추가'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            const _Hint(
              icon: '📋',
              text: '제품 라벨을 보고 입력해 주세요. 성분이 비어 있어도 등록은 가능하지만, '
                  '그 경우 부족 영양소 분석에는 포함되지 않아요.',
            ),
            const SizedBox(height: 16),
            _label('제품명 *'),
            _textField(
              _name,
              hint: '예: 우리집 종합비타민',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '제품명을 입력해 주세요' : null,
            ),
            const SizedBox(height: 12),
            _label('브랜드 / 제조사'),
            _textField(_brand, hint: '예: 한국제약 (선택)'),
            const SizedBox(height: 12),
            _label('카테고리 *'),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: _decoration(),
              items: [
                for (final e in _categories)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 12),
            _label('1일 복용량 *'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _textField(
                    _dailyDose,
                    hint: '1',
                    keyboard: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _positiveIntValidator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _unitDropdown()),
              ],
            ),
            const SizedBox(height: 12),
            _label('한 통 사이즈 *'),
            _textField(
              _packageSize,
              hint: '60',
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _positiveIntValidator,
            ),
            const SizedBox(height: 12),
            _label('가격 (선택)'),
            _textField(
              _price,
              hint: '한 통 가격 (원)',
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: AppTheme.line),
            const SizedBox(height: 16),
            const Text(
              '영양 성분 (선택)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '라벨에 표시된 성분을 추가하면 부족 영양소 분석이 가능해요. '
              '비워 두면 분석에서 제외돼요.',
              style: TextStyle(fontSize: 12, color: AppTheme.subtle, height: 1.4),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _ingredients.length; i++)
              _IngredientRowWidget(
                key: ValueKey(_ingredients[i].uniqueKey),
                row: _ingredients[i],
                choices: _ingredientChoices,
                onRemove: () => setState(() {
                  _ingredients[i].dispose();
                  _ingredients.removeAt(i);
                }),
                onChanged: () => setState(() {}),
              ),
            OutlinedButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('성분 추가'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: const BorderSide(color: AppTheme.line),
                foregroundColor: AppTheme.ink,
              ),
            ),
            if (_ingredients.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '성분을 입력하지 않으면 부족 영양소 분석이 부정확해요',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppTheme.line),
                    foregroundColor: AppTheme.ink,
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
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
                      : const Text(
                          '추가하기',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
      );

  Widget _textField(
    TextEditingController c, {
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator: validator,
      decoration: _decoration(hint: hint),
    );
  }

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppTheme.cream,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
    );
  }

  Widget _unitDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _unit,
      decoration: _decoration(),
      items: [
        for (final u in _units)
          DropdownMenuItem(value: u, child: Text(u)),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _unit = v);
      },
    );
  }

  String? _positiveIntValidator(String? v) {
    if (v == null || v.trim().isEmpty) return '입력해 주세요';
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) return '1 이상의 숫자를 입력해 주세요';
    return null;
  }

  void _addIngredient() {
    setState(() => _ingredients.add(_IngredientRow()));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dailyDose = int.tryParse(_dailyDose.text.trim()) ?? 0;
    final packageSize = int.tryParse(_packageSize.text.trim()) ?? 0;
    final priceTotal = int.tryParse(_price.text.trim()) ?? 0;
    final ingredients = <String, double>{};
    for (final row in _ingredients) {
      final key = row.key;
      final amount = double.tryParse(row.amount.text.trim());
      if (key != null && amount != null && amount > 0) {
        ingredients[key] = amount;
      }
    }

    final id = _generateManualId();
    final entry = Product(
      id: id,
      name: _name.text.trim(),
      brandType: 'brand',
      category: _category,
      pricePerUnitKrw: dailyDose > 0 ? (priceTotal ~/ packageSize) : 0,
      unit: _unit,
      dailyDose: dailyDose,
      packageSize: packageSize,
      packagePriceKrw: priceTotal,
      ingredients: ingredients,
      goodFor: const [],
      alternatives: const [],
      notes: _brand.text.trim().isEmpty ? '' : '제조사: ${_brand.text.trim()}',
      isManual: true,
    );

    setState(() => _saving = true);
    try {
      final repoAsync = ref.read(productRepositoryProvider);
      final repo = repoAsync.hasValue ? repoAsync.requireValue : null;
      if (repo == null) {
        _toast('잠시 후 다시 시도해 주세요');
        return;
      }
      await repo.addUserEntry(entry);

      // 멤버의 currentProductIds 에 추가.
      final membersAsync = ref.read(familyMembersProvider);
      final members = membersAsync.hasValue ? membersAsync.value : null;
      FamilyMember? member;
      if (members != null) {
        for (final m in members) {
          if (m.id == widget.memberId) {
            member = m;
            break;
          }
        }
      }
      if (member != null) {
        final ids = [...(member.input.currentProductIds ?? const <String>[])];
        if (!ids.contains(id)) ids.add(id);
        final supplements = <String>{
          ...(member.input.currentSupplements ?? const <String>[]),
        };
        final mapped = productCategorySupplementName[_category];
        if (mapped != null) supplements.add(mapped);
        final updated = member.input.copyWith(
          currentProductIds: ids,
          currentSupplements: supplements.toList(),
        );
        await FamilyService.updateMember(member.id, updated);

        // 재구매 알림 자동 예약 (성분 무관, 통 사이즈만 있으면 가능).
        // 사용자가 설정에서 끄면 예약 자체를 스킵.
        await SecureStorage.write(
          'started.${member.id}.$id',
          DateTime.now().toIso8601String(),
        );
        final notif = ref.read(notificationSettingsProvider);
        if (notif.reorderEnabled) {
          await NotificationService.scheduleProductReorderReminder(
            memberId: member.id,
            productId: id,
            productName: entry.name,
            startedDate: DateTime.now(),
            packageSize: packageSize,
            dailyDose: dailyDose,
            daysBefore: notif.reorderDaysBefore,
          );
        }
      }

      ref.invalidate(productRepositoryProvider);
      ref.invalidate(familyMembersProvider);
      ref.invalidate(homeFeedProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('영양제를 추가했어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  static String _generateManualId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'manual_${ts}_$rand';
  }
}

/// 입력 폼에서 한 줄에 대응하는 임시 상태. dispose 책임은 부모 화면에 있다.
class _IngredientRow {
  _IngredientRow();
  final amount = TextEditingController();
  String? key;
  final int uniqueKey =
      DateTime.now().microsecondsSinceEpoch ^
          Random().nextInt(1 << 30);

  void dispose() => amount.dispose();
}

class _IngredientRowWidget extends StatelessWidget {
  const _IngredientRowWidget({
    required this.row,
    required this.choices,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final _IngredientRow row;
  final Map<String, String> choices;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<String>(
              initialValue: row.key,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: '성분 선택',
                filled: true,
                fillColor: AppTheme.cream,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                for (final e in choices.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                row.key = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                hintText: '수치',
                filled: true,
                fillColor: AppTheme.cream,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18, color: AppTheme.subtle),
            tooltip: '삭제',
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
