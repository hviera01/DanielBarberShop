const TOP_N = 10;
const TASA_COMISION_PRODUCTO_BASE = 0.07;
const TASA_COMISION_PRODUCTO_ALTA = 0.10;
const UMBRAL_COMISION_PRODUCTO_ALTA = 30;

function num(valor) {
  const n = Number(valor ?? 0);
  return Number.isFinite(n) ? n : 0;
}

function millis(timestamp) {
  return timestamp ? timestamp.toMillis() : null;
}

function sumar(lista, obtener) {
  return lista.reduce((s, x) => s + obtener(x), 0);
}

function tasaComisionProducto(cantidadTotal) {
  return cantidadTotal >= UMBRAL_COMISION_PRODUCTO_ALTA ? TASA_COMISION_PRODUCTO_ALTA : TASA_COMISION_PRODUCTO_BASE;
}

function normalizarVenta(id, d) {
  return {
    id,
    fechaRegistro: millis(d.fechaRegistro),
    tipoDocumento: d.tipoDocumento ?? 'Factura',
    numeroDocumento: d.numeroDocumento ?? '',
    totalAPagar: num(d.totalAPagar),
    metodoPago: d.metodoPago ?? '',
    usuarioRegistro: d.usuarioRegistro ?? '',
    nombreCliente: d.nombreCliente ?? '',
    documentoCliente: d.documentoCliente ?? '',
    condicion: d.condicion ?? '',
    estado: d.estado ?? 'Activa',
    pagosMixtos: (d.pagosMixtos ?? []).map((p) => ({ metodoPago: p.metodoPago ?? '', monto: num(p.monto) })),
  };
}

function normalizarCompra(id, d) {
  return {
    id,
    fechaRegistro: millis(d.fechaRegistro),
    numeroDocumento: d.numeroDocumento ?? '',
    montoTotal: num(d.totalAPagar),
    condicion: d.condicion ?? '',
    metodoPago: d.metodoPago ?? '',
    estado: d.estado ?? 'Activa',
    razonSocial: d.razonSocial ?? '',
    usuarioRegistro: d.usuarioRegistro ?? '',
  };
}

function normalizarItemVenta(d) {
  return {
    idProducto: d.idProducto ?? '',
    nombreProducto: d.nombreProducto ?? '',
    cantidad: num(d.cantidad),
    subtotal: num(d.subtotal),
    precioCompraUsado: num(d.precioCompraUsado),
    esServicio: d.esServicio ?? false,
    idBarbero: d.idBarbero ?? '',
    nombreBarbero: d.nombreBarbero ?? '',
    pctComisionBarbero: num(d.pctComisionBarbero),
    vendidoPorTipo: d.vendidoPorTipo ?? 'N/A',
    vendidoPorId: d.vendidoPorId ?? '',
    vendidoPorNombre: d.vendidoPorNombre ?? '',
  };
}

function normalizarItemCompra(d) {
  return {
    idProducto: d.idProducto ?? '',
    nombreProducto: d.nombreProducto ?? '',
    cantidad: num(d.cantidad),
  };
}

function normalizarAbonoVenta(d) {
  return {
    fecha: millis(d.fecha),
    montoAbonado: num(d.montoAbonado),
    metodoPago: d.metodoPago ?? '',
    numeroRecibo: d.numeroRecibo ?? '',
    usuario: d.usuario ?? '',
  };
}

function normalizarAbonoCompra(d) {
  return {
    fecha: millis(d.fecha),
    montoAbonado: num(d.montoAbonado),
    metodoPago: d.metodoPago ?? '',
    numeroRecibo: d.numeroRecibo ?? '',
    usuario: d.usuario ?? '',
    nombreProveedor: d.nombreProveedor ?? '',
  };
}

function normalizarEgreso(id, d) {
  return {
    id,
    fecha: millis(d.fecha),
    monto: num(d.monto),
    descripcion: d.descripcion ?? '',
    usuario: d.usuario ?? '',
    metodoPago: d.metodoPago ?? 'Efectivo',
    categoria: d.categoria ?? 'Negocio',
    esPagado: d.esPagado ?? true,
    fechaPago: millis(d.fechaPago),
  };
}

