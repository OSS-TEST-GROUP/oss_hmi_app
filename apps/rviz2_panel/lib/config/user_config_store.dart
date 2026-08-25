import 'dart:convert';
import 'dart:io';

import 'app_config.dart';

/// 패널에서 바꾼 옵션을 **영구 저장**하는 계층.
///
/// 왜 별도 파일인가: 사이트 기본값은 `/etc/rviz2_panel/config.json` 으로 내려오는데
/// 이 마운트는 읽기 전용이다(adsw 서비스 정의, `:ro`). 사용자가 화면에서 바꾼 값은
/// 쓰기 가능한 곳에 따로 남겨야 재기동 후에도 유지된다.
///
/// 저장 위치: `$XDG_CONFIG_HOME/rviz2_panel/config.json`
///   · 보드에서 XDG_CONFIG_HOME=/cfg 이고 호스트 `/root/oss/hmi_launcher_cfg` 로
///     마운트돼 있다 — 런처가 app_visibility.json 을 영속화하는 그 디렉토리다.
///   · XDG_CONFIG_HOME 이 없으면 `$HOME/.config` 로 떨어진다(단독 실행/개발용).
///     보드에서 HOME 은 /tmp(tmpfs)라 재부팅 시 사라지므로, 영속을 원하면
///     XDG_CONFIG_HOME 이 설정돼 있어야 한다.
///
/// 우선순위: 이 파일 > 사이트 기본값(/etc 등) > [AppConfig.defaults].
/// 저장은 **전체 스냅샷**이다(부분 병합 아님) — 화면이 모든 필드를 보여주고 그대로
/// 저장하므로, 부분 오버레이보다 "지금 보이는 값이 곧 저장된 값"이 예측하기 쉽다.
class UserConfigStore {
  UserConfigStore({String? path}) : _path = path ?? defaultPath();

  final String _path;

  /// 저장 파일 경로(표시용).
  String get path => _path;

  /// `$XDG_CONFIG_HOME/rviz2_panel/config.json` (없으면 `$HOME/.config/...`).
  static String defaultPath() {
    final env = Platform.environment;
    final base = env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '/tmp'}/.config';
    return '$base/rviz2_panel/config.json';
  }

  /// 저장된 사용자 설정. 없거나 깨졌으면 null (→ 호출자가 사이트 기본값을 쓴다).
  Future<AppConfig?> load() async {
    try {
      final f = File(_path);
      if (!await f.exists()) return null;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return AppConfig.fromJson(json);
    } catch (e) {
      stderr.writeln('[rviz2_panel] 사용자 설정 읽기 실패 ($_path): $e');
      return null;
    }
  }

  /// 현재 설정을 저장한다. 실패 사유는 호출자가 화면에 보여줄 수 있도록 돌려준다
  /// (읽기 전용 파일시스템·권한 등 — 경계에서만 방어한다).
  Future<String?> save(AppConfig cfg) async {
    try {
      final f = File(_path);
      await f.parent.create(recursive: true);
      await f.writeAsString(
          const JsonEncoder.withIndent('  ').convert(cfg.toJson()));
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// 저장본을 치운다 — 다음 로드부터 사이트 기본값으로 돌아간다.
  /// 지우지 않고 `.bak` 으로 옮긴다(되돌리기 여지를 남긴다).
  Future<String?> reset() async {
    try {
      final f = File(_path);
      if (await f.exists()) await f.rename('$_path.bak');
      return null;
    } catch (e) {
      return '$e';
    }
  }
}
