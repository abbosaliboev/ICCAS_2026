import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';

/// App-wide string localization.
/// Usage: final s = S.of(context);  then use s.home, s.events, etc.
/// Non-reactive reads (inside callbacks): S.read(context).someString
class S {
  final bool _ko;
  const S._(this._ko);

  factory S.of(BuildContext context) {
    final code = context.watch<SettingsProvider>().localeCode;
    return S._(code == 'ko');
  }

  factory S.read(BuildContext context) {
    final code = context.read<SettingsProvider>().localeCode;
    return S._(code == 'ko');
  }

  bool get isKorean => _ko;
  String _t(String ko, String en) => _ko ? ko : en;

  // ── Bottom navigation ──────────────────────────────────────────────────────
  String get home => _t('홈', 'Home');
  String get records => _t('기록', 'History');
  String get report => _t('리포트', 'Reports');
  String get settings => _t('설정', 'Settings');

  // ── Common actions ─────────────────────────────────────────────────────────
  String get save => _t('저장', 'Save');
  String get saving => _t('저장 중...', 'Saving...');
  String get cancel => _t('취소', 'Cancel');
  String get delete => _t('삭제', 'Delete');
  String get retry => _t('재시도', 'Retry');
  String get edit => _t('수정', 'Edit');
  String get confirm => _t('확인', 'Confirm');
  String get close => _t('닫기', 'Close');
  String get refresh => _t('새로고침', 'Refresh');

  // ── Fall severity labels ───────────────────────────────────────────────────
  String get all => _t('전체', 'All');
  String get severe => _t('중증', 'Severe');
  String get mild => _t('경미', 'Mild');
  String get severeFall => _t('심각한 낙상', 'Severe Fall');
  String get fallSuspect => _t('낙상 의심', 'Fall Suspected');
  String get confirmed => _t('확인 완료', 'Confirmed');
  String get needsConfirm => _t('확인 필요', 'Needs Confirm');
  String get unconfirmed => _t('미확인', 'Unconfirmed');

  // ── Home screen ────────────────────────────────────────────────────────────
  String greeting(String name) => _ko ? '안녕하세요, $name님' : 'Hello, $name';
  String get normal => _t('정상입니다', 'All Clear');
  String get safeNote => _t('지금 안전하게 지내고 계세요', 'Currently safe and sound');
  String get fallSuspected => _t('낙상 의심 감지', 'Fall Detected');
  String get needsAttention => _t('확인이 필요해요', 'Needs Attention');
  String get severeFallMsg => _t('중증 낙상이 의심됩니다', 'Severe fall suspected');
  String get fallDetectedMsg => _t('낙상이 감지되었습니다', 'A fall has been detected');
  String get recentFalls => _t('최근 낙상 기록', 'Recent Falls');
  String get viewAll => _t('전체보기', 'View All');
  String get noRecentFalls => _t('최근 낙상 기록이 없습니다', 'No recent fall events');
  String get liveCam => _t('라이브 카메라', 'Live Camera');
  String get aiAnalyzing => _t('AI 분석 중', 'AI Monitoring');
  String get emergencyCall => _t('긴급 연락', 'Emergency');
  String get allClearBtn => _t('안심 확인', 'All Clear');