function normalizarProducto(id, d) {
  return {
    id,
    nombre: d.nombre ?? '',
    stock: num(d.stock),
    precioCompra: num(d.precioCompra),
    estado: d.estado ?? true,
  };
}

/// Igual que CierreCajaModel.fromMap: se pasa casi tal cual, solo
/// convirtiendo los Timestamp a millis (JSON no tiene tipo de fecha propio).
function normalizarCierreCaja(id, d) {
  return {
    id,
    fechaInicio: millis(d.fechaInicio),
    fechaFin: millis(d.fechaFin),
    montoInicial: num(d.montoInicial),
    ingresosEfectivo: num(d.ingresosEfectivo),
    ingresosTarjeta: num(d.ingresosTarjeta),
    ingresosTransferencia: num(d.ingresosTransferencia),
    egresosEfectivo: num(d.egresosEfectivo),
    egresosTransferencia: num(d.egresosTransferencia),
    totalCalculadoEfectivo: num(d.totalCalculadoEfectivo),
    totalTransferencia: num(d.totalTransferencia),
    granTotal: num(d.granTotal),
    totalReal: num(d.totalReal),
    diferencia: num(d.diferencia),
    usuarioResponsable: d.usuarioResponsable ?? '',
    observaciones: d.observaciones ?? '',
    fechaRegistro: millis(d.fechaRegistro),
  };
}

function ventaEsValida(v) {
  return v.estado === 'Activa' && v.tipoDocumento !== 'Cotizacion';
}

function calcularFlujo({ ventasContado, comprasContado, abonosVenta, abonosCompra, egresos }) {
  let ingresosEfectivo = 0;
  let ingresosTarjeta = 0;
  let ingresosTransferencia = 0;
  let egresosEfectivo = 0;
  let egresosTransferencia = 0;

  const sumarIngreso = (metodoPago, monto) => {
    if (metodoPago === 'Efectivo') ingresosEfectivo += monto;
    else if (metodoPago === 'Tarjeta') ingresosTarjeta += monto;
    else if (metodoPago === 'Transferencia') ingresosTransferencia += monto;
  };
  const sumarEgreso = (metodoPago, monto) => {
    if (metodoPago === 'Efectivo') egresosEfectivo += monto;
    else if (metodoPago === 'Transferencia') egresosTransferencia += monto;
  };

  for (const v of ventasContado) {
    if (v.metodoPago === 'Mixto' && v.pagosMixtos.length > 0) {
      for (const pago of v.pagosMixtos) sumarIngreso(pago.metodoPago, pago.monto);
    } else {
      sumarIngreso(v.metodoPago, v.totalAPagar);
    }
  }
  for (const c of comprasContado) sumarEgreso(c.metodoPago, c.montoTotal);
  for (const a of abonosVenta) sumarIngreso(a.metodoPago, a.montoAbonado);
  for (const a of abonosCompra) sumarEgreso(a.metodoPago, a.montoAbonado);
  for (const e of egresos) sumarEgreso(e.metodoPago, e.monto);

  return { ingresosEfectivo, ingresosTarjeta, ingresosTransferencia, egresosEfectivo, egresosTransferencia };
}

function flujoDeMovimientos({ ventas, compras, abonosVenta, abonosCompra, egresos }) {
  return calcularFlujo({
    ventasContado: ventas.filter((v) => ventaEsValida(v) && v.condicion === 'Contado'),
    comprasContado: compras.filter((c) => c.estado === 'Activa' && c.condicion !== 'Credito'),
    abonosVenta,
    abonosCompra,
    egresos,
  });
}

function clienteVisible(nombre) {
  return nombre === '' ? 'CONSUMIDOR FINAL' : nombre;
}

function porFechaDesc(a, b) {
  return (b.fecha ?? 946684800000) - (a.fecha ?? 946684800000);
}

