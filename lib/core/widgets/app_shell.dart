import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/tabs_provider.dart';
import '../models/tab_item.dart';
import '../widgets/side_menu.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/screens/home_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _menuAbierto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabsState = ref.read(tabsProvider);
      if (tabsState.tabs.isEmpty) {
        ref.read(tabsProvider.notifier).abrirTab(
          TabItem(
            id: 'inicio',
            titulo: 'Inicio',
            icono: Icons.home_outlined,
            contenido: const HomeScreen(),
            cerrable: false,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(tabsProvider);
    final authState = ref.watch(authProvider);
    final usuario = authState.usuario;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: Stack(
        children: [
          Column(
            children: [
              _barraSuperior(usuario),
              _barraPestanas(tabsState),
              Expanded(
                child: tabsState.tabs.isEmpty
                    ? const SizedBox()
                    : IndexedStack(
                        index: tabsState.indiceActivo,
                        children: tabsState.tabs.map((t) => t.contenido).toList(),
                      ),
              ),
            ],
          ),
          if (_menuAbierto)
            GestureDetector(
              onTap: () => setState(() => _menuAbierto = false),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: _menuAbierto ? 0 : -300,
            top: 0,
            bottom: 0,
            child: SideMenu(onCerrar: () => setState(() => _menuAbierto = false)),
          ),
        ],
      ),
    );
  }

  Widget _barraSuperior(dynamic usuario) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFC62828),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => setState(() => _menuAbierto = !_menuAbierto),
          ),
          const SizedBox(width: 4),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'SUPERCOLOR',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          if (usuario != null) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                usuario.nombreCompleto.isNotEmpty ? usuario.nombreCompleto[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  usuario.nombreCompleto,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  usuario.rol,
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.75), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
              tooltip: 'Cerrar sesión',
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _barraPestanas(TabsState tabsState) {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: tabsState.tabs.length,
        itemBuilder: (context, index) {
          final tab = tabsState.tabs[index];
          final activo = index == tabsState.indiceActivo;
          return GestureDetector(
            onTap: () => ref.read(tabsProvider.notifier).seleccionarTab(index),
            child: Container(
              margin: const EdgeInsets.only(right: 6, top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: activo ? const Color(0xFFFCE9E9) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: activo ? Border.all(color: const Color(0xFFC62828).withOpacity(0.25)) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icono, size: 16, color: activo ? const Color(0xFFC62828) : Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    tab.titulo,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: activo ? const Color(0xFFC62828) : Colors.grey.shade600,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (tab.cerrable) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => ref.read(tabsProvider.notifier).cerrarTab(tab.id),
                      child: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}