  // Fall response overlay
  String get fallAlertTitle => _t('낙상이 감지되었습니다', 'Fall Detected');
  String get fallAlertMeta => _t('방금 전 · 중증', 'Just now · Severe');
  String get fallAlertTtsPlaying => _t('TTS 재생 중...', 'Playing voice alert...');
  String get fallAlertVoicePrompt =>
      _t('"연락" 또는 "아니"라고 말씀해주세요', 'Say "help" or "no"');
  String get fallAlertContacting => _t('연락 중...', 'Contacting...');
  String get fallAlertContacted =>
      _t('보호자 및 119에 연락 완료', 'Guardian and emergency services contacted');
  String get fallAlertContactError =>
      _t('연락 처리 중 오류 발생', 'Unable to complete contact request');
  String get fallAlertCanceled =>
      _t('취소되었습니다. 안전하세요!', 'Canceled. Please stay safe.');
  String get fallAlertReport119 => _t('119 신고하기', 'Call Emergency');
  String get fallAlertContactGuardian =>
      _t('보호자에게 연락', 'Contact Guardian');
  String get fallAlertConfirmed => _t('확인했습니다', "I'm OK");
  String get fallAlertMicActive => _t('마이크 활성화 중', 'Microphone active');
  String fallAlertSeconds(int seconds) => _ko ? '$seconds초' : '$seconds sec';
  String get fallAlertTtsMessage => _t(
    '낙상이 감지되었습니다. 보호자에게 연락 및 119 신고를 원하시면 "연락"이라고 말씀해주세요. 괜찮으시면 "아니"라고 말씀해주세요. 15초 간 응답이 없으시면 자동으로 119 문자 신고 및 보호자에게 연락 조치가 진행됩니다.',
    'A fall has been detected. If you need your guardian and emergency services contacted, please say "help". If you are okay, please say "no". If there is no response for 15 seconds, an emergency text and guardian alert will be sent automatically.',
  );

  // Emergency dialog
  String get emergencyDialogTitle => _t('긴급 연락', 'Emergency');
  String get emergencyDialogBody => _t(
    '보호자와 119에 즉시 연락하시겠습니까?',
    'Contact your guardian and emergency services now?',
  );
  String get contactNow => _t('연락하기', 'Contact Now');
  String get guardianContactedMsg =>
      _t('보호자 및 119에 연락했습니다', 'Guardian and emergency services contacted');
  String contactFailed(String e) => _t('연락 실패: $e', 'Contact failed: $e');

  // ── Events screen ──────────────────────────────────────────────────────────
  String get fallRecords => _t('낙상 기록', 'Fall Records');
  String get noFalls => _t('낙상 기록이 없습니다', 'No fall events recorded');
  String get noFiltered => _t('해당 기록이 없습니다', 'No matching events');

  // ── Events screen — bulk delete ───────────────────────────────────────────
  String get selectBtn => _t('선택', 'Select');
  String get cancelSelect => _t('취소', 'Cancel');
  String get selectAll => _t('전체 선택', 'Select All');
  String get deselectAll => _t('전체 해제', 'Deselect All');
  String get deleteSelectedBtn => _t('선택 항목 삭제', 'Delete Selected');
  String selectedCount(int n) => _ko ? '${n}개 선택됨' : '$n selected';
  String deleteSelectedTitle(int n) => _ko ? '${n}개 삭제' : 'Delete $n Items';
  String deleteSelectedBody(int n) => _ko
      ? '선택한 ${n}개의 낙상 기록을 삭제할까요?'
      : 'Delete $n selected fall record${n == 1 ? '' : 's'}?';
  String deleteSuccessMsg(int n) =>
      _ko ? '${n}개가 삭제되었습니다' : '$n record${n == 1 ? '' : 's'} deleted';
  String get deletePartialFail =>
      _t('일부 항목 삭제에 실패했습니다', 'Some records failed to delete');

  // ── Reports screen ─────────────────────────────────────────────────────────
  String get reportsTitle => _t('리포트', 'Reports');
  String get today => _t('오늘', 'Today');
  String get thisWeek => _t('이번 주', 'This Week');
  String get thisMonth => _t('이번 달', 'This Month');
  String get allTime => _t('전체', 'All Time');
  String get totalFalls => _t('총 낙상 수', 'Total Falls');
  String get severeEvents => _t('중증 이벤트', 'Severe Events');
  String get peakTime => _t('위험 시간대', 'Peak Hours');
  String get lastEvent => _t('마지막 발생', 'Last Event');
  String get dailyChart => _t('일별 낙상 현황', 'Daily Fall Chart');
  String get exportCsv => _t('CSV 내보내기', 'Export CSV');
  String get emailReport => _t('이메일 전송', 'Email Report');
  String get fallList => _t('낙상 목록', 'Fall List');
  String get noEventsInPeriod =>
      _t('해당 기간 낙상 이벤트 없음', 'No events in this period');
  String countEntries(int n) => _ko ? '${n}건' : '$n event${n == 1 ? '' : 's'}';

