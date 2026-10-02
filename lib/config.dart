/// URL base de la web Laravel (sin barra final). Se puede cambiar al compilar:
/// flutter run --dart-define=API_URL=https://mi-tienda.com
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

/// Cada cuántos segundos la app consulta cambios hechos en la web.
const int syncSeconds = 5;
