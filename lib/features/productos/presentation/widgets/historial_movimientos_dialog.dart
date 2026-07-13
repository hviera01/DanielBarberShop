import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/producto_model.dart';

class HistorialMovimientosDialog extends StatelessWidget {
  final ProductoModel producto;
  final String tipo;

  const HistorialMovimientosDialog({super.key, required this.producto, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final titulo = tipo == 'ventas' ? 'Historial de Ventas' : 'Historial de Compras';
    final icono = tipo == 'ventas' ? Icons.point_of_sale_outlined : Icons.shopping_cart_outlined;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$titulo · ${producto.nombre}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 30),
            Icon(icono, size: 54, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              'Todavía no hay movimientos',
              style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              'Este historial se completa automáticamente cuando el módulo de ${tipo == 'ventas' ? 'Ventas' : 'Compras'} esté conectado',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}