  // ── App settings screen ────────────────────────────────────────────────────
  String get settingsTitle => _t('설정', 'Settings');
  String get appearanceSection => _t('외관', 'Appearance');
  String get themeLabel => _t('테마', 'Theme');
  String get themeSubtitle => _t('앱 전체 색상 모드', 'App color mode');
  String get languageLabel => _t('언어', 'Language');
  String get languageSubtitle => _t('앱 표시 언어 설정', 'App display language');
  String get selectLanguage => _t('언어 선택', 'Select Language');
  String get lightMode => _t('☀️  라이트', '☀️  Light');
  String get darkMode => _t('🌙  다크', '🌙  Dark');
  String get lightModeSet => _t('라이트 모드가 설정되었습니다', 'Light mode enabled');
  String get darkModeSet => _t('다크 모드가 설정되었습니다', 'Dark mode enabled');
  String get emergencyContactSection => _t('긴급 연락처', 'Emergency Contact');
  String get emergencyContactSubtitle =>
      _t('연락처를 등록하면 낙상 시 빠른 전화 가능', 'Register for quick emergency contact');
  String emergencyContactSet(String who) =>
      _ko ? '$who(이)가 긴급 연락처로 설정되었습니다' : '$who set as emergency contact';
  String get emergencyContactCleared =>
      _t('긴급 연락처가 삭제되었습니다', 'Emergency contact removed');
  String get connectionSection => _t('연결', 'Connection');
  String get serverSettingsLabel => _t('서버 설정', 'Server Settings');
  String get serverSettingsSubtitle =>
      _t('백엔드 & 엣지 서버 주소', 'Backend & edge server address');
  String get cameraAndSafetySection => _t('카메라 & 안전', 'Camera & Safety');
  String get cameraTypeLabel => _t('카메라 유형', 'Camera Type');
  String get cameraTypeSubtitle =>
      _t('설치 위치에 맞게 설정하세요', 'Set for your installation');
  String cameraTypeSet(String label) =>
      _ko ? '$label(으)로 카메라 유형이 설정되었습니다' : '$label camera type set';
  String get safeZoneLabel => _t('안전 구역 설정', 'Safe Zone Settings');
  String get safeZoneSubtitle =>
      _t('낙상 감지 제외 구역 관리', 'Manage fall detection exclusion zones');
  String get appInfoSection => _t('앱 정보', 'App Info');
  String get appInfoSubtitle =>
      _t('v1.3.0 · Edge AI 기반 낙상 감지', 'v1.3.0 · Edge AI Fall Detection');
  String get logoutLabel => _t('로그아웃', 'Log Out');
  String get logoutConfirmTitle => _t('로그아웃', 'Log Out');
  String get logoutConfirmBody =>
      _t('정말 로그아웃하시겠습니까?', 'Are you sure you want to log out?');
  String get frontCameraBtn => _t('정면', 'Front');
  String get ceilingCameraBtn => _t('천장', 'Ceiling');
  String get guardianAccountLabel => _t('보호자 계정', 'Guardian Account');
  String get userAccountLabel => _t('실사용자 계정', 'User Account');
  String get nameHint => _t('이름 (예: 홍길동)', 'Name');
  String get phoneHint => _t('전화번호 (예: 010-1234-5678)', 'Phone number');
  String languageSelected(String lang) =>
      _ko ? '$lang(으)로 언어가 설정되었습니다' : '$lang language set';

  // ── Safe zone screen ───────────────────────────────────────────────────────
  String get safeZoneTitle => _t('안전 구역 설정', 'Safe Zone Settings');
  String get safeZoneInfo => _t(
    '침대나 소파 등 낙상 감지를 제외할 구역을\n카메라 화면 위에 드래그하여 지정하세요.',
    'Drag on the camera feed to mark areas\n(bed, sofa, etc.) to exclude from fall detection.',
  );
  String get drawZoneLabel => _t('구역 그리기', 'Draw Zone');
  String get editZones => _t('구역 편집', 'Edit Zones');
  String get noZoneLabel => _t('구역 없음', 'No zones');
  String zoneCount(int n) =>
      _ko ? '${n}개 구역 지정됨' : '$n zone${n == 1 ? '' : 's'} defined';
  String get cancelLastZone => _t('마지막 구역 취소', 'Undo Last Zone');
  String get safeZoneSaved => _t('안전 구역이 저장되었습니다', 'Safe zone saved');
  String get safeZoneCleared => _t('구역이 삭제되었습니다', 'Zones cleared');
  String saveFailed(Object e) => _t('저장 실패: $e', 'Save failed: $e');
  String deleteFailed(Object e) => _t('삭제 실패: $e', 'Delete failed: $e');
  String get snapshotRefresh => _t('스냅샷 새로고침', 'Refresh Snapshot');
  String get frontCameraLabel => _t('정면 카메라', 'Front Camera');
  String get ceilingCameraLabel => _t('CCTV (천장)', 'CCTV (Ceiling)');
  String get noCameraMsg => _t(
    '카메라 연결 없음\n구역 그리기는 가능합니다',
    'No camera connected\nZone drawing still available',
  );

