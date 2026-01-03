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
        backgroundColor: const Color(0xFF7B3FF2),
        elevation: 0,
        title: const Text("Report Preview", style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: PdfPreview(

        maxPageWidth: 760,

        canChangeOrientation: false,
        canChangePageFormat: false,

        allowPrinting: true,
        allowSharing: true,
        pdfFileName: fileName,

        build: (_) async => await pdfFuture,
      ),
    );
  }
}
