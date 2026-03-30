// 웹이면 web용, 아니면 io용 구현 선택
export 'config_loader_web.dart'
  if (dart.library.io) 'config_loader_io.dart';