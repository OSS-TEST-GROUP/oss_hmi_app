import 'dart:convert';
import 'dart:io';

import 'app_config.dart';

/// 패널 설정 파일 두 벌을 관리한다 — **둘 다 쓰기 가능한 `$XDG_CONFIG_HOME` 안**에 둔다.
///
/// | 파일 | 뜻 | 누가 만드나 |
/// |---|---|---|
/// | `config_def.json` | 이 기기의 **기본값** | 패널이 첫 실행에 코드 기본값으로 만든다 |
/// | `config.json` | **사용자 변경분** (화면에서 저장) | 저장 버튼 |
///
/// 읽기: `config.json` → 없으면 `config_def.json` → 없으면 코드 기본값(그리고 그때
/// `config_def.json` 을 만들어 둔다).
/// "기본값으로" 는 `config.json` 을 `.bak` 으로 치워 `config_def.json` 으로 되돌아간다.
///
/// **왜 마운트를 쓰지 않나**: 예전에는 사이트 기본값을 `/etc/rviz2_panel/config.json` 으로
/// 마운트했다(adsw 서비스 정의). 그러면 ① Yocto 이미지에 파일과 마운트를 넣어야 하고
/// ② 읽기 전용이라 기기에서 기본값을 조정할 수 없었다. 두 파일을 `/cfg` 안에 두면
/// **이미지를 건드리지 않고** 기본값·사용자값을 모두 기기에서 다룰 수 있다.
/// 보드에서 `XDG_CONFIG_HOME=/cfg` 는 호스트 `/root/oss/hmi_launcher_cfg` 로 마운트돼
/// 있어(런처가 app_visibility.json 을 두는 그 디렉토리) 재기동 후에도 남는다.
class UserConfigStore {
  UserConfigStore({String? path, String? defaultPath})
      : _path = path ?? defaultUserPath(),
        _defPath = defaultPath ?? defaultDefPath();

  final String _path;
  final String _defPath;

  /// 사용자 변경분 경로(화면 표시용).
  String get path => _path;

  /// 기본값 파일 경로(화면 표시용).
  String get defPath => _defPath;

  static String _dir() {
    final env = Platform.environment;
    final base = env['XDG_CONFIG_HOME'] ?? '${env['HOME'] ?? '/tmp'}/.config';
    return '$base/rviz2_panel';
  }

  /// `$XDG_CONFIG_HOME/rviz2_panel/config.json`
  static String defaultUserPath() => '${_dir()}/config.json';

  /// `$XDG_CONFIG_HOME/rviz2_panel/config_def.json`
  static String defaultDefPath() => '${_dir()}/config_def.json';

  /// 사용자 변경분. 없거나 깨졌으면 null.
  Future<AppConfig?> load() => _read(_path);

  /// 기기 기본값. 없거나 깨졌으면 null.
  Future<AppConfig?> loadDefault() => _read(_defPath);

  Future<AppConfig?> _read(String p) async {
    try {
      final f = File(p);
      if (!await f.exists()) return null;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return AppConfig.fromJson(json);
    } catch (e) {
      stderr.writeln('[rviz2_panel] 설정 읽기 실패 ($p): $e');
      return null;
    }
  }

  /// 사용자 변경분을 저장한다. 실패 사유는 화면에 보여줄 수 있게 돌려준다.
  Future<String?> save(AppConfig cfg) => _write(_path, cfg);

  /// 기본값 파일이 **없을 때만** 만든다(이미 있으면 손대지 않는다).
  /// 운영자가 그 파일을 직접 고쳐 기기 기본값을 바꿀 수 있으므로 덮어쓰지 않는다.
  Future<String?> seedDefault(AppConfig cfg) async {
    if (await File(_defPath).exists()) return null;
    return _write(_defPath, cfg);
  }

  Future<String?> _write(String p, AppConfig cfg) async {
    try {
      final f = File(p);
      await f.parent.create(recursive: true);
      await f.writeAsString(
          const JsonEncoder.withIndent('  ').convert(cfg.toJson()));
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// 사용자 변경분을 치운다 — 다음 로드부터 기본값 파일로 돌아간다.
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