  // ── Stream screen ──────────────────────────────────────────────────────────
  String get liveViewTitle => _t('라이브 뷰', 'Live View');
  String get streamConnected => _t('연결됨', 'Connected');
  String get streamDisconnected => _t('연결 끊김', 'Disconnected');
  String get streamFallDetected => _t('낙상 감지됨', 'Fall Detected');
  String get streamResolving => _t('상황 완료', 'Resolved');
  String get streamFallResolved => _t('낙상 상황 해제', 'Fall Cleared');
  String get cameraOffline => _t('카메라 연결 없음', 'Camera Offline');
  String get reconnect => _t('재연결 시도', 'Reconnect');
  String get pauseStream => _t('일시정지', 'Pause');
  String get resumeStream => _t('재생', 'Resume');

  // ── Event detail screen ────────────────────────────────────────────────────
  String get eventDetailTitle => _t('이벤트 상세', 'Event Details');
  String get impactZoneTitle => _t('충격 부위 분석', 'Impact Zone');
  String get estimateLabel => _t('추정', 'Estimate');
  String get impactBadge => _t('충격', 'Impact');
  String get emergencyReportTitle => _t('긴급 리포트', 'Emergency Report');
  String get acknowledgeBtn => _t('확인 처리', 'Acknowledge');
  String get sendSmsBtn => _t('보호자에게 문자 전송', 'Send SMS to Guardian');
  String get smsSentMsg => _t('문자 전송 완료', 'SMS sent successfully');
  String smsFailed(String e) => _t('문자 전송 실패: $e', 'SMS failed: $e');
  String get smsLimitMsg => _t(
      '문자 발송 한도에 도달했습니다. 잠시 후 다시 시도해 주세요',
      'SMS limit reached. Please try again later');
  String get smsFailedFriendly => _t(
      '문자를 보내지 못했습니다. 잠시 후 다시 시도해 주세요',
      'Could not send the SMS. Please try again later');
  String get deleteEventTitle => _t('이벤트 삭제', 'Delete Event');
  String get deleteEventBody =>
      _t('이 이벤트와 관련 영상을 삭제할까요?', 'Delete this event and its footage?');
  String get acknowledgedMsg => _t('확인 처리되었습니다', 'Event acknowledged');
  String get estimatedImpact => _t('추정 충격 부위', 'Estimated Impact');
  String get fallDirectionLabel => _t('낙상 방향', 'Fall Direction');
  String get nameLabel => _t('이름', 'Name');
  String get ageLabel => _t('나이', 'Age');
  String get addressLabel => _t('주소', 'Address');
  String get contactField => _t('연락처', 'Contact');
  String get timeLabel => _t('발생 시각', 'Time');
  String get footageLabel => _t('영상', 'Footage');
  String get available => _t('있음', 'Available');
  String get none => _t('없음', 'None');

  // Body regions (ordered head→foot)
  List<String> get bodyRegions => _ko
      ? ['머리/목', '어깨', '손목/팔꿈치', '골반/고관절', '무릎', '발목/발']
      : [
          'Head/Neck',
          'Shoulder',
          'Wrist/Elbow',
          'Hip/Joint',
          'Knee',
          'Ankle/Foot',
        ];

