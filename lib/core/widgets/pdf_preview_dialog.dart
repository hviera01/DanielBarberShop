import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

class PdfPreviewDialog extends StatefulWidget {
  final String titulo;
  final Future<Uint8List> Function() generarPdf;
  final String nombreArchivo;
  final Printer? impresora;

  const PdfPreviewDialog({super.key, required this.titulo, required this.generarPdf, required this.nombreArchivo, this.impresora});

  @override
  State<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<PdfPreviewDialog> {
  bool _imprimiendo = false;

  Future<void> _imprimirDirecto() async {
    final impresora = widget.impresora;
    if (impresora == null) return;
    setState(() => _imprimiendo = true);
    try {
      await Printing.directPrintPdf(printer: impresora, onLayout: (format) => widget.generarPdf());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo imprimir en la impresora configurada')));
      }
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.of(context).size;
    final anchoDialog = tamano.width < 760 ? tamano.width - 24 : 640.0;
    final altoDialog = tamano.height < 700 ? tamano.height - 60 : 720.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: anchoDialog,
        height: altoDialog,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.titulo, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            if (widget.impresora != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _imprimiendo ? null : _imprimirDirecto,
                  icon: _imprimiendo
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print_outlined, size: 18),
                  label: Text(
                    _imprimiendo ? 'Imprimiendo...' : 'Imprimir en ${widget.impresora!.name}',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PdfPreview(
                  build: (format) => widget.generarPdf(),
                  pdfFileName: widget.nombreArchivo,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  allowPrinting: true,
                  allowSharing: true,
                  useActions: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
