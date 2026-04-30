/// 앱 전체에서 사용하는 한국어 UI 문자열 단일 소스. 향후 다국어를 붙일 때
/// 이 파일만 교체하거나, 같은 키 구조를 가진 영문 / 일문 클래스를 추가하면
/// 된다. 현 단계는 i18n "준비"이므로 모든 값은 한국어로 둔다.
///
/// 원칙:
/// - 사용자에게 보이는 모든 한국어 리터럴은 여기에 둔다.
/// - 동적 값을 끼워야 하는 문자열은 `String Function(...)` 헬퍼로 노출.
/// - 데이터(JSON 자산), 백엔드 prompt, 디버그 로그는 대상이 아니다.
class AppStrings {
  AppStrings._();

  // ───────────────────────────────────────────────────────────── App / 공통
  static const String appName = '알약';
  static const String yes = '예';
  static const String no = '아니오';
  static const String cancel = '취소';
  static const String save = '저장';
  static const String delete = '삭제';
  static const String checkingVersion = '확인 중';

  // ───────────────────────────────────────────────────────────── Disclaimer
  static const String homeDisclaimer =
      '※ 본 앱은 의사·약사의 전문 진단을 대체하지 않습니다.';
  static const String previewDisclaimer = '※ 의사·약사 진단을 대체하지 않습니다.';
  static const String guideDisclaimerFallback =
      '이 정보는 건강기능식품 정보이며 의료적 진단을 대체하지 않아요.';
  static const String recommendationDisclaimer =
      '본 추천은 일반 정보 제공이며 진단·처방을 대체하지 않습니다. '
      '만성 질환이나 약물 복용 중이라면 반드시 의사·약사와 상담해 주세요.';

  // ───────────────────────────────────────────────────────────── 홈 화면
  static const String homeTitle = '알약';
  static const String homeGreeting = '안녕하세요 👋';
  static const String homeMenuFamily = '가족 관리';
  static const String homeMenuFamilyAdd = '가족 추가';
  static const String homeMenuSettings = '설정';
  static const String homeStatusReady = '🟢 오늘 추천 있음';
  static const String homeStatusNeedSetup = '⚪ 설정 필요';
  static const String homeSlotMorning = '아침';
  static const String homeSlotEvening = '저녁';
  static const String homeSlotMorningEmoji = '☀️';
  static const String homeSlotEveningEmoji = '🌙';
  static const String homeNoRecommendations =
      '아직 추천할 영양제가 없어요. 가족 정보를 더 입력해 주세요.';
  static const String homeAddSymptom = '증상 추가하기';
  static const String homeViewAll = '전체 보기 →';
  static const String homeAlreadyTaken = '먹었어요 👍';
  static const String homeAllDone = '✅ 완료';
  static const String homeEmptyHeading = '아직 등록된 가족이 없어요.';
  static const String homeEmptyBody = '가족을 추가하면 맞춤 추천을 받을 수 있어요.';
  static const String homeAddFamily = '가족 추가하기';
  static const String homeLoadFailed =
      '가족 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';

  // 동적 — 카운트 칩.
  static String homeSlotCount(String label, int count) => '$label $count';

  /// 1인칭 이름("나"/"저")이면 그대로, 그 외엔 "○○님" 호칭으로.
  /// 어색한 "나님 오늘 영양제" 같은 합성을 막기 위해 동적 helper 들이 공유.
  static bool _isFirstPerson(String name) {
    final n = name.trim();
    return n == '나' || n == '저';
  }

  /// "○○님 오늘 영양제" 메인 카드 헤더.
  /// 본인("나"/"저")이면 "오늘 내 영양제" 로 자연스럽게 바꿔 준다.
  static String homeMemberDailyHeader(String name) {
    if (_isFirstPerson(name)) return '오늘 내 영양제';
    return '$name님 오늘 영양제';
  }

  /// 한국어 요일 (월~일).
  static const List<String> _weekdayKo = ['월', '화', '수', '목', '금', '토', '일'];

