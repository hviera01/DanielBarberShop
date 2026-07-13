import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/producto_model.dart';
import '../../providers/productos_provider.dart';
import '../../../categorias/providers/categorias_provider.dart';
import '../../../../core/utils/texto_utils.dart';
import '../../../../core/utils/formato_moneda.dart';
import '../widgets/producto_form_dialog.dart';
import '../widgets/ajuste_stock_dialog.dart';
import '../widgets/historial_stock_dialog.dart';
import '../widgets/historial_movimientos_dialog.dart';

class InventarioScreen extends ConsumerStatefulWidget {
  const InventarioScreen({super.key});

  @override
  ConsumerState<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends ConsumerState<InventarioScreen> {
  final _busquedaController = TextEditingController();
  String? _filaSeleccionada;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _buscar() {
    ref.read(inventarioBusquedaProvider.notifier).actualizar(_busquedaController.text.trim());
  }

  void _limpiarBusqueda() {
    _busquedaController.clear();
    ref.read(inventarioBusquedaProvider.notifier).actualizar('');
    setState(() => _filaSeleccionada = null);
  }

  void _abrirFormulario([ProductoModel? producto]) {
    showDialog(context: context, builder: (context) => ProductoFormDialog(producto: producto));
  }

  void _abrirAjusteStock(ProductoModel producto) {
    showDialog(context: context, builder: (context) => AjusteStockDialog(producto: producto));
  }

  void _abrirHistorial(ProductoModel producto) {
    showDialog(context: context, builder: (context) => HistorialStockDialog(producto: producto));
  }

  void _abrirHistorialMovimientos(ProductoModel producto, String tipo) {
    showDialog(context: context, builder: (context) => HistorialMovimientosDialog(producto: producto, tipo: tipo));
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosStreamProvider);
    final categoriasAsync = ref.watch(categoriasStreamProvider);
    final busqueda = ref.watch(inventarioBusquedaProvider);
    final vista = ref.watch(inventarioVistaProvider);

    return Container(
      color: const Color(0xFFF2F3F7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final esMovil = constraints.maxWidth < 720;
          return Padding(
            padding: EdgeInsets.all(esMovil ? 14 : 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Text('Inventario', style: GoogleFonts.poppins(fontSize: esMovil ? 19 : 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A1A))),
                    productosAsync.when(
                      data: (productos) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFC62828).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text('${productos.length} productos', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFC62828))),
                      ),
                      loading: () => const SizedBox(),
                      error: (e, st) => const SizedBox(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: esMovil ? constraints.maxWidth : 220, child: _selectorVista(vista)),
                    SizedBox(width: esMovil ? constraints.maxWidth : 340, child: _buscador(busqueda)),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(productosStreamProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text('Refrescar', style: GoogleFonts.poppins(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1A1A),
                        side: const BorderSide(color: Color(0xFFDCDFE6)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _abrirFormulario(),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Nuevo Producto', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCDD1DA), width: 1.3),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 26, offset: const Offset(0, 12))],
                    ),
                    child: productosAsync.when(
                      data: (productos) {
                        final categorias = categoriasAsync.value ?? [];
                        final mapaCategorias = {for (final c in categorias) c.id: c.descripcion};

                        var lista = productos;
                        if (vista == 'bajo') {
                          lista = lista.where((p) => p.stock < 3).toList();
                        } else if (vista == 'filtrados') {
                          lista = busqueda.isEmpty
                              ? []
                              : lista
                                  .where(
                                    (p) => coincideFuzzy(
                                      p.textoBusqueda,
                                      busqueda,
                                    ),
                                  )
                                  .toList();
                        }

                        if (lista.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 56,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  vista == 'filtrados' && busqueda.isEmpty
                                      ? 'Escribí algo y presioná buscar'
                                      : 'No hay productos encontrados',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                                                return _tabla(
                          lista,
                          mapaCategorias,
                          constraints.maxWidth,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC62828))),
                      error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.red))),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

   
      Widget _tabla(
    List<ProductoModel> lista,
    Map<String, String> mapaCategorias,
    double anchoDisponible,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final mostrarDescripcion = ancho >= 1050;
        final mostrarCategoria = ancho >= 850;

        return Column(
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFECEEF3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _celdaHeader(
                    texto: 'CÓDIGO',
                    flex: 12,
                  ),
                  _celdaHeader(
                    texto: 'NOMBRE',
                    flex: 24,
                  ),
                  if (mostrarDescripcion)
                    _celdaHeader(
                      texto: 'DESCRIPCIÓN',
                      flex: 20,
                    ),
                  if (mostrarCategoria)
                    _celdaHeader(
                      texto: 'CATEGORÍA',
                      flex: 17,
                    ),
                  _celdaHeader(
                    texto: 'EXISTENCIA',
                    flex: 12,
                  ),
                  _celdaHeader(
                    texto: 'P. VENTA',
                    flex: 14,
                  ),
                  _celdaHeader(
                    texto: 'P. COMPRA',
                    flex: 14,
                  ),
                  _celdaHeader(
                    texto: 'ESTADO',
                    flex: 11,
                  ),
                  _celdaHeaderAcciones(),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: lista.length,
                separatorBuilder: (context, index) {
                  return Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade200,
                  );
                },
                itemBuilder: (context, index) {
                  final producto = lista[index];
                  final bajoStock = producto.stock < 3;
                  final seleccionada =
                      _filaSeleccionada == producto.id;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _filaSeleccionada =
                            seleccionada ? null : producto.id;
                      });
                    },
                    child: Container(
                      height: 72,
                      color: seleccionada
                          ? const Color(0xFFFBEAEA)
                          : Colors.white,
                      child: Row(
                        children: [
                          _celdaTabla(
                            flex: 12,
                            child: Text(
                              producto.codigo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: const Color(0xFF3F434A),
                              ),
                            ),
                          ),
                          _celdaTabla(
                            flex: 24,
                            child: Text(
                              producto.nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          if (mostrarDescripcion)
                            _celdaTabla(
                              flex: 20,
                              child: Text(
                                producto.descripcion.isEmpty
                                    ? '-'
                                    : producto.descripcion,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          if (mostrarCategoria)
                            _celdaTabla(
                              flex: 17,
                              child: Text(
                                mapaCategorias[
                                        producto.idCategoria] ??
                                    '-',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: const Color(0xFF3F434A),
                                ),
                              ),
                            ),
                          _celdaTabla(
                            flex: 12,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: bajoStock
                                      ? const Color(0xFFFCE4E4)
                                      : const Color(0xFFEFF4FF),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  producto.stock.toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: bajoStock
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _celdaTabla(
                            flex: 14,
                            child: Text(
                              formatearMoneda(
                                producto.precioVenta,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: const Color(0xFF3F434A),
                              ),
                            ),
                          ),
                          _celdaTabla(
                            flex: 14,
                            child: Text(
                              formatearMoneda(
                                producto.precioCompra,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: const Color(0xFF3F434A),
                              ),
                            ),
                          ),
                          _celdaTabla(
                            flex: 11,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: producto.estado
                                      ? const Color(0xFFE8F8EE)
                                      : Colors.grey.shade200,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Text(
                                  producto.estado
                                      ? 'Activo'
                                      : 'Inactivo',
                                  maxLines: 1,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: producto.estado
                                        ? const Color(0xFF16A34A)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _celdaAcciones(producto),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
      Widget _celdaHeader({
    required String texto,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Color(0xFFD6D9E0),
              width: 1,
            ),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666A72),
            letterSpacing: 0.35,
          ),
        ),
      ),
    );
  }

  Widget _celdaHeaderAcciones() {
    return Container(
      width: 76,
      height: double.infinity,
      alignment: Alignment.center,
      child: Text(
        'ACCIONES',
        maxLines: 1,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF666A72),
          letterSpacing: 0.25,
        ),
      ),
    );
  }

  Widget _celdaTabla({
    required int flex,
    required Widget child,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Color(0xFFE5E7EC),
              width: 1,
            ),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _celdaAcciones(ProductoModel producto) {
    return Container(
      width: 76,
      height: double.infinity,
      alignment: Alignment.center,
      child: PopupMenuButton<String>(
        tooltip: 'Más acciones',
        padding: EdgeInsets.zero,
        icon: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: const Color(0xFFDFE1E6),
            ),
          ),
          child: const Icon(
            Icons.more_vert,
            size: 21,
            color: Color(0xFF454950),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
        position: PopupMenuPosition.under,
        onSelected: (valor) {
          switch (valor) {
            case 'editar':
              _abrirFormulario(producto);
              break;
            case 'ajustar':
              _abrirAjusteStock(producto);
              break;
            case 'historial_stock':
              _abrirHistorial(producto);
              break;
            case 'historial_ventas':
              _abrirHistorialMovimientos(
                producto,
                'ventas',
              );
              break;
            case 'historial_compras':
              _abrirHistorialMovimientos(
                producto,
                'compras',
              );
              break;
          }
        },
        itemBuilder: (context) {
          return [
            _opcionMenu(
              valor: 'editar',
              icono: Icons.edit_outlined,
              texto: 'Editar producto',
            ),
            _opcionMenu(
              valor: 'ajustar',
              icono: Icons.tune,
              texto: 'Ajustar existencia',
            ),
            const PopupMenuDivider(),
            _opcionMenu(
              valor: 'historial_stock',
              icono: Icons.history,
              texto: 'Historial de existencia',
            ),
            _opcionMenu(
              valor: 'historial_ventas',
              icono: Icons.point_of_sale_outlined,
              texto: 'Historial de ventas',
            ),
            _opcionMenu(
              valor: 'historial_compras',
              icono: Icons.shopping_cart_outlined,
              texto: 'Historial de compras',
            ),
          ];
        },
      ),
    );
  }

  PopupMenuItem<String> _opcionMenu({
    required String valor,
    required IconData icono,
    required String texto,
  }) {
    return PopupMenuItem<String>(
      value: valor,
      height: 44,
      child: Row(
        children: [
          Icon(
            icono,
            size: 19,
            color: const Color(0xFF4B4F58),
          ),
          const SizedBox(width: 12),
          Text(
            texto,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF25272B),
            ),
          ),
        ],
      ),
    );
  }


  Widget _selectorVista(String vista) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDCDFE6))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: vista,
          isExpanded: true,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF1A1A1A)),
          items: const [
            DropdownMenuItem(value: 'filtrados', child: Text('Productos filtrados')),
            DropdownMenuItem(value: 'todos', child: Text('Mostrar todos')),
            DropdownMenuItem(value: 'bajo', child: Text('Bajo existencia')),
          ],
          onChanged: (v) {
            if (v == null) return;
            ref.read(inventarioVistaProvider.notifier).actualizar(v);
          },
        ),
      ),
    );
  }

  Widget _buscador(String busqueda) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDCDFE6))),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _busquedaController,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar producto, código o código de barras...',
                hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade400),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _buscar(),
            ),
          ),
          if (busqueda.isNotEmpty)
            IconButton(tooltip: 'Limpiar', icon: const Icon(Icons.close, size: 18), onPressed: _limpiarBusqueda),
          IconButton(tooltip: 'Buscar', icon: const Icon(Icons.arrow_forward, size: 18), onPressed: _buscar),
        ],
      ),
    );
  }
}