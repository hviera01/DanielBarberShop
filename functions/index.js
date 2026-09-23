const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const c = require('./calculos.js');

admin.initializeApp();
const db = admin.firestore();
const { Timestamp, AggregateField } = admin.firestore;

// Firestore de este proyecto está en nam5 (multi-región EE. UU.), que
// comprende us-central1: es la región de Cloud Functions con menor latencia
// hacia esa base, sin tener que migrar Firestore a una región de una sola
// zona. Todas las funciones de este archivo viven ahí.
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

// Honduras no usa horario de verano: UTC-6 todo el año. Estas funciones no
// tienen forma de saber la zona horaria del dispositivo que llama, así que
// reciben siempre un "ahoraMillis" (instante absoluto) desde el cliente y
// acá se convierte a fecha calendario de Honduras para armar límites de
// día/mes -igual que hacía antes `DateTime.now()` en el dispositivo, que ya
// corre en esa misma zona-.
const OFFSET_HONDURAS_MINUTOS = -360;

function partesLocal(ms) {
  const d = new Date(ms + OFFSET_HONDURAS_MINUTOS * 60000);
  return { anio: d.getUTCFullYear(), mes: d.getUTCMonth(), dia: d.getUTCDate() };
}

function instanteLocal(anio, mes, dia, hora, minuto, segundo) {
  return Date.UTC(anio, mes, dia, hora, minuto, segundo) - OFFSET_HONDURAS_MINUTOS * 60000;
}

function finDeHoyMillis(ahoraMillis) {
  const { anio, mes, dia } = partesLocal(ahoraMillis);
  return instanteLocal(anio, mes, dia, 23, 59, 59);
}

function mesesDeLaSerie(ahoraMillis) {
  const { anio, mes } = partesLocal(ahoraMillis);
  const meses = [];
  for (let i = 0; i < 6; i++) {
    const mesIndice = mes - 5 + i;
    meses.push({
      mesMillis: instanteLocal(anio, mesIndice, 1, 0, 0, 0),
      inicioMillis: instanteLocal(anio, mesIndice, 1, 0, 0, 0),
      finMillisExclusivo: instanteLocal(anio, mesIndice + 1, 1, 0, 0, 0),
    });
  }
  return meses;
}

function requerirNumero(data, campo) {
  const valor = data?.[campo];
  if (typeof valor !== 'number' || !Number.isFinite(valor)) {
    throw new HttpsError('invalid-argument', `Falta o es inválido el parámetro "${campo}"`);
  }
  return valor;
}

function ts(millis) {
  return Timestamp.fromMillis(millis);
}

function conManejoDeErrores(nombre, manejador) {
  return onCall(async (request) => {
    try {
      return await manejador(request.data ?? {});
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error(`${nombre} falló:`, error);
      throw new HttpsError('internal', 'No se pudo completar la operación, intentá de nuevo');
    }
  });
}

// ---------- Lecturas de rango compartidas (ventas/compras/abonos/egresos) ----------

async function leerVentasRango(inicioMillis, finMillis) {
  const snap = await db
    .collection('ventas')
    .where('fechaRegistro', '>=', ts(inicioMillis))
    .where('fechaRegistro', '<=', ts(finMillis))
    .get();
  return snap.docs.map((d) => c.normalizarVenta(d.id, d.data()));
}

async function leerComprasRango(inicioMillis, finMillis) {
  const snap = await db
    .collection('compras')
    .where('fechaRegistro', '>=', ts(inicioMillis))
    .where('fechaRegistro', '<=', ts(finMillis))
    .get();
  return snap.docs.map((d) => c.normalizarCompra(d.id, d.data()));
}

async function leerAbonosVentaRango(inicioMillis, finMillis) {
  const snap = await db
    .collectionGroup('abonos')
    .where('fecha', '>=', ts(inicioMillis))
    .where('fecha', '<=', ts(finMillis))
    .get();
  return snap.docs.map((d) => c.normalizarAbonoVenta(d.data()));
}

async function leerAbonosCompraRango(inicioMillis, finMillis) {
  const snap = await db
    .collectionGroup('abonosCompra')
    .where('fecha', '>=', ts(inicioMillis))
    .where('fecha', '<=', ts(finMillis))
    .get();
  return snap.docs.map((d) => c.normalizarAbonoCompra(d.data()));
}

async function leerEgresosRango(inicioMillis, finMillis) {
  const snap = await db
    .collection('egresos')
    .where('fecha', '>=', ts(inicioMillis))
    .where('fecha', '<=', ts(finMillis))
    .get();
  return snap.docs.map((d) => c.normalizarEgreso(d.id, d.data()));
}

