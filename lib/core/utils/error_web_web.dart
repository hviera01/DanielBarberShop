import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// En web, cuando una excepción de Dart se lanza dentro del callback de una
/// transacción de Firestore, el SDK de JavaScript la devuelve envuelta en un
/// error genérico ("Dart exception thrown from converted Future...") que
/// esconde la causa real. La excepción original viene en su propiedad
/// 'error'.
Object desenvolverErrorBoxed(Object e) {
  try {
    final js = e as JSAny?;
    if (js == null || !js.isA<JSObject>()) return e;
    final interno = (js as JSObject).getProperty<JSAny?>('error'.toJS);
    if (interno != null && interno.isA<JSBoxedDartObject>()) {
      return (interno as JSBoxedDartObject).toDart;
    }
  } catch (_) {}
  return e;
}
