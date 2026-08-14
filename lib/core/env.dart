class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ws.test.ds-clickeat.com.mx/api/admin/',
  );
}
