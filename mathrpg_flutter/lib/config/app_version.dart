class AppVersion {
  static const version =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
  static const buildDate =
      String.fromEnvironment('BUILD_DATE', defaultValue: '');
}
