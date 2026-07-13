import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/producto_model.dart';
import '../../providers/productos_provider.dart';

class HistorialStockDialog extends ConsumerWidget {
  final ProductoModel producto;

  const HistorialStockDialog({super.key, required this.producto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialStream = ref.watch(productoRepositoryProvider).obtenerHistorialStock(producto.id);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        height: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Historial de Existencia · ${producto.nombre}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder(
                stream: historialStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFC62828)));
                  final registros = snapshot.data!;
                  if (registros.isEmpty) {
                    return Center(child: Text('Sin movimientos registrados', style: GoogleFonts.poppins(color: Colors.grey.shade500)));
                  }
                  return ListView.separated(
                    itemCount: registros.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final r = registros[index];
                      final subio = r.stockNuevo >= r.stockAnterior;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: (subio ? const Color(0xFF16A34A) : const Color(0xFFC62828)).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(subio ? Icons.trending_up : Icons.trending_down, size: 18, color: subio ? const Color(0xFF16A34A) : const Color(0xFFC62828)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${r.stockAnterior} → ${r.stockNuevo}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (r.motivo.isNotEmpty)
                                    Text(r.motivo, style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade600)),
                                  Text(r.usuario, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Text(
                              r.fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(r.fecha!) : '',
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}