  /// "4월 26일 토요일" 형태의 한국어 짧은 날짜.
  static String homeTodayDateLong(DateTime now) {
    final wd = _weekdayKo[(now.weekday - 1).clamp(0, 6)];
    return '${now.month}월 ${now.day}일 $wd요일';
  }

  // ───────────────────────────────────────────────────────────── 가족 관리
  static const String familyTitle = '가족 관리';
  static const String familyAdd = '가족 추가';
  static const String familyAddBtn = '가족 추가하기';
  static const String familyDeleteTitle = '가족 삭제';
  static const String familyDeleteSwipe = '삭제';
  static const String familySelfBadge = '본인';
  static const String familyTooltipAddSymptom = '증상 추가';
  static const String familyTooltipShowRec = '추천 보기';
  static const String familyEmptyHeading = '등록된 가족이 없어요.';
  static const String familyEmptyBody = '하단 가족 추가 버튼으로 시작해 보세요.';
  static const String familyLoadFailed = '가족 정보를 불러오지 못했어요.';
  static String familyDeleteConfirm(String name) =>
      '$name 정보를 삭제하시겠어요?\n저장된 모든 정보가 삭제됩니다.';

  // ───────────────────────────────────────────────────────────── 가족 정보 수정
  static const String familyEditTitle = '가족 정보 수정';
  static const String familyEditNotFound = '가족 정보를 찾을 수 없어요.';
  static const String familyEditDecryptFailed = '복호화에 실패했어요.';
  static const String familyEditTapHint = '항목을 탭하면 그 항목만 다시 입력해요.';
  static const String familyEditNameHint = '예) 엄마, 우리딸';
  static const String familyEditAgeHint = '나이를 숫자로';
  static const String familyEditAgeError = '1부터 120 사이의 숫자로 입력해 주세요.';
  static const String familyEditFillAll = '모든 항목을 채워 주세요.';

  // ───────────────────────────────────────────────────────────── 추천 상세
  static const String recommendationTitle = '추천 영양제';
  static const String recommendationLoadFailed = '추천 정보를 불러오지 못했어요.';
  static const String recommendationSectionMustTake = '꼭 챙기세요 ⭐';
  static const String recommendationSectionHighly = '적극 추천 👍';
  static const String recommendationSectionConsider = '이런 분께 추가로 ➕';
  static const String recommendationSectionSynergy = '함께 드시면 좋아요 💚';
  static const String recommendationSectionConflicts = '주의해 주세요 ⚠️';
  static const String recommendationEmpty =
      '추천할 영양제를 찾지 못했어요. 가족 정보를 다시 확인해 주세요.';
  static const String recommendationOrdered = '주문했어요';
  static const String recommendationOrderSnack =
      '주문 일자를 기록했어요. 25일 뒤 재주문 알림을 보내드릴게요 💊';

  static const String ageLabelNewborn = '영아';
  static const String ageLabelToddler = '유아';
  static const String ageLabelChild = '어린이';
  static const String ageLabelTeen = '청소년';
  static const String ageLabelAdult = '성인';
  static const String ageLabelElderly = '노인';

  static String recommendationHeader(String name) {
    if (_isFirstPerson(name)) return '내 맞춤 추천';
    return '$name님 맞춤 추천';
  }
  static String recommendationSubHeader(String ageLabel, int age) =>
      '$ageLabel · $age세';
  static String reorderLastDate(int year, int month, int day) =>
      '마지막 주문 $year.${month.toString().padLeft(2, '0')}.${day.toString().padLeft(2, '0')}';

