import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/security/encryption_service.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/providers/home_feed_provider.dart';
import '../../onboarding/family_chat/widgets/chat_bubble.dart';
import '../../onboarding/family_chat/models/chat_message.dart';
import '../../recommendation/engine/family_input.dart';
import '../models/family_member.dart';
import '../providers/family_members_provider.dart';
import '../services/family_service.dart';

/// Screen 5의 카드를 누르면 열리는 편집 화면.
///
/// 채팅 스타일 외형은 유지하되, 각 답변(유저 버블)을 탭하면 바텀시트로
/// 그 항목만 수정한다. 한 번에 한 답을 고치는 흐름이라 처음 온보딩보다
/// 가벼움.
class FamilyEditScreen extends ConsumerStatefulWidget {
  const FamilyEditScreen({required this.memberId, super.key});

  final String memberId;

  static const routeName = '/family/edit';
  static String pathFor(String id) => '$routeName/$id';

  @override
  ConsumerState<FamilyEditScreen> createState() => _FamilyEditScreenState();
}

class _FamilyEditScreenState extends ConsumerState<FamilyEditScreen> {
  FamilyInput? _input;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cipher =
        await SecureStorage.read(SecureStorage.familyDraftKey(widget.memberId));
    if (cipher == null) {
      setState(() => _error = AppStrings.familyEditNotFound);
      return;
    }
    try {
      final json = EncryptionService.instance.decryptJson(cipher);
      // 채팅 온보딩에서 들어온 나이대별 추가 필드(allergies/exercise/sleep
      // 등)도 보존하기 위해 FamilyMember.fromDraft를 통해 파싱한다.
      // 편집 화면은 기본 6개 필드만 노출하지만 나머지는 그대로 유지된다.
      final member = FamilyMember.fromDraft(id: widget.memberId, draft: json);
      setState(() => _input = member.input);
    } catch (_) {
      setState(() => _error = AppStrings.familyEditDecryptFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.familyEditTitle),
        actions: [
          TextButton(
            onPressed: input == null || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    AppStrings.save,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : input == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _row(
                      question: AppStrings.qName,
                      answer: input.name ?? '입력 필요',
                      onTap: () => _editName(),
                    ),
                    _row(
                      question: AppStrings.qAge,
                      answer: input.age == null ? '입력 필요' : '${input.age}세',
                      onTap: () => _editAge(),
                    ),
                    _row(
                      question: AppStrings.qSex,
                      answer: input.sex?.ko ?? '선택 필요',
                      onTap: () => _editSex(),
                    ),
                    _row(
                      question: AppStrings.qSmoker,
                      answer: input.smoker == null
                          ? '선택 필요'
                          : (input.smoker! ? AppStrings.yes : AppStrings.no),
                      onTap: () => _editSmoker(),
                    ),
                    _row(
                      question: AppStrings.qDrinker,
                      answer: input.drinker == null
                          ? '선택 필요'
                          : (input.drinker!
                              ? (input.drinkingFrequency?.ko ?? '음주')
                              : AppStrings.no),
                      onTap: () => _editDrinking(),
                    ),
                    _row(
                      question: AppStrings.qDiet,
                      answer: input.diet?.ko ?? '선택 필요',
                      onTap: () => _editDiet(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      AppStrings.familyEditTapHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtle,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _row({
    required String question,
    required String answer,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatBubble(
            message: ChatMessage(
              id: question.hashCode,
              author: ChatAuthor.bot,
              text: question,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      answer,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.edit,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _editName() async {
    final result = await _promptText(
      title: '이름',
      initial: _input?.name ?? '',
      hint: AppStrings.familyEditNameHint,
      maxLength: 20,
    );
    if (result == null) return;
    setState(() => _input = _input!.copyWith(name: result));
  }

  Future<void> _editAge() async {
    final result = await _promptText(
      title: '나이',
      initial: _input?.age?.toString() ?? '',
      hint: AppStrings.familyEditAgeHint,
      keyboardType: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
    );
    if (result == null) return;
    final age = int.tryParse(result);
    if (age == null || age < 1 || age > 120) {
      _toast(AppStrings.familyEditAgeError);
      return;
    }
    setState(() => _input = _input!.copyWith(age: age));
  }

  Future<void> _editSex() async {
    final result = await _promptChoice<Sex>(
      title: '성별',
      options: const [
        (Sex.male, AppStrings.choiceMale),
        (Sex.female, AppStrings.choiceFemale),
      ],
    );
    if (result == null) return;
    setState(() => _input = _input!.copyWith(sex: result));
  }

  Future<void> _editSmoker() async {
    final result = await _promptChoice<bool>(
      title: AppStrings.qSmoker,
      options: const [(true, AppStrings.yes), (false, AppStrings.no)],
    );
    if (result == null) return;
    setState(() => _input = _input!.copyWith(smoker: result));
  }

  Future<void> _editDrinking() async {
    final yesNo = await _promptChoice<bool>(
      title: AppStrings.qDrinker,
      options: const [(true, AppStrings.yes), (false, AppStrings.no)],
    );
    if (yesNo == null) return;
    if (!yesNo) {
      setState(() => _input = _input!.copyWith(drinker: false));
      return;
    }
    final freq = await _promptChoice<DrinkingFrequency>(
      title: AppStrings.qDrinkingFrequency,
      options: const [
        (DrinkingFrequency.monthly, AppStrings.choiceFreqMonthly),
        (DrinkingFrequency.weekly, AppStrings.choiceFreqWeekly),
        (DrinkingFrequency.frequent, AppStrings.choiceFreqFrequent),
      ],
    );
    if (freq == null) return;
    setState(() => _input = _input!.copyWith(
          drinker: true,
          drinkingFrequency: freq,
        ));
  }

  Future<void> _editDiet() async {
    final result = await _promptChoice<DietHabit>(
      title: AppStrings.qDiet,
      options: const [
        (DietHabit.meat, AppStrings.choiceDietMeat),
        (DietHabit.balanced, AppStrings.choiceDietBalanced),
        (DietHabit.vegetarian, AppStrings.choiceDietVegetarian),
      ],
    );
    if (result == null) return;
    setState(() => _input = _input!.copyWith(diet: result));
  }

  Future<String?> _promptText({
    required String title,
    required String initial,
    required String hint,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: keyboardType,
                inputFormatters: formatters,
                maxLength: maxLength,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: AppTheme.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    Navigator.of(sheetCtx).pop(controller.text.trim()),
                child: const Text(AppStrings.save),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Future<T?> _promptChoice<T>({
    required String title,
    required List<(T, String)> options,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(opt.$1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: AppTheme.line),
                          foregroundColor: AppTheme.ink,
                        ),
                        child: Text(
                          opt.$2,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    final input = _input;
    if (input == null) return;
    if (!input.isComplete) {
      _toast(AppStrings.familyEditFillAll);
      return;
    }
    setState(() => _saving = true);
    try {
      await FamilyService.updateMember(widget.memberId, input);
      ref.invalidate(familyMembersProvider);
      ref.invalidate(homeFeedProvider);
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
