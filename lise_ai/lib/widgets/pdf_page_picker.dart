import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/pdf_service.dart';

/// Opens the PDF page picker dialog.
/// Returns [null] if cancelled, or a list of high-res PNG page bytes.
Future<List<Uint8List>?> showPdfPagePicker(
  BuildContext context,
  PdfService pdf,
) {
  return showDialog<List<Uint8List>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PdfPagePickerDialog(pdf: pdf),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _PdfPagePickerDialog extends StatefulWidget {
  final PdfService pdf;
  const _PdfPagePickerDialog({required this.pdf});

  @override
  State<_PdfPagePickerDialog> createState() => _PdfPagePickerDialogState();
}

class _PdfPagePickerDialogState extends State<_PdfPagePickerDialog> {
  // Thumbnail cache (low-res, for display)
  final _thumbs = <int, Uint8List?>{};
  // Page numbers currently loading
  final _loading = <int>{};
  // Selected page numbers (1-indexed)
  final _selected = <int>{};

  bool _confirming = false;

  static const int _maxSelect = 5;

  @override
  void initState() {
    super.initState();
    _loadThumbnailRange(1, _visiblePageCount);
  }

  int get _total => widget.pdf.pageCount;
  int get _visiblePageCount => _total.clamp(0, 20); // show at most 20 pages

  void _loadThumbnailRange(int from, int to) {
    for (int p = from; p <= to; p++) {
      if (!_thumbs.containsKey(p) && !_loading.contains(p)) {
        _loading.add(p);
        widget.pdf.renderPage(p, scale: 0.8).then((bytes) {
          if (!mounted) return;
          setState(() {
            _thumbs[p] = bytes;
            _loading.remove(p);
          });
        });
      }
    }
  }

  void _togglePage(int p) {
    setState(() {
      if (_selected.contains(p)) {
        _selected.remove(p);
      } else if (_selected.length < _maxSelect) {
        _selected.add(p);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _confirming) return;
    setState(() => _confirming = true);

    // Render selected pages at high res
    final pages = <Uint8List>[];
    final sorted = _selected.toList()..sort();
    for (final p in sorted) {
      final bytes = await widget.pdf.renderPage(p, scale: 2.0);
      if (bytes != null) pages.add(bytes);
    }

    if (mounted) Navigator.of(context).pop(pages);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 640,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFF1F2937)),
            Expanded(child: _buildGrid()),
            const Divider(height: 1, color: Color(0xFF1F2937)),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2035),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFEF4444), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pdf.filename,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_total} sayfa • En fazla $_maxSelect sayfa seçebilirsiniz',
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(null),
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF6B7280), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: _visiblePageCount,
      itemBuilder: (_, i) {
        final pageNum = i + 1;
        return _PageThumb(
          pageNum: pageNum,
          thumbBytes: _thumbs[pageNum],
          isLoading: _loading.contains(pageNum),
          isSelected: _selected.contains(pageNum),
          canSelect: _selected.length < _maxSelect,
          onTap: () => _togglePage(pageNum),
        );
      },
    );
  }

  Widget _buildFooter() {
    final count = _selected.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(
            count == 0
                ? 'Sayfa seçin'
                : '$count sayfa seçildi',
            style: TextStyle(
              color: count > 0
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('İptal',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: (count > 0 && !_confirming) ? _confirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C6BF8),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF3A3A3A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: _confirming
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Çöz →',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Individual page thumbnail ─────────────────────────────────────────────────

class _PageThumb extends StatelessWidget {
  final int pageNum;
  final Uint8List? thumbBytes;
  final bool isLoading;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;

  const _PageThumb({
    required this.pageNum,
    required this.thumbBytes,
    required this.isLoading,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !isSelected && !canSelect;

    return GestureDetector(
      onTap: (isSelected || canSelect) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4ADE80)
                : const Color(0xFF2D3748),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            children: [
              // Thumbnail image or placeholder
              Positioned.fill(
                child: isLoading || thumbBytes == null
                    ? Container(
                        color: const Color(0xFF1E2035),
                        child: isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.broken_image_outlined,
                                    color: Color(0xFF4B5563), size: 24),
                              ),
                      )
                    : Image.memory(thumbBytes!, fit: BoxFit.cover),
              ),
              // Dim overlay when selection limit reached
              if (dimmed)
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              // Selected checkmark
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.black, size: 14),
                  ),
                ),
              // Page number badge
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    'Sayfa $pageNum',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
