import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'dds_bridge.dart';

/// DdsKeeper initialises the DDS bridge and subscribes to the OTA topics.
///
/// It holds one [NativeCallable] per subscribed topic so the C++ listener
/// thread can safely dispatch callbacks back onto the Dart isolate.
class DdsKeeper {
  DdsKeeper({int domainId = 0}) : _domainId = domainId;

  final int _domainId;
  final DdsBridge _bridge = DdsBridge.instance;

  // One NativeCallable per subscription (keeps the pointer alive).
  final List<NativeCallable<DdsMsgCallbackNative>> _callables = [];

  bool _started = false;

  /// Initialise DDS.  Must be called before subscribing.
  int init() {
    final rc = _bridge.init(domainId: _domainId);
    if (rc != 0) {
      debugPrint('[DDS] init failed: $rc');
    } else {
      debugPrint('[DDS] init ok (domain $_domainId)');
      _started = true;
    }
    return rc;
  }

  bool get isStarted => _started;

  /// Subscribe to [topicName].
  ///
  /// [onMessage] receives *(topicName, jsonString)* on the Flutter isolate.
  int subscribe(
      String topicName,
      String typeName,
      void Function(String topic, String json) onMessage) {
    // Create a NativeCallable.listener so the C++ callback is dispatched back
    // to the Dart isolate's event loop — safe without locks.
    final callable = NativeCallable<DdsMsgCallbackNative>.listener(
      (Pointer<Utf8> tPtr, Pointer<Utf8> jPtr) {
        final topic = tPtr.toDartString();
        final json  = jPtr.toDartString();
        onMessage(topic, json);
      },
    );
    _callables.add(callable);

    final rc = _bridge.subscribe(topicName, typeName, callable.nativeFunction);
    if (rc != 0) {
      debugPrint('[DDS] subscribe failed ($rc): $topicName');
    } else {
      debugPrint('[DDS] subscribed: $topicName');
    }
    return rc;
  }

  /// Publish a JSON message.
  int publish(String topicName, String typeName, String json) {
    return _bridge.publish(topicName, typeName, json);
  }

  /// Release all DDS resources.
  void dispose() {
    _bridge.cleanup();
    for (final c in _callables) {
      c.close();
    }
    _callables.clear();
    _started = false;
    debugPrint('[DDS] disposed');
  }
}
