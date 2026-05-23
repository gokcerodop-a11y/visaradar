import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

/// Wraps pdfx for PDF loading and page rendering.
/// Pages are 1-indexed.
class PdfService {
  final String tempPath; // copy in system temp (sandbox-safe)
  final String filename;
  final int pageCount;

  PdfDocument? _doc;

  PdfService._({
    required this.tempPath,
    required this.filename,
    required this.pageCount,
    required PdfDocument doc,
  }) : _doc = doc;

  /// Open a PDF from raw [bytes]. Copies to temp dir for sandbox-safe access.
  static Future<PdfService?> fromBytes(Uint8List bytes, String filename) async {
    try {
      final tempPath =
          '${Directory.systemTemp.path}/lise_ai_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(tempPath).writeAsBytes(bytes, flush: true);
      final doc = await PdfDocument.openFile(tempPath);
      debugPrint('[PDF] Opened "$filename" — ${doc.pagesCount} pages');
      return PdfService._(
        tempPath: tempPath,
        filename: filename,
        pageCount: doc.pagesCount,
        doc: doc,
      );
    } catch (e) {
      debugPrint('[PDF] Open failed: $e');
      return null;
    }
  }

  /// Render [pageNumber] (1-indexed) and return PNG bytes.
  /// [scale] controls resolution: 1.5 ≈ thumbnail, 2.5 ≈ high-res for AI.
  Future<Uint8List?> renderPage(int pageNumber, {double scale = 1.5}) async {
    if (_doc == null) return null;
    try {
      final page = await _doc!.getPage(pageNumber);
      final image = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      return image?.bytes;
    } catch (e) {
      debugPrint('[PDF] Render page $pageNumber failed: $e');
      return null;
    }
  }

  Future<void> close() async {
    await _doc?.close();
    _doc = null;
    try {
      await File(tempPath).delete();
    } catch (_) {}
  }
}
