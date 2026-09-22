import 'package:cloud_firestore/cloud_firestore.dart';
import 'cierre_caja_model.dart';
import '../../egresos/data/egreso_repository.dart';
import '../../../core/services/funciones_nube.dart';

class EstadoCaja {
  final DateTime fechaDesde;
  final double montoInicial;

  const EstadoCaja({required this.fechaDesde, required this.montoInicial});
}

class CierreCajaRepository {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('cierresCaja');
  final _docEstado = FirebaseFirestore.instance.collection('cajaEstado').doc('actual');
  final _egresoRepository = EgresoRepository();

  Future<EstadoCaja> obtenerEstadoCaja() async {
    final snap = await _docEstado.get();
    final data = snap.data();
    if (data == null) {
      final hoy = DateTime.now();
      return EstadoCaja(fechaDesde: DateTime(hoy.year, hoy.month, hoy.day), montoInicial: 0);
    }
    return EstadoCaja(
      fechaDesde: (data['fechaDesde'] as Timestamp?)?.toDate() ?? DateTime.now(),
      montoInicial: (data['montoInicial'] ?? 0).toDouble(),
    );
  }

  Future<void> guardarMontoInicial(DateTime fechaDesde, double montoInicial, String usuario) async {
    await _docEstado.set({
      'fechaDesde': Timestamp.fromDate(fechaDesde),
      'montoInicial': montoInicial,
      'usuarioResponsable': usuario,
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Suma los totales por método de pago con una sola llamada a la Cloud
  /// Function `cierreCajaTotales` (ver functions/index.js): las 5 lecturas
  /// que arman el libro financiero y la suma final ocurren del lado del
  /// servidor, y solo viaja de vuelta el resultado ya sumado (5 números),
  /// no la lista completa de movimientos. Si la función no responde, cae al
  /// camino local de siempre (que ya tiene su propio respaldo en
  /// [EgresoRepository.obtenerLibroFinanciero]).
  Future<TotalesCaja> calcularTotales(DateTime inicio, DateTime finInclusive) async {
    try {
      final resultado = await FuncionesNube.llamar('cierreCajaTotales', {
        'inicioMillis': inicio.millisecondsSinceEpoch,
        'finMillis': finInclusive.millisecondsSinceEpoch,
      }) as Map<String, dynamic>;
      return TotalesCaja(
        ingresosEfectivo: numDesde(resultado['ingresosEfectivo']),
        ingresosTarjeta: numDesde(resultado['ingresosTarjeta']),
        ingresosTransferencia: numDesde(resultado['ingresosTransferencia']),
        egresosEfectivo: numDesde(resultado['egresosEfectivo']),
        egresosTransferencia: numDesde(resultado['egresosTransferencia']),
      );
    } catch (_) {
      return _calcularTotalesLocal(inicio, finInclusive);
    }
  }

  Future<TotalesCaja> _calcularTotalesLocal(DateTime inicio, DateTime finInclusive) async {
    final movimientos = await _egresoRepository.obtenerLibroFinanciero(inicio, finInclusive);

    double ingresosEfectivo = 0, ingresosTarjeta = 0, ingresosTransferencia = 0;
    double egresosEfectivo = 0, egresosTransferencia = 0;

    for (final m in movimientos) {
      if (m.ingreso > 0) {
        switch (m.metodoPago) {
          case 'Efectivo':
            ingresosEfectivo += m.ingreso;
            break;
          case 'Tarjeta':
            ingresosTarjeta += m.ingreso;
            break;
          case 'Transferencia':
            ingresosTransferencia += m.ingreso;
            break;
        }
      } else if (m.egreso > 0) {
        switch (m.metodoPago) {
          case 'Efectivo':
            egresosEfectivo += m.egreso;
            break;
          case 'Transferencia':
            egresosTransferencia += m.egreso;
            break;
        }
      }
    }

    return TotalesCaja(
      ingresosEfectivo: ingresosEfectivo,
      ingresosTarjeta: ingresosTarjeta,
      ingresosTransferencia: ingresosTransferencia,
      egresosEfectivo: egresosEfectivo,
      egresosTransferencia: egresosTransferencia,
    );
  }

  Future<void> registrarCierre(CierreCajaModel cierre) async {
    await _col.add(cierre.toMap());
    await guardarMontoInicial(cierre.fechaFin, cierre.totalReal, cierre.usuarioResponsable);
  }

  Stream<List<CierreCajaModel>> obtenerHistorial() {
    return _db.collection('cierresCaja').orderBy('fechaFin', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => CierreCajaModel.fromMap(d.id, d.data())).toList();
    });
  }

  Future<List<CierreCajaModel>> obtenerCierresPorRango(DateTime inicio, DateTime finInclusive) async {
    final snap = await _col
        .where('fechaFin', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fechaFin', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive))
        .orderBy('fechaFin', descending: true)
        .get();
    return snap.docs.map((d) => CierreCajaModel.fromMap(d.id, d.data())).toList();
  }
}
