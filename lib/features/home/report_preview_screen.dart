import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class ReportPreviewScreen extends StatelessWidget {
  final Future<Uint8List> pdfFuture;
  final String fileName;

  const ReportPreviewScreen({
    super.key,
    required this.pdfFuture,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Preview"),
        backgroundColor: const Color(0xFF7B3FF2),
      ),
      body: PdfPreview(
        build: (format) => pdfFuture,
        canChangePageFormat: false,
        canChangeOrientation: false,
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.download_rounded),
            onPressed: (context, build, pageFormat) async {
              final bytes = await pdfFuture;
              await Printing.sharePdf(bytes: bytes, filename: fileName);
            },
          ),
        ],
      ),
    );
  }
}