  // Fall directions map
  Map<String, String> get fallDirections => _ko
      ? {
          'forward': '앞으로 넘어짐',
          'backward': '뒤로 넘어짐',
          'sideways_left': '왼쪽으로 넘어짐',
          'sideways_right': '오른쪽으로 넘어짐',
        }
      : {
          'forward': 'Fell Forward',
          'backward': 'Fell Backward',
          'sideways_left': 'Fell to Left',
          'sideways_right': 'Fell to Right',
        };

  // ── Login screen ───────────────────────────────────────────────────────────
  String get loginSubtitle =>
      _t('낙상 감지 케어 시스템', 'AI Fall Detection Care System');
  String get loginTagline =>
      _t('낙상을 놓치지 않는, 가장 든든한 눈', 'The steady eye that never misses a fall');
  String get usernameHint => _t('아이디', 'Username');
  String get passwordHint => _t('비밀번호', 'Password');
  String get loginBtn => _t('로그인', 'Sign In');
  String get registerBtn => _t('회원가입', 'Create Account');
  String get usernameRequired => _t('아이디를 입력하세요', 'Please enter your username');
  String get passwordRequired =>
      _t('비밀번호를 입력하세요', 'Please enter your password');
  String get loginFailed =>
      _t('아이디 또는 비밀번호가 올바르지 않습니다', 'Invalid username or password');

  // ── Register screen ───────────────────────────────────────────────────────
  String get registerTitle => _t('회원가입', 'Create Account');
  String get registerRoleQuestion =>
      _t('어떤 분으로 가입하시나요?', 'Which role are you registering as?');
  String get registerRoleSubtitle => _t(
    '역할에 따라 화면과 기능이 달라져요.',
    'Screens and features change based on your role.',
  );
  String get registerUserTitle => _t('실사용자', 'Care Recipient');
  String get registerUserSubtitle => _t(
    '낙상 위험이 있는 어르신 본인이에요.',
    'The person who will be monitored for fall risk.',
  );
  String get registerUserFeatures => _t(
    '내 상태 확인 · 긴급 연락 · 카메라/안전구역 설정',
    'Status check · Emergency call · Camera/safe zone setup',
  );
  String get registerGuardianTitle => _t('보호자', 'Guardian');
  String get registerGuardianSubtitle => _t(
    '가족/간병인/요양시설 담당자예요.',
    'A family member, caregiver, or facility staff member.',
  );
  String get registerGuardianFeatures =>
      _t('피보호자 목록 · 알림 수신 · 리포트 확인', 'Care recipient list · Alerts · Reports');
  String get accountInfoSection => _t('계정 정보', 'Account Information');
  String get profileInfoSection => _t('프로필 정보', 'Profile Information');
  String get nameLabelShort => _t('이름', 'Name');
  String get phoneWithFormatLabel => _t('전화번호 (010-XXXX-XXXX)', 'Phone number');
  String get addressOptionalLabel => _t('주소 (선택)', 'Address (optional)');
  String get ageLabelShort => _t('나이', 'Age');
  String get genderUnspecified => _t('미선택', 'Not selected');
  String get completeRegister => _t('가입 완료', 'Create Account');
  String get passwordMinLength =>
      _t('4자 이상 입력하세요', 'Enter at least 4 characters');
  String requiredField(String label) =>
      _ko ? '$label을 입력하세요' : 'Please enter $label';

  // ── Profile screen ─────────────────────────────────────────────────────────
  String get profileTitle => _t('내 프로필', 'My Profile');
  String get displayNameLabel => _t('표시 이름', 'Display Name');
  String get phoneLabelP => _t('전화번호', 'Phone');
  String get addressLabelP => _t('주소', 'Address');
  String get ageLabelP => _t('나이', 'Age');
  String get genderLabel => _t('성별', 'Gender');
  String get male => _t('남성', 'Male');
  String get female => _t('여성', 'Female');
  String get noSetting => _t('미설정', 'Not set');
  String get guardianLinkLabel => _t('보호자 연동', 'Link Guardian');
  String get guardianConnectLabel => _t('보호자 연결', 'Guardian Link');
  String get guardianConnectHelp => _t(
    '보호자 계정의 아이디를 입력하면 낙상 발생 시 자동으로 알림이 전송됩니다.',
    'Enter a guardian account username to send alerts automatically when a fall occurs.',
  );
  String get guardianUsernameHint => _t('보호자 아이디', 'Guardian username');
  String get connectBtn => _t('연결', 'Link');
  String get profileSaved => _t('프로필이 저장되었습니다', 'Profile saved');
  String saveFailedShort(Object e) => _t('저장 실패: $e', 'Save failed: $e');
  String get optional => _t('선택사항', 'Optional');
  String get basicInfoSection => _t('기본 정보', 'Basic Information');
  String get guardianRole => _t('보호자', 'Guardian');
  String get careRecipientRole => _t('피보호자', 'Care Recipient');