  // ───────────────────────────────────────────────────────────── 영양제 가이드
  static const String guideLoadFailed = '가이드를 불러오지 못했어요.';
  static const String guideNotFound = '해당 영양제 정보를 찾지 못했어요.';
  static const String guideTitleFallback = '복용 가이드';
  static const String guideExpand = '자세히 보기 ↓';
  static const String guideCollapse = '간단히 보기 ↑';
  static const String guideSummaryWhen = '언제';
  static const String guideSummaryAmount = '얼마나';
  static const String guideSummaryCaution = '핵심 주의';
  static const String guideTimingAnytime = '아무때나';
  static const String guideDosageMissing = '권장량 정보가 아직 없어요';
  static const String guideTimeMorning = '아침';
  static const String guideTimeNoon = '낮';
  static const String guideTimeLunch = '점심';
  static const String guideTimeEvening = '저녁';
  static const String guideTimeBeforeSleep = '취침 전';
  static const String guideSectionEffects = '💡 주요 효과';
  static const String guideSectionWhen = '⏰ 언제 드세요?';
  static const String guideSectionDosage = '⚖️ 얼마나 드세요?';
  static const String guideSectionGoodCombo = '💚 같이 드시면 좋아요';
  static const String guideSectionCautions = '⚠️ 주의하세요';
  static const String guideSectionFood = '🥗 음식으로도 드실 수 있어요';
  static const String guideSectionEffectTime = '⏳ 효과는 언제부터?';
  static const String guideShowOtherAges = '다른 나이대 보기 +';
  static const String guideHideOtherAges = '다른 나이대 숨기기';
  static const String guideAgeAdult = '성인';
  static const String guideAgeChild = '어린이 (7~12세)';
  static const String guideAgeTeen = '청소년 (13~18세)';
  static const String guideAgeElderly = '노인 (60세 이상)';
  static const String guideAgeInfantToddler = '영유아 (0~6세)';

  static String guideTitleFor(String supplementName, String memberName) {
    if (_isFirstPerson(memberName)) return '$supplementName — 내 복용법';
    return '$supplementName — $memberName님 복용법';
  }
  static String guideCautionWith(String supplementName) =>
      '$supplementName 와(과) 복용 시 주의가 필요해요';

  // ───────────────────────────────────────────────────────────── 웰컴 (Toss-style)
  static const String welcomeMsg1 = '우리 가족의 건강을 위해 💚';
  static const String welcomeMsg2 = '가장 중요한 분을 먼저 등록해요';
  static const String welcomeMsg3 = '바로 이 앱을 설치한 당신이에요 😊';
  static const String welcomeCtaSelf = '나부터 등록할게요';
  static const String welcomeCtaFamily = '가족 먼저 등록할게요';

  // ───────────────────────────────────────────────────────────── 가족 선택
  static const String familySelectQuestion = '누구를 먼저 등록할까요? 👨‍👩‍👧';
  static const String familySelectDone = '완료';
  static const String relationSpouse = '배우자';
  static const String relationSon = '아들';
  static const String relationDaughter = '딸';
  static const String relationMom = '엄마';
  static const String relationDad = '아빠';
  static const String relationOther = '다른 소중한 사람';
  static const String relationSpouseEmoji = '👫';
  static const String relationSonEmoji = '👦';
  static const String relationDaughterEmoji = '👧';
  static const String relationMomEmoji = '👩';
  static const String relationDadEmoji = '👨';
  static const String relationOtherEmoji = '💝';

  // ───────────────────────────────────────────────────────────── 등록 완료 (chat-style)
  static const String completionOwnMsg1 = '등록 완료예요 🎉';
  static const String completionOwnMsg2 = '이제 가족도 함께 관리할까요?';
  static const String completionOwnYes = '네, 가족 등록할게요 →';
  static const String completionOwnLater = '나중에 할게요 →';
  static const String completionFamilyMsg = '등록 완료예요 💚';
  static const String completionFamilyMore = '다른 가족도 등록할게요 →';
  static const String completionFamilyDone = '이제 시작할게요 →';

  // 본인 프로필 모드용 이름 hint (own 모드 전용 override).
  static const String ownNameHint = '예: 나, 엄마, 또는 나만의 별명';

