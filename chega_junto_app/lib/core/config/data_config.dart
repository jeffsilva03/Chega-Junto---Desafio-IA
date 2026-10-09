enum DataSourceMode { mock, api }

class DataConfig {
  const DataConfig({this.mode = DataSourceMode.mock, this.baseUrl = ''});
  factory DataConfig.environment() {
    const source = String.fromEnvironment('DATA_SOURCE', defaultValue: 'mock');
    if (!['mock', 'api'].contains(source)) {
      throw ArgumentError('DATA_SOURCE deve ser mock ou api.');
    }
    return DataConfig(
      mode: DataSourceMode.values.byName(source),
      baseUrl: const String.fromEnvironment('API_BASE_URL'),
    );
  }
  final DataSourceMode mode;
  final String baseUrl;
  static const connectTimeout = Duration(seconds: 30);
  static const requestTimeout = Duration(seconds: 90);
}
