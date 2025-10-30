import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CsvTable {
  CsvTable(this.headers, this.rows, {this.fileName});
  final List<String> headers;         // 첫 줄 헤더(정규화 적용)
  final List<List<dynamic>> rows;     // 데이터 행들
  final String? fileName;
}

class CsvLoader {
  static String _normalize(String text) {
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1); // BOM 제거
    }
    text = text.replaceAll(RegExp(r'\r\n?'), '\n'); // EOL 통일
    final out = <String>[];
    for (final line in const LineSplitter().convert(text)) {
      final t = line.trimRight();
      if (t.isEmpty) continue;
      if (t.startsWith('#')) continue; // 코멘트 제거
      out.add(t);
    }
    return out.join('\n');
  }

  static String _canonHeader(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// 파일 선택 → 파싱 → CsvTable 반환 (취소 시 null)
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
    final text = utf8.decode(bytes);

    final normalized = _normalize(text);
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    if (rows.isEmpty) return CsvTable(const [], const []);

    final rawHeader = rows.first.map((e) => (e ?? '').toString()).toList();
    final header = rawHeader.map(_canonHeader).toList();
    final dataRows = rows.length > 1 ? rows.sublist(1) : <List<dynamic>>[];

    return CsvTable(header, dataRows, fileName: fileName);
  }
}
