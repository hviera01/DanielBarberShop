import 'package:flutter/material.dart';
import '../constants/roles.dart';

class SubModulo {
  final String titulo;
  final IconData icono;
  final String moduleKey;
  // Qué roles ven este submódulo en el menú (ver SideMenu). Por default,
  // Administrador y Empleado (el comportamiento de siempre); los que antes
  // eran `soloAdmin: true` ahora listan solo Roles.administrador. Un
  // usuario con rol Barbero solo ve lo que liste Roles.barbero
  // explícitamente (Agenda de Citas y Comisiones, filtradas a lo suyo).
  final List<String> roles;

  SubModulo({
    required this.titulo,
    required this.icono,
    required this.moduleKey,
    this.roles = const [Roles.administrador, Roles.empleado],
  });
}

class ModuloMenu {
  final String titulo;
  final IconData icono;
  final Color color;
  final List<SubModulo> subModulos;

  ModuloMenu({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.subModulos,
  });
}

List<ModuloMenu> obtenerModulos() {
  return [
    ModuloMenu(
      titulo: 'Usuarios',
      icono: Icons.people_alt_outlined,
      color: const Color(0xFF0F1B3D),
      subModulos: [
        SubModulo(titulo: 'Usuarios', icono: Icons.people_alt_outlined, moduleKey: 'usuarios', roles: const [Roles.administrador]),
      ],
    ),
    ModuloMenu(
      titulo: 'Mantenedor',
      icono: Icons.settings_outlined,
      color: const Color(0xFF0EA5A4),
      subModulos: [
        SubModulo(titulo: 'Categorías', icono: Icons.category_outlined, moduleKey: 'categorias', roles: const [Roles.administrador]),
        SubModulo(titulo: 'Inventario', icono: Icons.inventory_2_outlined, moduleKey: 'inventario', roles: const [Roles.administrador]),
        SubModulo(titulo: 'Negocio', icono: Icons.store_outlined, moduleKey: 'negocio', roles: const [Roles.administrador]),
        SubModulo(titulo: 'Dispositivos', icono: Icons.devices_outlined, moduleKey: 'dispositivos', roles: const [Roles.administrador]),
      ],
    ),
    ModuloMenu(
      titulo: 'Ventas',
      icono: Icons.point_of_sale_outlined,
      color: const Color(0xFF22C55E),
      subModulos: [
        SubModulo(titulo: 'Registrar Venta', icono: Icons.add_shopping_cart_outlined, moduleKey: 'ventas_registrar'),
        SubModulo(titulo: 'Ver Detalle', icono: Icons.receipt_long_outlined, moduleKey: 'ventas_detalle'),
      ],
    ),
    ModuloMenu(
      titulo: 'Compras',
      icono: Icons.shopping_cart_outlined,
      color: const Color(0xFFF59E0B),
      subModulos: [
        SubModulo(titulo: 'Registrar Compra', icono: Icons.add_box_outlined, moduleKey: 'compras_registrar'),
        SubModulo(titulo: 'Ver Detalle', icono: Icons.receipt_long_outlined, moduleKey: 'compras_detalle'),
        SubModulo(titulo: 'Hacer Pedido', icono: Icons.local_shipping_outlined, moduleKey: 'compras_pedido', roles: const [Roles.administrador]),
      ],
    ),
    ModuloMenu(
      titulo: 'Clientes',
      icono: Icons.groups_outlined,
      color: const Color(0xFF3B82F6),
      subModulos: [
        SubModulo(titulo: 'Clientes', icono: Icons.groups_outlined, moduleKey: 'clientes'),
      ],
    ),
    ModuloMenu(
      titulo: 'Proveedores',
      icono: Icons.local_shipping_outlined,
      color: const Color(0xFF8B5CF6),
      subModulos: [
        SubModulo(titulo: 'Proveedores', icono: Icons.local_shipping_outlined, moduleKey: 'proveedores'),
      ],
    ),
    ModuloMenu(
      titulo: 'Barberos',
      icono: Icons.content_cut_outlined,
      color: const Color(0xFF0F1B3D),
      subModulos: [
        SubModulo(titulo: 'Barberos', icono: Icons.content_cut_outlined, moduleKey: 'barberos', roles: const [Roles.administrador]),
      ],
    ),
    ModuloMenu(
      titulo: 'Citas',
      icono: Icons.event_outlined,
      color: const Color(0xFF14B8A6),
      subModulos: [
        SubModulo(titulo: 'Agenda de Citas', icono: Icons.event_outlined, moduleKey: 'agenda', roles: const [Roles.administrador, Roles.empleado, Roles.barbero]),
      ],
    ),
    ModuloMenu(
      titulo: 'Créditos',
      icono: Icons.credit_card_outlined,
      color: const Color(0xFFEC4899),
      subModulos: [
        SubModulo(titulo: 'Ventas Crédito', icono: Icons.credit_score_outlined, moduleKey: 'ventas_credito'),
        SubModulo(titulo: 'Compras Crédito', icono: Icons.credit_score_outlined, moduleKey: 'compras_credito'),
      ],
    ),
    ModuloMenu(
      titulo: 'Reportes',
      icono: Icons.bar_chart_outlined,
      color: const Color(0xFF64748B),
      subModulos: [
        SubModulo(titulo: 'Reporte de Ventas', icono: Icons.trending_up_outlined, moduleKey: 'reporte_ventas'),
        SubModulo(titulo: 'Reporte de Compras', icono: Icons.trending_down_outlined, moduleKey: 'reporte_compras'),
        SubModulo(titulo: 'Reporte Financiero', icono: Icons.account_balance_outlined, moduleKey: 'reporte_financiero', roles: const [Roles.administrador]),
        SubModulo(titulo: 'Cierre de Caja', icono: Icons.point_of_sale_outlined, moduleKey: 'cierre_caja'),
        SubModulo(titulo: 'Ingresos-Egresos', icono: Icons.swap_vert_outlined, moduleKey: 'ingresos_egresos'),
        SubModulo(titulo: 'Comisiones', icono: Icons.paid_outlined, moduleKey: 'reporte_comisiones', roles: const [Roles.administrador, Roles.barbero]),
      ],
    ),
  ];
}
