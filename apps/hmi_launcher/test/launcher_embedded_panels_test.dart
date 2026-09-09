// QA(docs/qa): embedded 패널(ota/adsw/lfc/rviz2)은 **통합 경계**로 분류.
//
// 각 패널은 임베드된 모니터 앱의 RosKeeper(주기 Timer)와 실 rosbridge 연결을
// initState 에서 시작한다. testWidgets 의 FakeAsync 환경에서는 이 백그라운드
// 타이머가 "pending timer" 로 남아 위젯 유닛 테스트가 불가하다(rviz2_panel 의
// permanent 컨트롤러 타이머 이슈와 동일 성격). — MMF OTA Mgr 의 DDS/HTTP 래퍼를
// LCOV_EXCL 로 유닛 분모에서 분리한 것과 같은 판단.
//
// 검증 경로: HMI 통합 레인(내장 MockOtaManager + Xvfb, INTEGRATION_TEST_GUIDE.md).
// 유닛 커버리지 측정에서는 embedded 패널을 분모에서 제외한다(측정 스크립트 필터).
//
// 서비스 레벨의 rosbridge 로직(LauncherRosKeeper)은 mock rosbridge 로 유닛 검증됨
// (launcher_ros_keeper_test.dart, 82%).
void main() {}
