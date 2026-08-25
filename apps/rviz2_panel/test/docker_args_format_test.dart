import 'package:flutter_test/flutter_test.dart';
import 'package:rviz2_panel/config/docker_args_format.dart';

/// 화면은 "인자 하나가 한 줄", 파일은 "토큰 하나씩" — 그 사이 변환이 값을 흔들지
/// 않아야 저장/재진입이 안전하다.
void main() {
  const tokens = [
    '--net=host',
    '--ipc=host',
    '--user', '1001:1001',
    '--group-add', '44',
    '-v', '/run/user/1001:/host-xdg',
    '-e', 'XDG_RUNTIME_DIR=/host-xdg',
    '-e', 'WAYLAND_DISPLAY=wayland-0',
    '-e', 'HOME=/tmp',
    '-e', 'LIBGL_ALWAYS_SOFTWARE=1',
  ];

  test('플래그와 값이 한 줄로 묶인다', () {
    expect(dockerArgsToText(tokens).split('\n'), [
      '--net=host',
      '--ipc=host',
      '--user 1001:1001',
      '--group-add 44',
      '-v /run/user/1001:/host-xdg',
      '-e XDG_RUNTIME_DIR=/host-xdg',
      '-e WAYLAND_DISPLAY=wayland-0',
      '-e HOME=/tmp',
      '-e LIBGL_ALWAYS_SOFTWARE=1',
    ]);
  });

  test('왕복해도 토큰이 그대로다', () {
    expect(dockerArgsFromText(dockerArgsToText(tokens)), tokens);
  });

  test('사람이 손으로 쓴 여백·빈 줄도 받아들인다', () {
    expect(
      dockerArgsFromText('  --net=host \n\n  --user   1001:1001  \n'),
      ['--net=host', '--user', '1001:1001'],
    );
  });

  test('값 없는 플래그가 연달아 와도 각각 한 줄', () {
    expect(dockerArgsToText(['-d', '--rm']).split('\n'), ['-d', '--rm']);
  });
}