/// Igual que EgresoRepository.obtenerLibroFinanciero: junta ventas de
/// contado, abonos a crédito (venta y compra) y egresos manuales en una
/// sola lista de movimientos, para el Libro Financiero (Ingresos/Egresos) y
/// para calcularTotalesCaja (Cierre de Caja).
function construirLibroFinanciero({ ventas, compras, abonosVenta, abonosCompra, egresos }) {
  const movimientos = [];

  for (const v of ventas) {
    if (v.estado !== 'Activa' || v.condicion !== 'Contado' || v.tipoDocumento === 'Cotizacion') continue;
    const descripcion = `Doc. ${v.numeroDocumento} · ${clienteVisible(v.nombreCliente) === 'CONSUMIDOR FINAL' ? 'Consumidor final' : v.nombreCliente}`;
    if (v.metodoPago === 'Mixto' && v.pagosMixtos.length > 0) {
      for (const pago of v.pagosMixtos) {
        movimientos.push({
          fecha: v.fechaRegistro,
          tipoMovimiento: 'Venta (Contado)',
          descripcion: `${descripcion} (mixto)`,
          ingreso: pago.monto,
          egreso: 0,
          metodoPago: pago.metodoPago,
          categoria: '',
          esPagado: true,
          fechaPago: null,
          usuario: v.usuarioRegistro,
          idEgreso: '',
          esEgresoManual: false,
        });
      }
    } else {
      movimientos.push({
        fecha: v.fechaRegistro,
        tipoMovimiento: 'Venta (Contado)',
        descripcion,
        ingreso: v.totalAPagar,
        egreso: 0,
        metodoPago: v.metodoPago,
        categoria: '',
        esPagado: true,
        fechaPago: null,
        usuario: v.usuarioRegistro,
        idEgreso: '',
        esEgresoManual: false,
      });
    }
  }

  for (const c of compras) {
    if (c.condicion === 'Credito' || c.estado !== 'Activa') continue;
    movimientos.push({
      fecha: c.fechaRegistro,
      tipoMovimiento: 'Compra (Contado)',
      descripcion: `Doc. ${c.numeroDocumento} · ${c.razonSocial}`,
      ingreso: 0,
      egreso: c.montoTotal,
      metodoPago: c.metodoPago,
      categoria: '',
      esPagado: true,
      fechaPago: null,
      usuario: c.usuarioRegistro,
      idEgreso: '',
      esEgresoManual: false,
    });
  }

  for (const a of abonosVenta) {
    movimientos.push({
      fecha: a.fecha,
      tipoMovimiento: 'Abono a Crédito',
      descripcion: `Recibo ${a.numeroRecibo}`,
      ingreso: a.montoAbonado,
      egreso: 0,
      metodoPago: a.metodoPago,
      categoria: '',
      esPagado: true,
      fechaPago: null,
      usuario: a.usuario,
      idEgreso: '',
      esEgresoManual: false,
    });
  }

  for (const a of abonosCompra) {
    movimientos.push({
      fecha: a.fecha,
      tipoMovimiento: 'Abono Compra Crédito',
      descripcion: `${a.nombreProveedor} · Recibo ${a.numeroRecibo}`,
      ingreso: 0,
      egreso: a.montoAbonado,
      metodoPago: a.metodoPago,
      categoria: '',
      esPagado: true,
      fechaPago: null,
      usuario: a.usuario,
      idEgreso: '',
      esEgresoManual: false,
    });
  }

  for (const e of egresos) {
    movimientos.push({
      fecha: e.fecha,
      tipoMovimiento: 'Egreso Manual',
      descripcion: e.descripcion,
      ingreso: 0,
      egreso: e.monto,
      metodoPago: e.metodoPago,
      categoria: e.categoria,
      esPagado: e.esPagado,
      fechaPago: e.fechaPago,
      usuario: e.usuario,
      idEgreso: e.id,
      esEgresoManual: true,
    });
  }

  movimientos.sort(porFechaDesc);
  return movimientos;
}

