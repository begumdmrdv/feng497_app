import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class ReportPreviewScreen extends StatefulWidget {
  final Future<Uint8List> pdfFuture;
  final String fileName;

  const ReportPreviewScreen({
    super.key,
    required this.pdfFuture,
    required this.fileName,
  });

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  Uint8List? _pdfBytes;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await widget.pdfFuture;
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text("Report Preview", style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loadPdf,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: "Share",
            onPressed: (_pdfBytes == null)
                ? null
                : () async {
              try {
                await Printing.sharePdf(bytes: _pdfBytes!, filename: widget.fileName);
              } catch (_) {
                _showSnack("Could not share the PDF.");
              }
            },
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: "Print",
            onPressed: (_pdfBytes == null)
                ? null
                : () async {
              try {
                await Printing.layoutPdf(onLayout: (_) async => _pdfBytes!);
              } catch (_) {
                _showSnack("Could not open print dialog.");
              }
            },
            icon: const Icon(Icons.print_rounded),
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? _ErrorState(
        errorText: "PDF generation failed.\n$_error",
        onRetry: _loadPdf,
      )
          : PdfPreview(
        maxPageWidth: 760,
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: widget.fileName,

        // ✅ We already resolved bytes; avoid re-running the future repeatedly
        build: (_) async => _pdfBytes!,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String errorText;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.errorText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7B3FF2);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 8),
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
              const SizedBox(height: 10),
              const Text(
                "Something went wrong",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                errorText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Retry", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
