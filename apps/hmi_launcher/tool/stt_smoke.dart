// Smoke test for the persistent-channel STT path used by AgentSubmitAiService.
//
// Opens ONE ClientChannel to the daemon and issues two sequential Transcribe
// calls on it — call #1 pays connection setup, call #2 reuses the warm HTTP/2
// connection. The gap between them is the latency a persistent connection
// saves versus opening a fresh channel per utterance.
//
// Usage: dart run tool/stt_smoke.dart <host> <port> <s16le-16k-pcm-file>
import 'dart:io';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';

import '../lib/generated/common.pb.dart';
import '../lib/generated/speech.pbgrpc.dart';

Future<void> main(List<String> args) async {
  final host = args.isNotEmpty ? args[0] : '127.0.0.1';
  final port = args.length > 1 ? int.parse(args[1]) : 50051;
  final path = args.length > 2 ? args[2] : 'ko_test.pcm';

  // raw s16le @16k → Float32List([-1,1]), mirroring VoiceInputService output.
  final raw = File(path).readAsBytesSync();
  final s16 = ByteData.sublistView(raw);
  final pcm = Float32List(raw.length ~/ 2);
  for (var i = 0; i < pcm.length; i++) {
    pcm[i] = s16.getInt16(i * 2, Endian.little) / 32768.0;
  }
  final audio = pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes);
  stdout.writeln('[smoke] host=$host:$port pcm=$path samples=${pcm.length} '
      'dur=${(pcm.length / 16000).toStringAsFixed(2)}s');

  // ONE channel, ONE stub — the persistent connection.
  final channel = ClientChannel(host,
      port: port,
      options:
          const ChannelOptions(credentials: ChannelCredentials.insecure()));
  final client = SpeechServiceClient(channel,
      options: CallOptions(timeout: const Duration(seconds: 30)));

  TranscribeRequest req() => TranscribeRequest()
    ..audio = audio
    ..format = (AudioFormat()
      ..sampleRateHz = 16000
      ..encoding = 'pcm_f32le')
    ..enablePostprocess = true;

  for (var call = 1; call <= 2; call++) {
    final sw = Stopwatch()..start();
    final resp = await client.transcribe(req());
    sw.stop();
    stdout.writeln('[smoke] call#$call ${sw.elapsedMilliseconds}ms '
        'success=${resp.success} transcript=[${resp.transcript.trim()}]');
  }

  await channel.shutdown();
}