// Igual que EgresoRepository.obtenerLibroFinanciero: junta las 5 fuentes de
// un mismo rango en paralelo y arma la lista de movimientos.
async function obtenerMovimientosRango(inicioMillis, finMillis) {
  const [ventas, compras, abonosVenta, abonosCompra, egresos] = await Promise.all([
    leerVentasRango(inicioMillis, finMillis),
    leerComprasRango(inicioMillis, finMillis),
    leerAbonosVentaRango(inicioMillis, finMillis),
    leerAbonosCompraRango(inicioMillis, finMillis),
    leerEgresosRango(inicioMillis, finMillis),
  ]);
  return c.construirLibroFinanciero({ ventas, compras, abonosVenta, abonosCompra, egresos });
}

// ---------- Detalle de venta/compra (collectionGroup 'detalle' por rango) ----------

async function leerDetallePorRango(inicioMillis, finMillis) {
  const snap = await db
    .collectionGroup('detalle')
    .where('fecha', '>=', ts(inicioMillis))
    .where('fecha', '<=', ts(finMillis))
    .get();
  const porVenta = new Map();
  const porCompra = new Map();
  for (const doc of snap.docs) {
    const docPadre = doc.ref.parent.parent;
    if (!docPadre) continue;
    const coleccionRaiz = docPadre.parent.id;
    if (coleccionRaiz === 'ventas') {
      if (!porVenta.has(docPadre.id)) porVenta.set(docPadre.id, []);
      porVenta.get(docPadre.id).push(c.normalizarItemVenta(doc.data()));
    } else if (coleccionRaiz === 'compras') {
      if (!porCompra.has(docPadre.id)) porCompra.set(docPadre.id, []);
      porCompra.get(docPadre.id).push(c.normalizarItemCompra(doc.data()));
    }
  }
  return { porVenta, porCompra };
}

// Respaldo para ventas/compras registradas antes de que 'detalle' guardara su
// propia fecha (ver ReporteFinancieroRepository._resolverDetalleVentas).
async function completarFaltantes(ids, mapa, coleccion, normalizar) {
  const faltantes = ids.filter((id) => !mapa.has(id));
  if (faltantes.length === 0) return;
  const snaps = await Promise.all(faltantes.map((id) => db.collection(coleccion).doc(id).collection('detalle').get()));
  faltantes.forEach((id, i) => {
    mapa.set(id, snaps[i].docs.map((d) => normalizar(d.data())));
  });
}

// ---------- Serie mensual (agregación con respaldo si el índice no está listo) ----------

async function sumaMensual(coleccion, inicioMillis, finMillisExclusivo) {
  let query = db.collection(coleccion).where('estado', '==', 'Activa');
  if (coleccion === 'ventas') {
    query = query.where('tipoDocumento', 'in', ['Factura', 'Boleta', 'Venta']);
  }
  query = query.where('fechaRegistro', '>=', ts(inicioMillis)).where('fechaRegistro', '<', ts(finMillisExclusivo));
  const resultado = await query.aggregate({ total: AggregateField.sum('totalAPagar') }).get();
  return c.num(resultado.data().total);
}

async function sumaMensualConRespaldo(coleccion, inicioMillis, finMillisExclusivo) {
  try {
    return await sumaMensual(coleccion, inicioMillis, finMillisExclusivo);
  } catch (error) {
    console.warn(`Agregación mensual de "${coleccion}" falló, se recalcula sumando documentos:`, error.message);
    const finInclusivo = finMillisExclusivo - 1;
    const lista = coleccion === 'ventas' ? await leerVentasRango(inicioMillis, finInclusivo) : await leerComprasRango(inicioMillis, finInclusivo);
    const validas = coleccion === 'ventas' ? lista.filter(c.ventaEsValida) : lista.filter((x) => x.estado === 'Activa');
    return c.sumar(validas, (x) => (coleccion === 'ventas' ? x.totalAPagar : x.montoTotal));
  }
}

async function calcularSerieMensual(ahoraMillis) {
  const meses = mesesDeLaSerie(ahoraMillis);
  const totales = await Promise.all(
    meses.flatMap((mes) => [
      sumaMensualConRespaldo('ventas', mes.inicioMillis, mes.finMillisExclusivo),
      sumaMensualConRespaldo('compras', mes.inicioMillis, mes.finMillisExclusivo),
    ]),
  );
  return meses.map((mes, i) => ({
    mesMillis: mes.mesMillis,
    totalVentas: totales[i * 2],
    totalCompras: totales[i * 2 + 1],
  }));
}

