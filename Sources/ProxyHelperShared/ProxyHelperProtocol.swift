import Foundation

public enum ProxyHelperConstants {
    public static let machServiceName = "com.catbar.helper"
    public static let daemonPlistName = "com.catbar.helper.plist"
    public static let helperBundleProgram = "Contents/Library/HelperTools/com.catbar.helper"
    public static let allowedClientBundleIdentifier = "com.catbar"
    public static let allowedClientRequirement = "identifier \"\(allowedClientBundleIdentifier)\""
}

@objc(ProxyHelperProtocol)
public protocol ProxyHelperProtocol {
    func ping(completion: @escaping (Bool, String?) -> Void)
    func setSystemProxy(
        host: String,
        httpPort: Int,
        httpsPort: Int,
        socksPort: Int,
        completion: @escaping (Bool, String?) -> Void)
    func clearSystemProxy(completion: @escaping (Bool, String?) -> Void)
    func getSystemProxyState(completion: @escaping (Bool, Bool, String?) -> Void)
    func getSystemProxyActiveTarget(completion: @escaping (Bool, String?, Int, String?) -> Void)
    func isSystemProxyConfigured(
        host: String,
        httpPort: Int,
        httpsPort: Int,
        socksPort: Int,
        completion: @escaping (Bool, Bool, String?) -> Void)
}