/// Igual que CierreCajaRepository.calcularTotales: suma los movimientos del
/// libro financiero por método de pago.
function calcularTotalesCaja(movimientos) {
  let ingresosEfectivo = 0;
  let ingresosTarjeta = 0;
  let ingresosTransferencia = 0;
  let egresosEfectivo = 0;
  let egresosTransferencia = 0;

  for (const m of movimientos) {
    if (m.ingreso > 0) {
      if (m.metodoPago === 'Efectivo') ingresosEfectivo += m.ingreso;
      else if (m.metodoPago === 'Tarjeta') ingresosTarjeta += m.ingreso;
      else if (m.metodoPago === 'Transferencia') ingresosTransferencia += m.ingreso;
    } else if (m.egreso > 0) {
      if (m.metodoPago === 'Efectivo') egresosEfectivo += m.egreso;
      else if (m.metodoPago === 'Transferencia') egresosTransferencia += m.egreso;
    }
  }

  return { ingresosEfectivo, ingresosTarjeta, ingresosTransferencia, egresosEfectivo, egresosTransferencia };
}

/// Igual que ComisionRepository._calcularCortes/_calcularProductos: [lineas]
/// es la lista de líneas de detalle activas del periodo, cada una ya
/// cruzada con los datos de su venta (idVenta, numeroDocumento, fecha,
/// cliente) y el ItemVentaModel original (item).
function calcularComisiones({ lineas, tipoFiltro, idFiltro }) {
  const cortes = tipoFiltro === 'Usuario' ? [] : calcularCortes(lineas, tipoFiltro === 'Barbero' ? idFiltro : null);
  const productos = calcularProductos(lineas, tipoFiltro ?? null, idFiltro ?? null);
  return { cortes, productos };
}

function calcularCortes(lineas, idBarbero) {
  const filtradas = lineas.filter((l) => l.item.esServicio && l.item.idBarbero !== '' && (idBarbero == null || l.item.idBarbero === idBarbero));
  const porBarbero = new Map();
  for (const linea of filtradas) {
    const item = linea.item;
    const comisionLinea = item.subtotal * (item.pctComisionBarbero / 100);
    const lineaComision = {
      idVenta: linea.idVenta,
      numeroDocumento: linea.numeroDocumento,
      fecha: linea.fecha,
      cliente: linea.cliente,
      nombreItem: item.nombreProducto,
      monto: item.subtotal,
      comision: comisionLinea,
    };
    const actual = porBarbero.get(item.idBarbero);
    if (!actual) {
      porBarbero.set(item.idBarbero, {
        idBarbero: item.idBarbero,
        nombreBarbero: item.nombreBarbero,
        cantidadCortes: item.cantidad,
        montoTotal: item.subtotal,
        comisionTotal: comisionLinea,
        lineas: [lineaComision],
      });
    } else {
      actual.cantidadCortes += item.cantidad;
      actual.montoTotal += item.subtotal;
      actual.comisionTotal += comisionLinea;
      actual.lineas.push(lineaComision);
    }
  }
  return [...porBarbero.values()].sort((a, b) => b.montoTotal - a.montoTotal);
}

function calcularProductos(lineasDetalle, tipo, id) {
  const filtradas = lineasDetalle.filter((l) => {
    const item = l.item;
    if (item.esServicio || item.vendidoPorTipo === 'N/A' || item.vendidoPorId === '') return false;
    if (tipo != null && item.vendidoPorTipo !== tipo) return false;
    if (id != null && item.vendidoPorId !== id) return false;
    return true;
  });

  const cantidadPorClave = new Map();
  const montoPorClave = new Map();
  const infoPorClave = new Map();
  const detallePorClave = new Map();
  for (const l of filtradas) {
    const item = l.item;
    const clave = `${item.vendidoPorTipo}:${item.vendidoPorId}`;
    cantidadPorClave.set(clave, (cantidadPorClave.get(clave) ?? 0) + item.cantidad);
    montoPorClave.set(clave, (montoPorClave.get(clave) ?? 0) + item.subtotal);
    infoPorClave.set(clave, { tipo: item.vendidoPorTipo, id: item.vendidoPorId, nombre: item.vendidoPorNombre });
    if (!detallePorClave.has(clave)) detallePorClave.set(clave, []);
    detallePorClave.get(clave).push(l);
  }

  const lista = [...cantidadPorClave.keys()].map((clave) => {
    const info = infoPorClave.get(clave);
    const cantidad = cantidadPorClave.get(clave);
    const monto = montoPorClave.get(clave);
    const tasa = tasaComisionProducto(cantidad);
    const lineasComision = detallePorClave.get(clave).map((l) => ({
      idVenta: l.idVenta,
      numeroDocumento: l.numeroDocumento,
      fecha: l.fecha,
      cliente: l.cliente,
      nombreItem: l.item.nombreProducto,
      monto: l.item.subtotal,
      comision: l.item.subtotal * tasa,
    }));
    return {
      tipo: info.tipo,
      id: info.id,
      nombre: info.nombre,
      cantidadProductos: cantidad,
      montoTotal: monto,
      tasa,
      comisionTotal: monto * tasa,
      lineas: lineasComision,
    };
  });
  return lista.sort((a, b) => b.montoTotal - a.montoTotal);
}

