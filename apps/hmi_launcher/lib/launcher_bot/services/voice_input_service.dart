import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

class VoiceInputException implements Exception {
  const VoiceInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CapturedVoiceInput {
  const CapturedVoiceInput({
    required this.pcm,
    required this.sampleRate,
    required this.channels,
    required this.wavPath,
    required this.durationSeconds,
    required this.peakAmplitude,
    required this.rmsAmplitude,
    required this.silentFrameRatio,
  });

  final Float32List pcm;
  final int sampleRate;
  final int channels;
  final String wavPath;
  final double durationSeconds;
  final double peakAmplitude;
  final double rmsAmplitude;
  final double silentFrameRatio;

  String get debugSummary => 'duration=${durationSeconds.toStringAsFixed(2)}s '
      'peak=${peakAmplitude.toStringAsFixed(4)} '
      'rms=${rmsAmplitude.toStringAsFixed(4)} '
      'silent=${(silentFrameRatio * 100).toStringAsFixed(1)}%';
}

class VoiceInputService {
  const VoiceInputService({
    this.duration = const Duration(seconds: 10),
    this.sampleRate = 16000,
  });

  final Duration duration;
  final int sampleRate;

  Future<CapturedVoiceInput> capture() async {
    final session = await startCapture();
    return session.result;
  }

  Future<VoiceCaptureSession> startCapture() async {
    await _ensureAudioInputAvailable();

    final file = File(
      '${Directory.systemTemp.path}/hmi_launcher_voice_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    final device = Platform.environment['LAUNCHER_BOT_AUDIO_DEVICE'];
    final args = <String>[
      if (device != null && device.isNotEmpty) ...['-D', device],
      '-q',
      '-f',
      'S16_LE',
      '-r',
      '$sampleRate',
      '-c',
      '1',
      '-d',
      '${duration.inSeconds}',
      file.path,
    ];

    final Process process;
    try {
      process = await Process.start('arecord', args);
    } on ProcessException {
      throw const VoiceInputException(
        '오디오 녹음 도구(arecord)를 찾을 수 없습니다.',
      );
    }

    return VoiceCaptureSession._(process: process, file: file);
  }

  Future<void> _ensureAudioInputAvailable() async {
    final ProcessResult result;
    try {
      result = await Process.run('arecord', const ['-l']);
    } on ProcessException {
      throw const VoiceInputException(
        '오디오 녹음 도구(arecord)를 찾을 수 없습니다.',
      );
    }
    if (result.exitCode != 0) {
      final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
      if (output.contains('no soundcards') ||
          output.contains('no soundcard') ||
          output.contains('no such file or directory')) {
        throw const VoiceInputException('인식된 오디오 입력 장치가 없습니다.');
      }
      throw VoiceInputException(
        '오디오 입력 장치를 확인할 수 없습니다. ${_processMessage(result)}',
      );
    }

    final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (!output.contains('card ') && !output.contains('카드 ')) {
      throw const VoiceInputException('인식된 오디오 입력 장치가 없습니다.');
    }
  }

  String _processMessage(ProcessResult result) {
    final text = '${result.stderr}'.trim().isNotEmpty
        ? '${result.stderr}'.trim()
        : '${result.stdout}'.trim();
    return text.isEmpty ? '' : text;
  }
}

class VoiceCaptureSession {
  VoiceCaptureSession._({
    required Process process,
    required File file,
  })  : _process = process,
        _file = file {
    _result = _finish();
  }

  final Process _process;
  final File _file;
  late final Future<CapturedVoiceInput> _result;
  bool _stopRequested = false;

  Future<CapturedVoiceInput> get result => _result;

  void stop() {
    if (_stopRequested) return;
    _stopRequested = true;
    _process.kill(ProcessSignal.sigint);
  }

