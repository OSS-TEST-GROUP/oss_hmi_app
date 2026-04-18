// Pick the web implementation on web, the io implementation otherwise.
export 'config_loader_web.dart'
  if (dart.library.io) 'config_loader_io.dart';