function rankearPorCantidad(lineas) {
  const porProducto = new Map();
  for (const { idProducto, nombreProducto, cantidad } of lineas) {
    const actual = porProducto.get(idProducto);
    porProducto.set(idProducto, {
      idProducto,
      nombreProducto,
      cantidad: (actual ? actual.cantidad : 0) + cantidad,
      monto: 0,
    });
  }
  return [...porProducto.values()].sort((a, b) => b.cantidad - a.cantidad).slice(0, TOP_N);
}

function rankearGanancia(items) {
  const porProducto = new Map();
  for (const item of items) {
    const actual = porProducto.get(item.idProducto) ?? { ingreso: 0, costo: 0, cantidad: 0, nombre: '' };
    actual.ingreso += item.subtotal;
    actual.costo += item.precioCompraUsado * item.cantidad;
    actual.cantidad += item.cantidad;
    actual.nombre = item.nombreProducto;
    porProducto.set(item.idProducto, actual);
  }
  return [...porProducto.entries()]
    .map(([idProducto, x]) => ({ idProducto, nombreProducto: x.nombre, cantidad: x.cantidad, monto: x.ingreso - x.costo }))
    .sort((a, b) => b.monto - a.monto)
    .slice(0, TOP_N);
}

function calcularReporte(d) {
  const ventasValidas = d.ventas.filter(ventaEsValida);
  const comprasValidas = d.compras.filter((c) => c.estado === 'Activa');

  const detalleVentasPorVenta = ventasValidas.map((v) => d.detalleVentas.get(v.id) ?? []);
  const itemsVenta = detalleVentasPorVenta.flat();
  const itemsCompra = comprasValidas.flatMap((c) => d.detalleCompras.get(c.id) ?? []);

  const gananciaPorVenta = ventasValidas
    .map((v, i) => ({
      idVenta: v.id,
      numeroDocumento: v.numeroDocumento,
      fecha: v.fechaRegistro,
      cliente: clienteVisible(v.nombreCliente),
      ventas: v.totalAPagar,
      costo: sumar(detalleVentasPorVenta[i], (item) => item.precioCompraUsado * item.cantidad),
    }))
    .sort(porFechaDesc);

  const ventasPeriodo = sumar(ventasValidas, (v) => v.totalAPagar);
  const comprasPeriodo = sumar(comprasValidas, (c) => c.montoTotal);
  const costoVentas = sumar(itemsVenta, (i) => i.precioCompraUsado * i.cantidad);
  const utilidadBruta = ventasPeriodo - costoVentas;
  const gastosPeriodo = sumar(d.egresos, (e) => e.monto);
  const utilidadNeta = utilidadBruta - gastosPeriodo;

  const flujoEfectivo = flujoDeMovimientos({
    ventas: d.ventas,
    compras: d.compras,
    abonosVenta: d.abonosVenta,
    abonosCompra: d.abonosCompra,
    egresos: d.egresos,
  });

  const idsConVenta = new Set(itemsVenta.map((i) => i.idProducto));
  const productosActivos = d.productos.filter((p) => p.estado);
  const productosSinVenta = productosActivos
    .filter((p) => !idsConVenta.has(p.id))
    .map((p) => ({ idProducto: p.id, nombreProducto: p.nombre, stock: p.stock, valorInventario: p.stock * p.precioCompra }))
    .sort((a, b) => b.valorInventario - a.valorInventario);
  const inventarioACosto = sumar(productosActivos, (p) => p.stock * p.precioCompra);

  const totalPorUsuario = new Map();
  const conteoPorUsuario = new Map();
  for (const v of ventasValidas) {
    const usuario = v.usuarioRegistro === '' ? 'Sin usuario' : v.usuarioRegistro;
    totalPorUsuario.set(usuario, (totalPorUsuario.get(usuario) ?? 0) + v.totalAPagar);
    conteoPorUsuario.set(usuario, (conteoPorUsuario.get(usuario) ?? 0) + 1);
  }
  const ventasPorUsuario = [...totalPorUsuario.keys()]
    .map((usuario) => ({ usuario, totalVentas: totalPorUsuario.get(usuario), cantidadTransacciones: conteoPorUsuario.get(usuario) }))
    .sort((a, b) => b.totalVentas - a.totalVentas);

  const detalleServiciosProductos = ventasValidas
    .flatMap((v, i) =>
      detalleVentasPorVenta[i].map((item) => ({
        idVenta: v.id,
        numeroDocumento: v.numeroDocumento,
        fecha: v.fechaRegistro,
        cliente: clienteVisible(v.nombreCliente),
        nombreItem: item.nombreProducto,
        esServicio: item.esServicio,
        venta: item.subtotal,
        costo: item.precioCompraUsado * item.cantidad,
      })),
    )
    .sort(porFechaDesc);
  const servicios = detalleServiciosProductos.filter((x) => x.esServicio);
  const productosFisicos = detalleServiciosProductos.filter((x) => !x.esServicio);

  const totalPorProveedor = new Map();
  for (const a of d.abonosCompra) {
    const proveedor = a.nombreProveedor === '' ? 'N/A' : a.nombreProveedor;
    totalPorProveedor.set(proveedor, (totalPorProveedor.get(proveedor) ?? 0) + a.montoAbonado);
  }
  const abonosPorProveedor = [...totalPorProveedor.entries()]
    .map(([proveedor, total]) => ({ proveedor, total }))
    .sort((a, b) => b.total - a.total);

  const saldoPositivo = (saldo) => Math.max(0, num(saldo));

  return {
    ventasPeriodo,
    comprasPeriodo,
    costoVentas,
    utilidadBruta,
    gastosPeriodo,
    utilidadNeta,
    flujoEfectivo,
    serieMensual: d.serieMensual,
    gananciaPorVenta,
    topVendidosPorCantidad: rankearPorCantidad(itemsVenta),
    topCompradosPorCantidad: rankearPorCantidad(itemsCompra),
    topGananciaPorProducto: rankearGanancia(itemsVenta),
    productosSinVenta,
    ventasPorUsuario,
    resumenServiciosProductos: {
      ventasServicios: sumar(servicios, (x) => x.venta),
      costoServicios: sumar(servicios, (x) => x.costo),
      ventasProductos: sumar(productosFisicos, (x) => x.venta),
      costoProductos: sumar(productosFisicos, (x) => x.costo),
      detalle: detalleServiciosProductos,
    },
    totalAbonosComprasCredito: sumar(d.abonosCompra, (a) => a.montoAbonado),
    abonosPorProveedor,
    balanceGeneral: {
      inventarioACosto,
      cuentasPorCobrar: sumar(d.creditosVenta, saldoPositivo),
      efectivoEstimado: d.efectivoEstimado,
      cuentasPorPagar: sumar(d.creditosCompra, saldoPositivo),
    },
    cierresCaja: d.cierresCaja,
  };
}

module.exports = {
  num,
  millis,
  sumar,
  tasaComisionProducto,
  normalizarVenta,
  normalizarCompra,
  normalizarItemVenta,
  normalizarItemCompra,
  normalizarAbonoVenta,
  normalizarAbonoCompra,
  normalizarEgreso,
  normalizarProducto,
  normalizarCierreCaja,
  ventaEsValida,
  clienteVisible,
  flujoDeMovimientos,
  construirLibroFinanciero,
  calcularTotalesCaja,
  calcularComisiones,
  calcularReporte,
};
