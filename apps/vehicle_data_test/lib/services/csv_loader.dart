import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CsvTable {
  CsvTable(
    this.headers,
    this.rows, {
    this.fileName,
    this.rawFirstLine,
  });

  final List<String> headers;
  final List<List<dynamic>> rows;
  final String? rawFirstLine;  // ← "# StartTime = ..."
  final String? fileName;
}

class CsvLoader {
  // 헤더 정규화: 공백 여러 개 → 하나
  static String _canonHeader(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// 파일 선택 → 파싱 → CsvTable
  static Future<CsvTable?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null) return null;

    final f = result.files.single;
    final fileName = f.name;

    final bytes = f.bytes ?? await File(f.path!).readAsBytes();
    String text = utf8.decode(bytes);

    // 1) BOM 제거
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }

    // 2) EOL 통일
    text = text.replaceAll(RegExp(r'\r\n?'), '\n');

    // 3) 첫 라인 따로 뽑기 (주석일 수도 있으니까)
    final lines = const LineSplitter().convert(text);
    String? rawFirstLine;
    final normalizedLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) continue;

      // 첫 번째 주석 라인은 살려두고, 나머지 주석은 버릴 수 있음
      if (trimmed.startsWith('#')) {
        rawFirstLine ??= trimmed; // 첫 주석만 저장
        // 주석은 CSV로는 안 내려보냄
        continue;
      }

      normalizedLines.add(trimmed);
    }

    // 이제 CSV로 파싱할 문자열
    final normalized = normalizedLines.join('\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);

    if (rows.isEmpty) {
      return CsvTable(const [], const [],
          fileName: fileName, rawFirstLine: rawFirstLine);
    }

    final rawHeader = rows.first.map((e) => (e ?? '').toString()).toList();
    final header = rawHeader.map(_canonHeader).toList();
    final dataRows = rows.length > 1 ? rows.sublist(1) : <List<dynamic>>[];

    return CsvTable(
      header,
      dataRows,
      fileName: fileName,
      rawFirstLine: rawFirstLine, // ← 이제 여기로 들어감
    );
  }
}