  Future<CapturedVoiceInput> _finish() async {
    final exitCode = await _process.exitCode;
    if (!await _file.exists()) {
      throw VoiceInputException(
        '마이크 녹음 파일을 찾을 수 없습니다. exitCode=$exitCode',
      );
    }

    final bytes = await _file.readAsBytes();
    _logVoice(
      'recorded wav=${_file.path} exitCode=$exitCode bytes=${bytes.length}',
    );
    try {
      if (bytes.length <= 44) {
        throw VoiceInputException(
          '녹음된 음성 데이터가 너무 짧습니다. exitCode=$exitCode',
        );
      }
      return _decodeWavPcm(ByteData.sublistView(bytes), wavPath: _file.path);
    } finally {
      final keepAudio = Platform.environment['LAUNCHER_BOT_KEEP_AUDIO'] != '0';
      if (!keepAudio && await _file.exists()) {
        await _file.delete();
      }
    }
  }
}

CapturedVoiceInput _decodeWavPcm(ByteData data, {required String wavPath}) {
  String fourCc(int offset) {
    return String.fromCharCodes([
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
      data.getUint8(offset + 3),
    ]);
  }

  if (data.lengthInBytes < 44 || fourCc(0) != 'RIFF' || fourCc(8) != 'WAVE') {
    throw const VoiceInputException('지원하지 않는 WAV 파일입니다.');
  }

  int? audioFormat;
  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  int? dataOffset;
  int? dataSize;

  var offset = 12;
  while (offset + 8 <= data.lengthInBytes) {
    final chunkId = fourCc(offset);
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkDataOffset = offset + 8;

    if (chunkId == 'fmt ') {
      audioFormat = data.getUint16(chunkDataOffset, Endian.little);
      channels = data.getUint16(chunkDataOffset + 2, Endian.little);
      sampleRate = data.getUint32(chunkDataOffset + 4, Endian.little);
      bitsPerSample = data.getUint16(chunkDataOffset + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = chunkDataOffset;
      dataSize = chunkSize;
    }

    offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  if (audioFormat == null ||
      channels == null ||
      sampleRate == null ||
      bitsPerSample == null ||
      dataOffset == null ||
      dataSize == null) {
    throw const VoiceInputException('WAV fmt/data chunk를 찾을 수 없습니다.');
  }

  if (audioFormat != 1 || bitsPerSample != 16) {
    throw VoiceInputException(
      'PCM 16-bit WAV만 지원합니다. format=$audioFormat bits=$bitsPerSample',
    );
  }

  final frameCount = dataSize ~/ (channels * 2);
  final pcm = Float32List(frameCount);
  var cursor = dataOffset;
  var peak = 0.0;
  var squareSum = 0.0;
  var silentFrames = 0;
  for (var frame = 0; frame < frameCount; frame += 1) {
    var sum = 0.0;
    for (var channel = 0; channel < channels; channel += 1) {
      sum += data.getInt16(cursor, Endian.little) / 32768.0;
      cursor += 2;
    }
    final sample = sum / channels;
    final absSample = sample.abs();
    if (absSample > peak) peak = absSample;
    squareSum += sample * sample;
    if (absSample < 0.005) silentFrames += 1;
    pcm[frame] = sample;
  }

  final durationSeconds = frameCount / sampleRate;
  final rms = frameCount == 0 ? 0.0 : math.sqrt(squareSum / frameCount);
  final silentFrameRatio = frameCount == 0 ? 1.0 : silentFrames / frameCount;
  _logVoice(
    'decoded wav=$wavPath sampleRate=$sampleRate channelsIn=$channels '
    'bits=$bitsPerSample frames=$frameCount '
    'duration=${durationSeconds.toStringAsFixed(2)}s '
    'peak=${peak.toStringAsFixed(4)} rms=${rms.toStringAsFixed(4)} '
    'silent=${(silentFrameRatio * 100).toStringAsFixed(1)}%',
  );
  if (peak < 0.02 || rms < 0.003 || silentFrameRatio > 0.95) {
    _logVoice(
      'warning low/quiet input detected. Check capture device, mic gain, '
      'or whether speech was recorded.',
    );
  }

  return CapturedVoiceInput(
    pcm: pcm,
    sampleRate: sampleRate,
    channels: 1,
    wavPath: wavPath,
    durationSeconds: durationSeconds,
    peakAmplitude: peak,
    rmsAmplitude: rms,
    silentFrameRatio: silentFrameRatio,
  );
}

void _logVoice(String message) {
  stderr.writeln('[launcher_bot_voice] $message');
}
