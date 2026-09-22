const test = require('node:test');
const assert = require('node:assert/strict');
const c = require('../calculos.js');

test('tasaComisionProducto: 7% bajo el umbral, 10% desde 30', () => {
  assert.equal(c.tasaComisionProducto(29.99), 0.07);
  assert.equal(c.tasaComisionProducto(30), 0.10);
  assert.equal(c.tasaComisionProducto(0), 0.07);
});

test('ventaEsValida: excluye anuladas y cotizaciones', () => {
  assert.equal(c.ventaEsValida({ estado: 'Activa', tipoDocumento: 'Factura' }), true);
  assert.equal(c.ventaEsValida({ estado: 'Anulada', tipoDocumento: 'Factura' }), false);
  assert.equal(c.ventaEsValida({ estado: 'Activa', tipoDocumento: 'Cotizacion' }), false);
});

test('flujoDeMovimientos: reparte una venta con pago mixto en cada método', () => {
  const flujo = c.flujoDeMovimientos({
    ventas: [
      {
        estado: 'Activa',
        tipoDocumento: 'Factura',
        condicion: 'Contado',
        metodoPago: 'Mixto',
        totalAPagar: 300,
        pagosMixtos: [
          { metodoPago: 'Efectivo', monto: 100 },
          { metodoPago: 'Tarjeta', monto: 200 },
        ],
      },
      { estado: 'Activa', tipoDocumento: 'Factura', condicion: 'Contado', metodoPago: 'Transferencia', totalAPagar: 50, pagosMixtos: [] },
      // Anulada: no debe sumar nada.
      { estado: 'Anulada', tipoDocumento: 'Factura', condicion: 'Contado', metodoPago: 'Efectivo', totalAPagar: 999, pagosMixtos: [] },
      // A crédito: no es "de contado", no debe sumar acá.
      { estado: 'Activa', tipoDocumento: 'Factura', condicion: 'Credito', metodoPago: 'N/A', totalAPagar: 500, pagosMixtos: [] },
    ],
    compras: [{ estado: 'Activa', condicion: 'Contado', metodoPago: 'Efectivo', montoTotal: 40 }],
    abonosVenta: [{ metodoPago: 'Efectivo', montoAbonado: 20 }],
    abonosCompra: [{ metodoPago: 'Transferencia', montoAbonado: 10 }],
    egresos: [{ metodoPago: 'Efectivo', monto: 5 }],
  });

  assert.equal(flujo.ingresosEfectivo, 100 + 20);
  assert.equal(flujo.ingresosTarjeta, 200);
  assert.equal(flujo.ingresosTransferencia, 50);
  assert.equal(flujo.egresosEfectivo, 40 + 5);
  assert.equal(flujo.egresosTransferencia, 10);
});

test('construirLibroFinanciero: una venta mixta genera un movimiento por método', () => {
  const movimientos = c.construirLibroFinanciero({
    ventas: [
      {
        estado: 'Activa',
        tipoDocumento: 'Factura',
        condicion: 'Contado',
        metodoPago: 'Mixto',
        totalAPagar: 150,
        numeroDocumento: '00000001',
        nombreCliente: '',
        usuarioRegistro: 'Ana',
        fechaRegistro: 1000,
        pagosMixtos: [
          { metodoPago: 'Efectivo', monto: 50 },
          { metodoPago: 'Tarjeta', monto: 100 },
        ],
      },
    ],
    compras: [],
    abonosVenta: [],
    abonosCompra: [],
    egresos: [],
  });
  assert.equal(movimientos.length, 2);
  assert.equal(movimientos[0].tipoMovimiento, 'Venta (Contado)');
  assert.ok(movimientos.every((m) => m.descripcion.includes('(mixto)')));
  assert.equal(movimientos.reduce((s, m) => s + m.ingreso, 0), 150);
});

test('construirLibroFinanciero: compras a crédito y no activas quedan afuera', () => {
  const movimientos = c.construirLibroFinanciero({
    ventas: [],
    compras: [
      { estado: 'Activa', condicion: 'Credito', montoTotal: 100, metodoPago: 'N/A', numeroDocumento: '1', razonSocial: 'X', fechaRegistro: 1, usuarioRegistro: '' },
      { estado: 'Anulada', condicion: 'Contado', montoTotal: 200, metodoPago: 'Efectivo', numeroDocumento: '2', razonSocial: 'Y', fechaRegistro: 1, usuarioRegistro: '' },
      { estado: 'Activa', condicion: 'Contado', montoTotal: 30, metodoPago: 'Efectivo', numeroDocumento: '3', razonSocial: 'Z', fechaRegistro: 1, usuarioRegistro: '' },
    ],
    abonosVenta: [],
    abonosCompra: [],
    egresos: [],
  });
  assert.equal(movimientos.length, 1);
  assert.equal(movimientos[0].egreso, 30);
});

test('calcularTotalesCaja: suma por método de pago desde el libro', () => {
  const movimientos = [
    { ingreso: 100, egreso: 0, metodoPago: 'Efectivo' },
    { ingreso: 50, egreso: 0, metodoPago: 'Tarjeta' },
    { ingreso: 0, egreso: 20, metodoPago: 'Efectivo' },
    { ingreso: 0, egreso: 10, metodoPago: 'Transferencia' },
  ];
  const totales = c.calcularTotalesCaja(movimientos);
  assert.deepEqual(totales, {
    ingresosEfectivo: 100,
    ingresosTarjeta: 50,
    ingresosTransferencia: 0,
    egresosEfectivo: 20,
    egresosTransferencia: 10,
  });
});