  // ── Guardian screen ────────────────────────────────────────────────────────
  String get guardianTitle => _t('보호 대상 모니터링', 'Monitoring');
  String get noMonitoredUser =>
      _t('연동된 피보호자가 없습니다', 'No monitored user linked');
  String get guardianCodeSection => _t('나의 보호자 코드', 'My Guardian Code');
  String get enterGuardianCode => _t('보호자 코드 입력', 'Enter guardian code');
  String get linkGuardianBtn => _t('보호자 연동하기', 'Link Guardian');
  String get linkSuccess => _t('보호자 연동 완료', 'Guardian linked');
  String get monitoredStatusTitle => _t('피보호자 현황', 'Care Recipient Status');
  String monitoredStatusSubtitle(int n) => _ko
      ? '등록된 ${n}명의 상태를 한눈에 확인하세요'
      : 'View the status of $n registered care recipient${n == 1 ? '' : 's'}';
  String get noLinkedRecipients =>
      _t('연결된 피보호자가 없습니다', 'No linked care recipients');
  String get linkByGuardianId => _t(
    '피보호자가 보호자 아이디를 입력하여 연결합니다',
    'Care recipients can link by entering your guardian username',
  );
  String get allFallRecords => _t('전체 낙상 기록', 'All Fall Records');
  String get noRecords => _t('기록 없음', 'No records');
  String get justNowFallNeedsCheck =>
      _t('방금 · 낙상 의심 · 확인 필요', 'Just now · Fall suspected · Needs check');
  String ageYears(int age) => _ko ? '${age}세' : '$age yrs';
  String monitoredEventTitle(String? name, bool isSevere) {
    if (name != null) {
      return _ko
          ? '$name님 · ${isSevere ? severe : mild}'
          : '$name · ${isSevere ? severe : mild}';
    }
    return isSevere ? severeFall : fallSuspect;
  }

  // ── Server settings screen ─────────────────────────────────────────────────
  String get serverSettingsTitle => _t('서버 설정', 'Server Settings');
  String get backendUrlLabel => _t('백엔드 서버 URL', 'Backend Server URL');
  String get backendUrlHelp => _t(
    '인증·이벤트·리포트 등 앱 기능 서버',
    'App feature server for auth, events, and reports',
  );
  String get edgeUrlLabel => _t('엣지 디바이스 URL', 'Edge Device URL');
  String get edgeUrlHelp => _t(
    '카메라 영상·AI 낙상감지 디바이스 (Jetson 등)',
    'Camera and AI fall detection device, such as Jetson',
  );
  String get savedDone => _t('저장 완료!', 'Saved');
  String get connectionGuideTitle => _t('연결 방법', 'Connection Guide');
  String get connectionGuideBody => _t(
    '• 백엔드 서버: 이 PC (예: 192.168.0.57)\n'
        '• 엣지 디바이스: Jetson 카메라 장치 (예: 192.168.0.53)\n'
        '• 모두 같은 WiFi에 연결되어 있어야 합니다.',
    '• Backend server: this PC (for example, 192.168.0.57)\n'
        '• Edge device: Jetson camera device (for example, 192.168.0.53)\n'
        '• Both devices must be connected to the same Wi-Fi.',
  );
  String get testConnectionLabel => _t('연결 테스트', 'Test Connection');
  String get connecting => _t('연결 중...', 'Connecting...');
  String get connectionSuccess => _t('연결 성공', 'Connection OK');
  String connectionFailedMsg(String e) =>
      _t('연결 실패: $e', 'Connection failed: $e');
}
