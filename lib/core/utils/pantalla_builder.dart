import 'package:flutter/material.dart';
import '../widgets/placeholder_screen.dart';
import '../../features/categorias/presentation/screens/categorias_screen.dart';
import '../../features/productos/presentation/screens/inventario_screen.dart';

Widget construirPantalla(String moduleKey, String titulo, IconData icono) {
  switch (moduleKey) {
    case 'categorias':
      return const CategoriasScreen();
    case 'inventario':
      return const InventarioScreen();
    default:
      return PlaceholderScreen(titulo: titulo, icono: icono);
  }
}