// ---------- Cloud Functions ----------

exports.reporteFinanciero = conManejoDeErrores('reporteFinanciero', async (data) => {
  const inicioMillis = requerirNumero(data, 'inicioMillis');
  const finMillis = requerirNumero(data, 'finMillis');
  const ahoraMillis = requerirNumero(data, 'ahoraMillis');

  const efectivoEstimadoPromise = db
    .collection('cajaEstado')
    .doc('actual')
    .get()
    .then(async (estadoSnap) => {
      const estadoData = estadoSnap.data() ?? {};
      const fechaDesdeTs = estadoData.fechaDesde;
      const fechaDesdeMillis = fechaDesdeTs ? fechaDesdeTs.toMillis() : instanteLocal(partesLocal(ahoraMillis).anio, partesLocal(ahoraMillis).mes, partesLocal(ahoraMillis).dia, 0, 0, 0);
      const montoInicial = c.num(estadoData.montoInicial);
      const movimientos = await obtenerMovimientosRango(fechaDesdeMillis, finDeHoyMillis(ahoraMillis));
      const totales = c.calcularTotalesCaja(movimientos);
      return montoInicial + totales.ingresosEfectivo - totales.egresosEfectivo;
    });

  const [
    ventas,
    compras,
    { porVenta: detalleVentaRapido, porCompra: detalleCompraRapido },
    egresos,
    abonosVenta,
    abonosCompra,
    productosSnap,
    ventasCreditoSnap,
    comprasCreditoSnap,
    cierresCajaSnap,
    serieMensual,
    efectivoEstimado,
  ] = await Promise.all([
    leerVentasRango(inicioMillis, finMillis),
    leerComprasRango(inicioMillis, finMillis),
    leerDetallePorRango(inicioMillis, finMillis),
    leerEgresosRango(inicioMillis, finMillis),
    leerAbonosVentaRango(inicioMillis, finMillis),
    leerAbonosCompraRango(inicioMillis, finMillis),
    db.collection('productos').get(),
    db.collection('ventasCredito').where('saldoPendiente', '>', 0).get(),
    db.collection('comprasCredito').where('saldoPendiente', '>', 0).get(),
    db.collection('cierresCaja').where('fechaFin', '>=', ts(inicioMillis)).where('fechaFin', '<=', ts(finMillis)).get(),
    calcularSerieMensual(ahoraMillis),
    efectivoEstimadoPromise,
  ]);

  const ventasValidas = ventas.filter(c.ventaEsValida);
  const comprasValidas = compras.filter((x) => x.estado === 'Activa');
  await Promise.all([
    completarFaltantes(ventasValidas.map((v) => v.id), detalleVentaRapido, 'ventas', c.normalizarItemVenta),
    completarFaltantes(comprasValidas.map((cc) => cc.id), detalleCompraRapido, 'compras', c.normalizarItemCompra),
  ]);

  const productos = productosSnap.docs.map((d) => c.normalizarProducto(d.id, d.data()));
  const creditosVenta = ventasCreditoSnap.docs.map((d) => d.data().saldoPendiente);
  const creditosCompra = comprasCreditoSnap.docs.map((d) => d.data().saldoPendiente);
  const cierresCaja = cierresCajaSnap.docs.map((d) => c.normalizarCierreCaja(d.id, d.data()));

  return c.calcularReporte({
    ventas,
    compras,
    detalleVentas: detalleVentaRapido,
    detalleCompras: detalleCompraRapido,
    egresos,
    abonosVenta,
    abonosCompra,
    productos,
    creditosVenta,
    creditosCompra,
    serieMensual,
    efectivoEstimado,
    cierresCaja,
  });
});