function linea({ idVenta = 'v1', numeroDocumento = '1', fecha = 1, cliente = 'Juan', item }) {
  return { idVenta, numeroDocumento, fecha, cliente, item };
}

test('calcularComisiones: cortes por barbero y filtro por barbero', () => {
  const lineas = [
    linea({ item: { esServicio: true, idBarbero: 'b1', nombreBarbero: 'Beto', cantidad: 1, subtotal: 100, pctComisionBarbero: 50, vendidoPorTipo: 'N/A', vendidoPorId: '', vendidoPorNombre: '', nombreProducto: 'Corte' } }),
    linea({ item: { esServicio: true, idBarbero: 'b2', nombreBarbero: 'Mario', cantidad: 1, subtotal: 200, pctComisionBarbero: 40, vendidoPorTipo: 'N/A', vendidoPorId: '', vendidoPorNombre: '', nombreProducto: 'Corte' } }),
  ];
  const todos = c.calcularComisiones({ lineas, tipoFiltro: null, idFiltro: null });
  assert.equal(todos.cortes.length, 2);
  assert.equal(todos.cortes[0].nombreBarbero, 'Mario');
  assert.equal(todos.cortes[0].comisionTotal, 80);

  const filtrado = c.calcularComisiones({ lineas, tipoFiltro: 'Barbero', idFiltro: 'b1' });
  assert.equal(filtrado.cortes.length, 1);
  assert.equal(filtrado.cortes[0].idBarbero, 'b1');

  const comoUsuario = c.calcularComisiones({ lineas, tipoFiltro: 'Usuario', idFiltro: 'u1' });
  assert.equal(comoUsuario.cortes.length, 0);
});

test('calcularComisiones: tramo de producto sube a 10% desde 30 unidades', () => {
  const lineas = [
    linea({
      item: {
        esServicio: false,
        idBarbero: '',
        nombreBarbero: '',
        cantidad: 35,
        subtotal: 1000,
        pctComisionBarbero: 0,
        vendidoPorTipo: 'Usuario',
        vendidoPorId: 'u1',
        vendidoPorNombre: 'Carlos',
        nombreProducto: 'Cera',
      },
    }),
  ];
  const { productos } = c.calcularComisiones({ lineas, tipoFiltro: null, idFiltro: null });
  assert.equal(productos.length, 1);
  assert.equal(productos[0].tasa, 0.10);
  assert.equal(productos[0].comisionTotal, 100);
});

test('calcularReporte: totales básicos con una venta y una compra', () => {
  const reporte = c.calcularReporte({
    ventas: [{ id: 'v1', estado: 'Activa', tipoDocumento: 'Factura', condicion: 'Contado', metodoPago: 'Efectivo', totalAPagar: 100, numeroDocumento: '1', nombreCliente: '', usuarioRegistro: 'Ana', fechaRegistro: 1, pagosMixtos: [] }],
    compras: [{ id: 'c1', estado: 'Activa', condicion: 'Contado', metodoPago: 'Efectivo', montoTotal: 30, numeroDocumento: '1', razonSocial: 'Prov', fechaRegistro: 1, usuarioRegistro: '' }],
    detalleVentas: new Map([['v1', [{ idProducto: 'p1', nombreProducto: 'Cera', cantidad: 1, subtotal: 100, precioCompraUsado: 40, esServicio: false }]]]),
    detalleCompras: new Map(),
    egresos: [],
    abonosVenta: [],
    abonosCompra: [],
    productos: [{ id: 'p1', nombre: 'Cera', stock: 5, precioCompra: 40, estado: true }, { id: 'p2', nombre: 'Gel', stock: 2, precioCompra: 20, estado: true }],
    creditosVenta: [],
    creditosCompra: [],
    serieMensual: [],
    efectivoEstimado: 0,
    cierresCaja: [{ id: 'cc1', totalReal: 500 }],
  });

  assert.equal(reporte.ventasPeriodo, 100);
  assert.equal(reporte.comprasPeriodo, 30);
  assert.equal(reporte.costoVentas, 40);
  assert.equal(reporte.utilidadBruta, 60);
  assert.equal(reporte.productosSinVenta.length, 1);
  assert.equal(reporte.productosSinVenta[0].idProducto, 'p2');
  assert.equal(reporte.balanceGeneral.inventarioACosto, 5 * 40 + 2 * 20);
  assert.equal(reporte.cierresCaja.length, 1);
  assert.equal(reporte.cierresCaja[0].id, 'cc1');
});

test('normalizarCierreCaja: convierte Timestamps a millis y respeta valores', () => {
  const cierre = c.normalizarCierreCaja('cc1', {
    fechaInicio: { toMillis: () => 1000 },
    fechaFin: { toMillis: () => 2000 },
    montoInicial: 50,
    totalReal: 500,
    diferencia: -10,
    usuarioResponsable: 'Ana',
  });
  assert.equal(cierre.id, 'cc1');
  assert.equal(cierre.fechaInicio, 1000);
  assert.equal(cierre.fechaFin, 2000);
  assert.equal(cierre.totalReal, 500);
  assert.equal(cierre.diferencia, -10);
  assert.equal(cierre.usuarioResponsable, 'Ana');
});