  // ───────────────────────────────────────────────────────────── 온보딩 (가족 추가)
  static const String onboardingTitle = '가족 추가';
  static const String onboardingLoadFailed =
      '추천 데이터를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
  static const String onboardingSubmit = '추가 완료';
  static const String onboardingNameHint = '예: 술고래남편, 우리귀요미, 막내딸 🥰';
  // 이름 입력칸 아래 작은 회색 보조 안내.
  static const String nameSubHint = '나중에 바꿀 수 있어요';
  static const String onboardingAgeHint = '나이를 숫자로';
  static const String onboardingTooLongName =
      '이름이 너무 길어요. 20자 이하로 다시 입력해 주세요.';
  static const String onboardingAgeRange = '1부터 120 사이의 숫자로 다시 알려주세요.';

  // 채팅 봇 질문.
  static const String qName = '이분을 어떻게 부르세요? 😊';
  // 일반 가족 추가 모드에서 봇 메시지 아래 작은 회색 안내.
  static const String qNameSubText = '이름, 별명, 뭐든 괜찮아요';
  // 본인 등록 첫 질문 (own 모드 전용). 본인은 sub-text 생략.
  static const String qNameOwn = '이름이나 별명을 알려주세요 😊';
  static const String qAge = '나이가 어떻게 되세요?\n(숫자만 입력해 주세요)';
  static const String qSex = '성별을 알려주세요.';
  static const String qSmoker = '담배를 피우시나요?';
  static const String qSmokingAmount = '하루에 담배를 얼마나 피우세요?';
  static const String qDrinker = '술을 드시나요?';
  static const String qDrinkingType = '주로 어떤 술을 드세요?';
  static const String qDrinkingFrequency = '얼마나 자주 드세요?';
  static const String qDiet = '식습관은 어떤가요?';
  static const String qAllergies = '알레르기가 있나요?';
  static const String qFeeding = '주로 어떻게 먹고 있나요?';
  static const String qPickyEating = '편식이 있나요?';
  static const String qExercise = '운동은 얼마나 하시나요?';
  static const String qSleep = '수면 시간은 어느 정도인가요?';
  static const String qStress = '평소 스트레스 정도는 어떤가요?';
  static const String qDigestive = '소화 문제가 있으신가요?';
  static const String qMedications = '현재 복용 중인 약이 있으신가요?';
  static const String qDone = '다 됐어요! 아래에서 추천을 확인하고 등록해 주세요.';

  // 현재 복용 중인 영양제 — 추천 정확도 개선용 마지막 옵션 단계.
  static const String qCurrentSupplements = '지금 드시는 영양제가 있으세요? 💊';
  static const String qCurrentSupplementsSub = '있으면 추천이 더 정확해져요';
  static const String qCurrentSupplementsPick =
      '어떤 영양제를 드시고 계세요?\n검색해서 선택해 주세요';
  static const String currentSupplementsHasYes = '있어요';
  static const String currentSupplementsHasNo = '없어요 / 나중에';
  static const String currentSupplementsSearchHint =
      '예: 오메가3, 종합비타민, 마그네슘';
  static const String currentSupplementsDone = '완료';
  static const String currentSupplementsAnswerNone = '없음';

  // 제품 picker (products.json 기반)
  static const String productPickerTitle = '드시는 제품 선택';
  static const String productPickerSearchHint = '제품명 검색';
  static const String productPickerEmpty = '카테고리를 선택해 주세요';
  static String productCardPackage(int size, String unit, int priceKrw) =>
      '$size$unit / ${_krw(priceKrw)}';
  static String productCardDaily(int dose, String unit, int dailyKrw) =>
      '1일 복용: $dose$unit (약 ${_krw(dailyKrw)})';
  static String productCardDailyNoCost(int dose, String unit) =>
      '1일 복용: $dose$unit';

