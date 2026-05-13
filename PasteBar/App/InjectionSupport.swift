#if DEBUG
@_exported import Inject

enum InjectionSupport {
  static func load() {
    _ = InjectConfiguration.load
  }
}
#else
enum InjectionSupport {
  static func load() {}
}
#endif
