//
//  Generated code. Do not modify.
//  source: agent.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'agent.pbenum.dart';

export 'agent.pbenum.dart';

/// AgentSubmitRequest — Agent.Submit 요청 페이로드.
/// 사용자가 텍스트 또는 음성 전사 텍스트를 에이전트에게 제출.
class AgentSubmitRequest extends $pb.GeneratedMessage {
  factory AgentSubmitRequest({
    $core.String? text,
    $core.Iterable<$core.String>? contexts,
    $core.String? sessionId,
  }) {
    final $result = create();
    if (text != null) {
      $result.text = text;
    }
    if (contexts != null) {
      $result.contexts.addAll(contexts);
    }
    if (sessionId != null) {
      $result.sessionId = sessionId;
    }
    return $result;
  }
  AgentSubmitRequest._() : super();
  factory AgentSubmitRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AgentSubmitRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AgentSubmitRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ivi.agent'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..pPS(2, _omitFieldNames ? '' : 'contexts')
    ..aOS(3, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AgentSubmitRequest clone() => AgentSubmitRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AgentSubmitRequest copyWith(void Function(AgentSubmitRequest) updates) => super.copyWith((message) => updates(message as AgentSubmitRequest)) as AgentSubmitRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AgentSubmitRequest create() => AgentSubmitRequest._();
  AgentSubmitRequest createEmptyInstance() => create();
  static $pb.PbList<AgentSubmitRequest> createRepeated() => $pb.PbList<AgentSubmitRequest>();
  @$core.pragma('dart2js:noInline')
  static AgentSubmitRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentSubmitRequest>(create);
  static AgentSubmitRequest? _defaultInstance;

  /// 사용자 입력 텍스트 (직접 입력 또는 STT 결과).
  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => clearField(1);

  /// 컨텍스트 힌트 목록. 현재 열린 앱·화면 등의 정보.
  /// 예: ["Launcher", "MediaApp", "MapApp"]
  @$pb.TagNumber(2)
  $core.List<$core.String> get contexts => $_getList(1);

  /// 세션 식별자. 같은 대화 세션 내 연속 턴 추적용.
  /// 빈 문자열이면 서버가 새 세션 시작.
  @$pb.TagNumber(3)
  $core.String get sessionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set sessionId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSessionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionId() => clearField(3);
}

/// AgentSubmitResponse — Agent.Submit 응답.
class AgentSubmitResponse extends $pb.GeneratedMessage {
  factory AgentSubmitResponse({
    $core.String? text,
    $core.Iterable<ActionSummary>? actions,
    $core.String? sessionId,
  }) {
    final $result = create();
    if (text != null) {
      $result.text = text;
    }
    if (actions != null) {
      $result.actions.addAll(actions);
    }
    if (sessionId != null) {
      $result.sessionId = sessionId;
    }
    return $result;
  }
  AgentSubmitResponse._() : super();
  factory AgentSubmitResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AgentSubmitResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AgentSubmitResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'ivi.agent'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..pc<ActionSummary>(2, _omitFieldNames ? '' : 'actions', $pb.PbFieldType.PM, subBuilder: ActionSummary.create)
    ..aOS(3, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AgentSubmitResponse clone() => AgentSubmitResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AgentSubmitResponse copyWith(void Function(AgentSubmitResponse) updates) => super.copyWith((message) => updates(message as AgentSubmitResponse)) as AgentSubmitResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AgentSubmitResponse create() => AgentSubmitResponse._();
  AgentSubmitResponse createEmptyInstance() => create();
  static $pb.PbList<AgentSubmitResponse> createRepeated() => $pb.PbList<AgentSubmitResponse>();
  @$core.pragma('dart2js:noInline')
  static AgentSubmitResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentSubmitResponse>(create);
  static AgentSubmitResponse? _defaultInstance;

  /// 에이전트의 텍스트 응답. TTS 는 ivi-hmi.service 가 별도 처리.
  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => clearField(1);

  /// 에이전트가 실행한 도구 호출 결과 요약 (선택적).
  /// 클라이언트가 어떤 도구가 동작했는지 알 필요가 있는 경우에만 채워짐.
  @$pb.TagNumber(2)
  $core.List<ActionSummary> get actions => $_getList(1);

  /// 처리 세션 ID. 이후 연속 Submit 에서 재사용 가능.
  @$pb.TagNumber(3)
  $core.String get sessionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set sessionId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSessionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionId() => clearField(3);
}

/// ActionSummary — 에이전트가 실행한 단일 도구 호출의 요약.
/// UI 표시용 — 상세 페이로드는 Tools.Invoke 레이어 책임.
class ActionSummary extends $pb.GeneratedMessage {
  factory ActionSummary({
    $core.String? tool,
    $core.String? summary,
    $core.bool? success,
  }) {
    final $result = create();
    if (tool != null) {
      $result.tool = tool;
    }
    if (summary != null) {
      $result.summary = summary;
    }
    if (success != null) {
      $result.success = success;
    }
    return $result;
  }
  ActionSummary._() : super();
  factory ActionSummary.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ActionSummary.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ActionSummary', package: const $pb.PackageName(_omitMessageNames ? '' : 'ivi.agent'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'tool')
    ..aOS(2, _omitFieldNames ? '' : 'summary')
    ..aOB(3, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ActionSummary clone() => ActionSummary()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ActionSummary copyWith(void Function(ActionSummary) updates) => super.copyWith((message) => updates(message as ActionSummary)) as ActionSummary;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ActionSummary create() => ActionSummary._();
  ActionSummary createEmptyInstance() => create();
  static $pb.PbList<ActionSummary> createRepeated() => $pb.PbList<ActionSummary>();
  @$core.pragma('dart2js:noInline')
  static ActionSummary getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ActionSummary>(create);
  static ActionSummary? _defaultInstance;

  /// 실행된 도구 이름 ("navigation.set_destination" 형식).
  @$pb.TagNumber(1)
  $core.String get tool => $_getSZ(0);
  @$pb.TagNumber(1)
  set tool($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTool() => $_has(0);
  @$pb.TagNumber(1)
  void clearTool() => clearField(1);

  /// 사람이 읽을 수 있는 도구 실행 결과 요약.
  @$pb.TagNumber(2)
  $core.String get summary => $_getSZ(1);
  @$pb.TagNumber(2)
  set summary($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSummary() => $_has(1);
  @$pb.TagNumber(2)
  void clearSummary() => clearField(2);

  /// 도구 실행 성공 여부.
  @$pb.TagNumber(3)
  $core.bool get success => $_getBF(2);
  @$pb.TagNumber(3)
  set success($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSuccess() => $_has(2);
  @$pb.TagNumber(3)
  void clearSuccess() => clearField(3);
}

/// SubscribeRequest — Agent.Subscribe 구독 요청.
/// Phase 2 에서 채워질 예정. 현재는 골격만.
class SubscribeRequest extends $pb.GeneratedMessage {
  factory SubscribeRequest({
    $core.Iterable<$core.String>? categories,
  }) {
    final $result = create();
    if (categories != null) {
      $result.categories.addAll(categories);
    }
    return $result;
  }
  SubscribeRequest._() : super();
  factory SubscribeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SubscribeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SubscribeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'ivi.agent'), createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'categories')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SubscribeRequest clone() => SubscribeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SubscribeRequest copyWith(void Function(SubscribeRequest) updates) => super.copyWith((message) => updates(message as SubscribeRequest)) as SubscribeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubscribeRequest create() => SubscribeRequest._();
  SubscribeRequest createEmptyInstance() => create();
  static $pb.PbList<SubscribeRequest> createRepeated() => $pb.PbList<SubscribeRequest>();
  @$core.pragma('dart2js:noInline')
  static SubscribeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubscribeRequest>(create);
  static SubscribeRequest? _defaultInstance;

  /// 구독할 카드 카테고리 필터. 빈 목록이면 전체 카드 수신.
  /// Phase 2: 운전 중 자동 억제 / 우선순위 필터링 로직과 연동.
  @$pb.TagNumber(1)
  $core.List<$core.String> get categories => $_getList(0);
}

/// ProactiveCard — 에이전트가 자발적으로 발행하는 능동 제안 카드.
/// 기획서 §1.3 + §6.2: 항상 사용자가 거절(dismiss) 가능해야 한다.
/// Phase 2 에서 UI 표현(Flutter 카드 컴포넌트 + dismiss 액션) 구현 예정.
/// ADR-014 결정 6: 본 proto 에 시그니처만 보장.
class ProactiveCard extends $pb.GeneratedMessage {
  factory ProactiveCard({
    $core.String? cardId,
    $core.String? category,
    $core.String? title,
    $core.String? body,
    $core.Iterable<CardAction>? actions,
  }) {
    final $result = create();
    if (cardId != null) {
      $result.cardId = cardId;
    }
    if (category != null) {
      $result.category = category;
    }
    if (title != null) {
      $result.title = title;
    }
    if (body != null) {
      $result.body = body;
    }
    if (actions != null) {
      $result.actions.addAll(actions);
    }
    return $result;
  }
  ProactiveCard._() : super();
  factory ProactiveCard.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ProactiveCard.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ProactiveCard', package: const $pb.PackageName(_omitMessageNames ? '' : 'ivi.agent'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cardId')
    ..aOS(2, _omitFieldNames ? '' : 'category')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'body')
    ..pc<CardAction>(5, _omitFieldNames ? '' : 'actions', $pb.PbFieldType.PM, subBuilder: CardAction.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ProactiveCard clone() => ProactiveCard()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ProactiveCard copyWith(void Function(ProactiveCard) updates) => super.copyWith((message) => updates(message as ProactiveCard)) as ProactiveCard;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProactiveCard create() => ProactiveCard._();
  ProactiveCard createEmptyInstance() => create();
  static $pb.PbList<ProactiveCard> createRepeated() => $pb.PbList<ProactiveCard>();
  @$core.pragma('dart2js:noInline')
  static ProactiveCard getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProactiveCard>(create);
  static ProactiveCard? _defaultInstance;

  /// 카드 고유 식별자. dismiss 시 이 ID 를 에이전트에게 피드백.
  @$pb.TagNumber(1)
  $core.String get cardId => $_getSZ(0);
  @$pb.TagNumber(1)
  set cardId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCardId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCardId() => clearField(1);

  /// 카드 카테고리. UI 가 표시 방식을 결정하는 힌트.
  /// 예: "navigation_suggestion" | "media_control" | "hvac_alert"
  @$pb.TagNumber(2)
  $core.String get category => $_getSZ(1);
  @$pb.TagNumber(2)
  set category($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCategory() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategory() => clearField(2);

  /// 카드 제목 (짧고 명확하게).
  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => clearField(3);

  /// 카드 본문 텍스트.
  @$pb.TagNumber(4)
  $core.String get body => $_getSZ(3);
  @$pb.TagNumber(4)
  set body($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasBody() => $_has(3);
  @$pb.TagNumber(4)
  void clearBody() => clearField(4);

  /// 카드에 연결된 액션 목록 (예: [승인, 거절]).
  /// Phase 2: LauncherBotController 에서 처리 예정.
  @$pb.TagNumber(5)
  $core.List<CardAction> get actions => $_getList(4);
}

/// CardAction — ProactiveCard 에 표시되는 사용자 선택 가능 액션.
class CardAction extends $pb.GeneratedMessage {
  factory CardAction({
    $core.String? label,
    ActionType? actionType,
  }) {
    final $result = create();
    if (label != null) {
      $result.label = label;
    }
    if (actionType != null) {
      $result.actionType = actionType;
    }
    return $result;
  }
  CardAction._() : super();
  factory CardAction.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CardAction.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CardAction', package: const $pb.PackageName(_omitMessageNames ? '' : 'ivi.agent'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'label')
    ..e<ActionType>(2, _omitFieldNames ? '' : 'actionType', $pb.PbFieldType.OE, defaultOrMaker: ActionType.ACTION_TYPE_UNSPECIFIED, valueOf: ActionType.valueOf, enumValues: ActionType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CardAction clone() => CardAction()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CardAction copyWith(void Function(CardAction) updates) => super.copyWith((message) => updates(message as CardAction)) as CardAction;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CardAction create() => CardAction._();
  CardAction createEmptyInstance() => create();
  static $pb.PbList<CardAction> createRepeated() => $pb.PbList<CardAction>();
  @$core.pragma('dart2js:noInline')
  static CardAction getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CardAction>(create);
  static CardAction? _defaultInstance;

  /// 액션 레이블 (버튼 텍스트).
  @$pb.TagNumber(1)
  $core.String get label => $_getSZ(0);
  @$pb.TagNumber(1)
  set label($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasLabel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLabel() => clearField(1);

  /// 액션 처리 방식 힌트.
  @$pb.TagNumber(2)
  ActionType get actionType => $_getN(1);
  @$pb.TagNumber(2)
  set actionType(ActionType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasActionType() => $_has(1);
  @$pb.TagNumber(2)
  void clearActionType() => clearField(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