  static String _krw(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()}원';
  }

  /// 화폐 표시. 외부에서도 사용할 수 있게 노출.
  static String krw(int v) => _krw(v);

  // ───────────────────────────────────────────────────────────── 검진 결과 입력
  static const String checkupTitle = '검진 결과 입력';
  static const String checkupBotIntro = '건강검진 결과지가 있으세요? 📋';
  static const String checkupBotIntroSub = '최근 1년 이내 결과를 입력하면 추천이 훨씬 정확해져요';
  static const String checkupYes = '있어요';
  static const String checkupLater = '없어요 / 다음에';
  static const String checkupBotDate = '검진 받으신 날짜를 알려주세요';
  static const String checkupBotFields = '결과지 보면서 입력해주세요. 모르는 건 건너뛰어도 돼요 😊';
  static const String checkupSkip = '건너뛰기';
  static const String checkupNext = '다음';
  static const String checkupDone = '✅ 입력 완료';
  static const String checkupSaved = '검진 결과가 저장됐어요';
  static const String checkupOpen = '검진 결과 입력 →';
  static const String checkupOpenDone = '검진 결과 다시 입력 →';
  static String checkupLastDate(int year, int month, int day) =>
      '최근 검진: $year년 $month월 $day일';

  // 검진 항목별 라벨 + 정상 범위 힌트.
  static const String checkupCholTotal = '총콜레스테롤';
  static const String checkupCholTotalHint = '정상 범위: 200 이하 (mg/dL)';
  static const String checkupCholLdl = 'LDL 콜레스테롤';
  static const String checkupCholLdlHint = '정상 범위: 130 이하 (mg/dL)';
  static const String checkupCholHdl = 'HDL 콜레스테롤';
  static const String checkupCholHdlHint = '정상 범위: 40 이상 (mg/dL)';
  static const String checkupBloodSugar = '공복혈당';
  static const String checkupBloodSugarHint = '정상 범위: 100 이하 (mg/dL)';
  static const String checkupHemoglobin = '헤모글로빈';
  static const String checkupHemoglobinHint =
      '정상: 남 13 이상 / 여 12 이상 (g/dL)';
  static const String checkupAlt = '간수치 ALT';
  static const String checkupAltHint = '정상 범위: 40 이하 (U/L)';
  static const String checkupAst = '간수치 AST';
  static const String checkupAstHint = '정상 범위: 40 이하 (U/L)';
  static const String checkupVitaminD = '비타민D 수치';
  static const String checkupVitaminDHint = '정상 범위: 30 이상 (ng/mL)';
  static const String checkupBpSystolic = '혈압 (수축기)';
  static const String checkupBpSystolicHint = '정상 범위: 120 미만 (mmHg)';
  static const String checkupBpDiastolic = '혈압 (이완기)';
  static const String checkupBpDiastolicHint = '정상 범위: 80 미만 (mmHg)';

  // ───────────────────────────────────────────────────────────── 아이 상세 입력
  static const String qChildHeightWeight = '아이 키와 몸무게 알려주세요 📏';
  static const String qChildHeightWeightSub = '성장 추적에 도움돼요';
  static const String childHeightHint = '키 (cm)';
  static const String childWeightHint = '몸무게 (kg)';

  static const String qStool = '아이 변은 어떤 편이에요? 💩';
  static const String qStoolSub = '건강 상태 파악에 도움돼요';
  static const String qStoolFreq = '얼마나 자주 보나요?';
  static const String qStoolForm = '변 형태는 어떤가요?';
  static const String stoolDaily = '매일 보내요';
  static const String stoolTwoToThree = '2-3일에 한 번';
  static const String stoolWeekly = '일주일에 한 번';
  static const String stoolLess = '거의 못 봐요';
  static const String stoolHard = '딱딱해요 (변비)';
  static const String stoolNormal = '보통이에요';
  static const String stoolSoft = '무른 편이에요';
  static const String stoolWatery = '설사 같아요';

  static const String qAllergyItems = '알레르기 있는 음식이 있나요?';
  static const String qAllergyItemsSub = '해당하는 것 모두 골라 주세요';
  static const String allergyMilk = '우유';
  static const String allergyEgg = '계란';
  static const String allergyNuts = '견과류';
  static const String allergyWheat = '밀';
  static const String allergyShrimp = '새우';
  static const String allergyFish = '생선';
  static const String allergySoy = '콩';
  static const String allergyNone = '없어요';

  static const String qEatsVegetables = '채소를 잘 먹나요?';
  static const String qEatsFish = '생선을 먹나요?';

  // 추천 상세 - 제품 추천 섹션
  static const String productSectionTitle = '💊 이런 제품 어떠세요?';
  static String productRank(int rank) => '$rank순위';
  static const String productAlternativesButton = '같은 성분 다른 제품 보기 →';
  static const String productAlternativesSheetTitle = '같은 성분 다른 제품';
  static const String productEmptyEnough = '💚 현재 복용 중인 영양제로 충분해요!';
  static const String productEmptyEnoughSub = '추가 보충은 필요 없어 보여요';
  static const String productMissingDataTitle = '💡 현재 복용 영양제를 입력하면';
  static const String productMissingDataSub =
      '더 정확한 제품 추천을 받을 수 있어요';
  static const String productMissingDataAction = '지금 입력하기 →';
  /// 추천 결과 화면에서 "이미 드시는 것" 섹션 헤더.
  static const String recommendationSectionAlreadyTaking = '이미 드시는 것 ✅';

  // ───────────────────────────────────────────────────────────── 홈 - 아바타 상태 라벨
  static const String avatarStatusDone = '완료';
  static const String avatarStatusInProgress = '진행중';

  // ───────────────────────────────────────────────────────────── 홈 - 추천 정확도 pill
  static String accuracyPill(int pct) => '추천 정확도 $pct%';
  static const String accuracySheetTitle = '프로필 보충하기';
  static const String accuracySheetDone = '모두 채웠어요! 정확한 추천을 드릴게요 💚';

  // ───────────────────────────────────────────────────────────── 추천 상세 - 제품 검색
  static String searchProductFor(String dosage) =>
      dosage.isEmpty ? '제품 찾기 🔍' : '$dosage 기준 제품 찾기 🔍';

  // 선택지 라벨.
  static const String choiceMale = '남성';
  static const String choiceFemale = '여성';
  static const String choiceSmokeLight = '5개비 이하';
  static const String choiceSmokeModerate = '6-10개비';
  static const String choiceSmokeHeavy = '11-20개비';
  static const String choiceSmokeVeryHeavy = '20개비 이상';
  static const String choiceDrinkSoju = '소주';
  static const String choiceDrinkBeer = '맥주';
  static const String choiceDrinkWine = '와인';
  static const String choiceDrinkLiquor = '양주';
  static const String choiceDrinkMixed = '혼합';
  static const String choiceFreqMonthly = '월 1-2회';
  static const String choiceFreqWeekly = '주 1-2회';
  static const String choiceFreqFrequent = '주 3회 이상';
  static const String choiceDietMeat = '육류 위주';
  static const String choiceDietBalanced = '균형 잡힘';
  static const String choiceDietVegetarian = '채식 위주';
  static const String choiceFeedingBreast = '모유';
  static const String choiceFeedingFormula = '분유';
  static const String choiceFeedingSolid = '이유식';
  static const String choiceLevelNone = '안 함';
  static const String choiceLevelSometimes = '가끔';
  static const String choiceLevelOften = '자주';
  static const String choiceSleepLess = '6시간 이하';
  static const String choiceSleep78 = '7-8시간';
  static const String choiceSleep9 = '9시간 이상';
  static const String choiceStressLow = '낮음';
  static const String choiceStressMedium = '보통';
  static const String choiceStressHigh = '높음';

  // 채팅 라이브 프리뷰.
  static const String livePreviewEmpty = '답변하실수록 맞춤 추천이 여기에 보여요.';
  static const String livePreviewTitle = '맞춤 추천 미리보기';

  // ───────────────────────────────────────────────────────────── 증상 검색
  static const String symptomTitle = '증상 질문';
  static const String symptomLoadFailed = '증상 데이터를 불러오지 못했어요.';
  static const String symptomCommon = '자주 묻는 증상';
  static const String symptomNoMember = '먼저 가족을 등록하면 증상을 추천에 반영할 수 있어요.';
  static const String symptomSearchHint = '어떤 증상이 있으세요?';
  static const String symptomMedicalFallback =
      '이 증상은 영양제보다 의료 전문가 진단이 우선이에요.';
  static const String symptomNotFoundTip =
      '증상이 2주 이상 지속되면 의료기관 방문을 권장해요. 일반적인 가이드는 추천 영양제 화면을 확인해 주세요.';
  static const String symptomSectionRelated = '관련 영양제';
  static const String symptomSectionTips = '생활 속 팁';
  static const String symptomBadgePrimary = '주요';
  static const String symptomBadgeSecondary = '보조';

  static String symptomNotFound(String query) =>
      '"$query"에 정확히 맞는 증상을 찾지 못했어요.';
  static String symptomMedicalWarning(String label) =>
      '"$label"은(는) 병원에서 확인하시는 게 좋아요';
  static String symptomReflectedFor(String name) {
    if (_isFirstPerson(name)) return '내 추천에 반영됨';
    return '$name님 추천에 반영됨';
  }

  static String symptomReflectFor(String name) {
    if (_isFirstPerson(name)) return '내 추천에 반영하기';
    return '$name님 추천에 반영하기';
  }

  // ───────────────────────────────────────────────────────────── 설정
  static const String settingsTitle = '설정';
  static const String settingsSectionNotifications = '알림';
  static const String settingsSectionFamily = '가족';
  static const String settingsSectionAccount = '계정';
  static const String settingsSectionAdmin = '관리자';
  static const String settingsSectionInfo = '정보';
  static const String settingsTileNotifTime = '알림 시간';
  static const String settingsTileFamilyManage = '가족 관리';
  static const String settingsTileFamilyManageSub = '추가/수정/삭제';
  static const String settingsTileLogin = '로그인 정보';
  static const String settingsTileGoogleLogin = 'Google로 로그인';
  static const String settingsTileGoogleLoginSub = '연결 준비 중이에요';
  static const String settingsTileGoogleSoon = 'Google 로그인은 곧 만들어요.';
  static const String settingsTileLogout = '로그아웃';
  static const String settingsTileDeleteAll = '계정 및 데이터 삭제';
  static const String settingsTileAdmin = '관리자 패널';
  static const String settingsTilePrivacy = '개인정보처리방침';
  static const String settingsLogoutDialogTitle = '로그아웃';
  static const String settingsLogoutDialogBody =
      '저장된 가족 정보는 기기에서 모두 삭제되고 처음부터 시작합니다. 계속할까요?';
  static const String settingsDeleteDialogTitle = '계정 및 데이터 삭제';
  static const String settingsDeleteDialogBody =
      '모든 가족 정보, 체크인, 추천 캐시, 알림 설정이 영구 삭제됩니다. 되돌릴 수 없어요. 정말 삭제할까요?';
  static const String settingsNotifOff = '알림 없음';
  static String settingsNotifOn(String morningHm, String eveningHm) =>
      '아침 $morningHm / 저녁 $eveningHm';

  // ───────────────────────────────────────────────────────────── 알림 설정 (가족 통합)
  static const String notifSettingsTitleOnboarding = '알림 설정';
  static const String notifSettingsTitleSettings = '알림 설정';
  static const String notifSettingsHeading = '언제 챙겨드릴까요?';
  static const String notifSettingsSub = '가족 전체에 알림 한 번씩만 가요. 나중에 바꿀 수 있어요.';
  static const String notifSettingsToggleLabel = '알림 받기';
  static const String notifQEarliest = '가족 중 가장 이른 출발 시간이 언제예요?';
  static const String notifQEarliestSub = '30분 전에 알림 드릴게요';
  static const String notifQEvening = '저녁 알림은 몇 시가 좋으세요?';
  static const String notifSettingsTimeEarliest = '☀️ 출발 시간';
  static const String notifSettingsTimeEvening = '🌙 저녁 알림';
  static const String notifSettingsCtaStart = '시작하기';
  static const String notifSettingsCtaSave = '저장';
  static const String notifSettingsDenied =
      '알림 권한이 거부됐어요. 나중에 설정에서 변경할 수 있어요.';

  // ───────────────────────────────────────────────────────────── 로컬 알림 본문 (가족 통합)
  static const String notifChannelName = '하루 영양제 알림';
  static const String notifChannelDesc = '아침/저녁 가족 영양제 알림';
  static const String notifFamilyMorningTitle = '💊 가족 영양제 챙길 시간이에요!';
  /// 아침 알림 본문. 등록된 가족 이름들을 받아 한 줄로 엮어 준다.
  /// 빈 리스트면 "오늘 가족 분량 준비해주세요" 같은 안전한 fallback.
  static String notifFamilyMorningBody(List<String> names) {
    if (names.isEmpty) return '오늘 가족 분량 준비해주세요';
    return '오늘 ${names.join(', ')} 분량 준비해주세요';
  }

  static const String notifFamilyEveningTitle = '🌙 저녁 영양제 잊지 마세요';
  static const String notifFamilyEveningBody = '오늘 하루도 가족 건강 잘 챙기셨어요 💚';

  static const String notifReorderTitle = '💊 영양제 재주문 시기가 됐어요';
  static String notifReorderBody(int days) =>
      '복용 기록 기준 약 $days일이 지났어요. 새로 주문해 두시면 좋아요.';

  // ───────────────────────────────────────────────────────────── 날씨 / 계절 팁
  static const String weatherTipDust = '오늘 공기가 탁해요. 항산화제 챙기세요';
  static const String weatherTipDustEmoji = '😷';
  static const String weatherTipCloudy = '흐린 날씨엔 비타민D가 더 필요해요';
  static const String weatherTipCloudyEmoji = '🌧️';
  static const String seasonSpring = '환절기예요. 면역 영양제 챙기세요';
  static const String seasonSpringEmoji = '🌸';
  static const String seasonSummer = '땀으로 미네랄이 빠져나가요. 마그네슘 챙기세요';
  static const String seasonSummerEmoji = '☀️';
  static const String seasonAutumn = '환절기예요. 비타민C 챙기세요';
  static const String seasonAutumnEmoji = '🍂';
  static const String seasonWinter = '햇빛이 부족해요. 비타민D 더 챙기세요';
  static const String seasonWinterEmoji = '❄️';

  // ───────────────────────────────────────────────────────────── 스트릭 (연속 챙김)
  /// "🔥 N일 연속 가족 모두 챙겼어요!" — 홈 상단 작은 pill.
  static String streakPill(int days) => '🔥 $days일 연속';
  static String streakBanner(int days) => '🔥 $days일 연속 가족 모두 챙겼어요!';
  /// 오늘 가족 모두 체크 완료 시 AI comment 영역에 띄우는 축하 문구.
  static String streakCelebration(int days) =>
      '오늘도 가족 모두 챙겼어요! 🎉\n$days일 연속이에요. 정말 대단해요!';
  static String streakHistoryDialog(int current, int best) =>
      '현재 $current일 연속\n최고 기록 $best일';

  // ───────────────────────────────────────────────────────────── AI fallback
  static const List<String> aiFallbacks = <String>[
    '오늘도 영양제로 가족 건강 챙겨주세요. 작은 습관이 큰 변화를 만들어요 🌱',
    '꾸준함이 답이에요. 오늘 한 알, 내일도 한 알 💊',
    '오늘 영양제 잊지 마세요. 한 입의 작은 사랑이에요 💛',
    '하루 한 번이면 충분해요. 오늘도 챙겨봐요 🌞',
    '물 한 컵과 함께 영양제, 잊지 마세요 💧',
    '오늘도 건강한 하루! 영양제로 마무리해 봐요 ✨',
    '꾸준히가 제일 중요해요. 오늘 분량, 챙기셨나요? 🍀',
    '지금 이 순간, 가족을 위한 작은 챙김 시간이에요 💚',
    '영양제 한 알에 마음을 담아 보세요 🌷',
    '작지만 확실한 건강 습관, 오늘도 만들어 가요 🌟',
  ];
}
