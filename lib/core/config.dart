class AppConfig {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
  static const reverbHost = String.fromEnvironment(
    'REVERB_HOST',
    defaultValue: '10.0.2.2',
  );
  static const reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 8080,
  );
  static const reverbKey = String.fromEnvironment('REVERB_APP_KEY');
  static const reverbTls = bool.fromEnvironment(
    'REVERB_TLS',
    defaultValue: false,
  );

  /// Backend `asset()` / `APP_URL` often emit localhost; emulators and phones
  /// cannot reach the host that way. Rewrite to the API host from [apiUrl].
  static String resolveMediaUrl(String url) {
    if (url.isEmpty) return url;
    final media = Uri.tryParse(url);
    if (media == null || !media.hasScheme || media.host.isEmpty) return url;
    final host = media.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1') return url;
    final api = Uri.parse(apiUrl);
    return media
        .replace(
          host: api.host,
          port: api.hasPort ? api.port : null,
        )
        .toString();
  }
}