exports.comisionesPeriodo = conManejoDeErrores('comisionesPeriodo', async (data) => {
  const inicioMillis = requerirNumero(data, 'inicioMillis');
  const finMillis = requerirNumero(data, 'finMillis');
  const tipoFiltro = typeof data.tipoFiltro === 'string' && data.tipoFiltro !== '' ? data.tipoFiltro : null;
  const idFiltro = typeof data.idFiltro === 'string' && data.idFiltro !== '' ? data.idFiltro : null;

  const [ventas, detalleSnap] = await Promise.all([
    leerVentasRango(inicioMillis, finMillis),
    db.collectionGroup('detalle').where('fecha', '>=', ts(inicioMillis)).where('fecha', '<=', ts(finMillis)).get(),
  ]);
  const activasPorId = new Map(ventas.filter(c.ventaEsValida).map((v) => [v.id, v]));

  const lineas = [];
  for (const doc of detalleSnap.docs) {
    const docPadre = doc.ref.parent.parent;
    if (!docPadre || docPadre.parent.id !== 'ventas') continue;
    const venta = activasPorId.get(docPadre.id);
    if (!venta) continue;
    lineas.push({
      idVenta: docPadre.id,
      numeroDocumento: venta.numeroDocumento,
      fecha: venta.fechaRegistro,
      cliente: venta.nombreCliente,
      item: c.normalizarItemVenta(doc.data()),
    });
  }

  return c.calcularComisiones({ lineas, tipoFiltro, idFiltro });
});

exports.libroFinanciero = conManejoDeErrores('libroFinanciero', async (data) => {
  const inicioMillis = requerirNumero(data, 'inicioMillis');
  const finMillis = requerirNumero(data, 'finMillis');
  return obtenerMovimientosRango(inicioMillis, finMillis);
});

exports.cierreCajaTotales = conManejoDeErrores('cierreCajaTotales', async (data) => {
  const inicioMillis = requerirNumero(data, 'inicioMillis');
  const finMillis = requerirNumero(data, 'finMillis');
  const movimientos = await obtenerMovimientosRango(inicioMillis, finMillis);
  return c.calcularTotalesCaja(movimientos);
});

// ---------- Detalle de venta / compra ----------

function serializarVentaCruda(id, data, detalleDocs) {
  return {
    id,
    ...serializarTimestamps(data),
    detalle: detalleDocs.map((d) => serializarTimestamps(d)),
  };
}

// Las pantallas de detalle de venta/compra ya tienen su propio modelo Dart
// (VentaModel/CompraModel) que sabe leer Timestamps de Firestore: para no
// duplicar esa lógica acá, la función solo convierte los Timestamp a millis
// (JSON no tiene un tipo de fecha) y deja el resto de los campos tal cual
// están guardados, y VentaRepository/CompraRepository arma el modelo con el
// mismo `fromMap` que ya usan para leer directo de Firestore.
function serializarTimestamps(valor) {
  if (valor instanceof Timestamp) return { __timestampMillis: valor.toMillis() };
  if (Array.isArray(valor)) return valor.map(serializarTimestamps);
  if (valor && typeof valor === 'object') {
    const resultado = {};
    for (const [clave, v] of Object.entries(valor)) resultado[clave] = serializarTimestamps(v);
    return resultado;
  }
  return valor;
}

async function obtenerVentaConDetalle(doc) {
  const detalleSnap = await doc.ref.collection('detalle').get();
  return serializarVentaCruda(doc.id, doc.data(), detalleSnap.docs.map((d) => d.data()));
}

async function obtenerCompraConDetalle(doc) {
  const detalleSnap = await doc.ref.collection('detalle').get();
  return serializarVentaCruda(doc.id, doc.data(), detalleSnap.docs.map((d) => d.data()));
}

exports.ventaPorId = conManejoDeErrores('ventaPorId', async (data) => {
  const id = data?.id;
  if (typeof id !== 'string' || id === '') throw new HttpsError('invalid-argument', 'Falta el id de la venta');
  const doc = await db.collection('ventas').doc(id).get();
  if (!doc.exists) return { venta: null };
  return { venta: await obtenerVentaConDetalle(doc) };
});

exports.ventasPorNumero = conManejoDeErrores('ventasPorNumero', async (data) => {
  const texto = (data?.texto ?? '').trim();
  const tipoDocumento = typeof data?.tipoDocumento === 'string' && data.tipoDocumento !== '' ? data.tipoDocumento : null;
  if (texto === '') return { ventas: [] };

  const candidatos = new Set([texto]);
  if (/^\d+$/.test(texto)) {
    candidatos.add(texto.padStart(8, '0'));
    candidatos.add(texto.padStart(5, '0'));
    candidatos.add(texto.padStart(4, '0'));
  }

  const snaps = await Promise.all(
    [...candidatos].map((candidato) => db.collection('ventas').where('numeroDocumento', '==', candidato).get()),
  );
  const docs = snaps.flatMap((s) => s.docs).filter((doc) => !tipoDocumento || doc.data().tipoDocumento === tipoDocumento);

  const ventas = await Promise.all(docs.map((doc) => obtenerVentaConDetalle(doc)));
  ventas.sort((a, b) => (b.fechaRegistro?.__timestampMillis ?? 0) - (a.fechaRegistro?.__timestampMillis ?? 0));
  return { ventas };
});

