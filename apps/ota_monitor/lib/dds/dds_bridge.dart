import 'dart:ffi';
import 'package:ffi/ffi.dart';

// ---------------------------------------------------------------------------
// Public callback type — used by both DdsBridge and DdsKeeper
// ---------------------------------------------------------------------------

/// Native callback signature invoked by the C++ DDS listener thread.
typedef DdsMsgCallbackNative = Void Function(
    Pointer<Utf8> topic, Pointer<Utf8> json);

// ---------------------------------------------------------------------------
// Native function signatures (library-private)
// ---------------------------------------------------------------------------

typedef _DdsInitNative = Int32 Function(Int32 domainId);
typedef _DdsInit = int Function(int domainId);

typedef _DdsSubscribeNative = Int32 Function(
    Pointer<Utf8> topicName,
    Pointer<Utf8> typeName,
    Pointer<NativeFunction<DdsMsgCallbackNative>> callback);
typedef _DdsSubscribe = int Function(
    Pointer<Utf8> topicName,
    Pointer<Utf8> typeName,
    Pointer<NativeFunction<DdsMsgCallbackNative>> callback);

typedef _DdsPublishNative = Int32 Function(
    Pointer<Utf8> topicName, Pointer<Utf8> typeName, Pointer<Utf8> json);
typedef _DdsPublish = int Function(
    Pointer<Utf8> topicName, Pointer<Utf8> typeName, Pointer<Utf8> json);

typedef _DdsCleanupNative = Void Function();
typedef _DdsCleanup = void Function();

// ---------------------------------------------------------------------------
// DdsBridge – wraps libdds_ota_bridge.so
// ---------------------------------------------------------------------------

class DdsBridge {
  static DdsBridge? _instance;
  static DdsBridge get instance => _instance ??= DdsBridge._();

  late final DynamicLibrary _lib;
  late final _DdsInit _init;
  late final _DdsSubscribe _subscribe;
  late final _DdsPublish _publish;
  late final _DdsCleanup _cleanup;

  DdsBridge._() {
    // The .so is installed next to the executable in the bundle's lib/ dir.
    const libName = 'libdds_ota_bridge.so';
    _lib = DynamicLibrary.open(libName);

    _init = _lib
        .lookup<NativeFunction<_DdsInitNative>>('dds_ota_init')
        .asFunction();
    _subscribe = _lib
        .lookup<NativeFunction<_DdsSubscribeNative>>('dds_ota_subscribe')
        .asFunction();
    _publish = _lib
        .lookup<NativeFunction<_DdsPublishNative>>('dds_ota_publish')
        .asFunction();
    _cleanup = _lib
        .lookup<NativeFunction<_DdsCleanupNative>>('dds_ota_cleanup')
        .asFunction();
  }

  /// Initialize DDS.  Must be called once before subscribe/publish.
  int init({int domainId = 0}) => _init(domainId);

  /// Subscribe to [topicName].
  ///
  /// [callback] must be a [NativeCallable.listener] function pointer so it is
  /// safely dispatched back to the Dart isolate from the C++ listener thread.
  int subscribe(
      String topicName,
      String typeName,
      Pointer<NativeFunction<DdsMsgCallbackNative>> callback) {
    final tPtr = topicName.toNativeUtf8();
    final tnPtr = typeName.toNativeUtf8();
    try {
      return _subscribe(tPtr, tnPtr, callback);
    } finally {
      calloc.free(tPtr);
      calloc.free(tnPtr);
    }
  }

  /// Publish [json] to [topicName] / [typeName].
  int publish(String topicName, String typeName, String json) {
    final tPtr  = topicName.toNativeUtf8();
    final tnPtr = typeName.toNativeUtf8();
    final jPtr  = json.toNativeUtf8();
    try {
      return _publish(tPtr, tnPtr, jPtr);
    } finally {
      calloc.free(tPtr);
      calloc.free(tnPtr);
      calloc.free(jPtr);
    }
  }

  /// Release DDS resources.
  void cleanup() => _cleanup();
}