exports.compraPorId = conManejoDeErrores('compraPorId', async (data) => {
  const id = data?.id;
  if (typeof id !== 'string' || id === '') throw new HttpsError('invalid-argument', 'Falta el id de la compra');
  const doc = await db.collection('compras').doc(id).get();
  if (!doc.exists) return { compra: null };
  return { compra: await obtenerCompraConDetalle(doc) };
});

exports.compraPorNumero = conManejoDeErrores('compraPorNumero', async (data) => {
  const texto = (data?.texto ?? '').trim();
  if (texto === '') return { compra: null };

  const soloDigitos = texto.replace(/[^0-9]/g, '');
  let doc = null;

  if (soloDigitos !== '') {
    const sinCeros = soloDigitos.replace(/^0+/, '');
    const correlativo = (sinCeros === '' ? 0 : parseInt(sinCeros, 10)).toString().padStart(5, '0');
    const porDocumento = await db.collection('compras').where('numeroDocumento', '==', correlativo).limit(1).get();
    if (!porDocumento.empty) doc = porDocumento.docs[0];
  }
  if (!doc) {
    const porFactura = await db.collection('compras').where('noFactura', '==', texto).limit(1).get();
    if (!porFactura.empty) doc = porFactura.docs[0];
  }
  if (!doc) return { compra: null };
  return { compra: await obtenerCompraConDetalle(doc) };
});

// ---------- Total del Reporte de Ventas / Compras (sin filtros) ----------
//
// Reporte de Ventas/Compras (a diferencia del resto de las funciones de
// arriba) no trae la lista completa por acá: eso lo sigue haciendo el
// cliente, pero paginado (ver ReporteRepository.obtenerPaginaVentas), para
// que la pantalla pinte algo casi al instante sin importar cuántos meses
// abarque el rango. Lo único que SÍ conviene resolver del lado del servidor
// es el total del período: sumarlo requeriría traer todos los documentos, lo
// mismo que la paginación busca evitar. Con `aggregate(sum())` Firestore da
// el total sin bajar los documentos, usando el mismo índice compuesto que ya
// existe para la serie mensual del Reporte Financiero.

exports.totalReporteVentas = conManejoDeErrores('totalReporteVentas', async (data) => {
  const inicioMillis = requerirNumero(data, 'inicioMillis');
  const finMillis = requerirNumero(data, 'finMillis');
  try {
    const resultado = await db
      .collection('ventas')
      .where('estado', '==', 'Activa')
      .where('tipoDocumento', 'in', ['Factura', 'Boleta', 'Venta'])
      .where('fechaRegistro', '>=', ts(inicioMillis))
      .where('fechaRegistro', '<=', ts(finMillis))
      .aggregate({ total: AggregateField.sum('totalAPagar'), cantidad: AggregateField.count() })
      .get();
    const datos = resultado.data();
    return { total: c.num(datos.total), cantidad: datos.cantidad };
  } catch (error) {
    console.warn('totalReporteVentas: agregación falló, se recalcula sumando documentos:', error.message);
    const ventas = (await leerVentasRango(inicioMillis, finMillis)).filter(c.ventaEsValida);
    return { total: c.sumar(ventas, (v) => v.totalAPagar), cantidad: ventas.length };
  }
});

exports.totalReporteCompras = conManejoDeErrores('totalReporteCompras', async (data) => {
  const inicioMillis = requerirNumero(data, 'inicioMillis');
  const finMillis = requerirNumero(data, 'finMillis');
  try {
    const resultado = await db
      .collection('compras')
      .where('estado', '==', 'Activa')
      .where('fechaRegistro', '>=', ts(inicioMillis))
      .where('fechaRegistro', '<=', ts(finMillis))
      .aggregate({ total: AggregateField.sum('totalAPagar'), cantidad: AggregateField.count() })
      .get();
    const datos = resultado.data();
    return { total: c.num(datos.total), cantidad: datos.cantidad };
  } catch (error) {
    console.warn('totalReporteCompras: agregación falló, se recalcula sumando documentos:', error.message);
    const compras = (await leerComprasRango(inicioMillis, finMillis)).filter((x) => x.estado === 'Activa');
    return { total: c.sumar(compras, (x) => x.montoTotal), cantidad: compras.length };
  }
});
