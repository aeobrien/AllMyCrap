import Foundation

protocol InventoryMailboxTransport: AnyObject {
    func post(_ path: String, _ body: Data) async throws -> Data
    func close()
}

final class InventoryURLSessionTransport: NSObject, InventoryMailboxTransport, URLSessionTaskDelegate, @unchecked Sendable {
    private let endpoint: URL
    private let credential: String
    private var session: URLSession!
    init(endpoint: URL, credential: String, allowLoopbackHTTP: Bool = false) throws {
        guard let c = URLComponents(url:endpoint,resolvingAgainstBaseURL:false), c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              c.path.isEmpty || c.path == "/", let host = c.host, !host.isEmpty,
              c.scheme == "https" || (allowLoopbackHTTP && c.scheme == "http" && host == "127.0.0.1"),
              !credential.isEmpty, credential.utf8.count <= 512, credential.allSatisfy({ $0.isASCII && !$0.isWhitespace }) else { throw InventoryWire.Failure.invalid }
        self.endpoint = endpoint; self.credential = credential
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCache = nil; config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 3; config.timeoutIntervalForResource = 5
        config.connectionProxyDictionary = [:]
        session = URLSession(configuration:config,delegate:self,delegateQueue:nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func post(_ path: String, _ body: Data) async throws -> Data {
        guard ["worker/hello","worker/next","worker/result","worker/offline"].contains(path), body.count <= InventoryWire.responseLimit else { throw InventoryWire.Failure.invalid }
        var request = URLRequest(url:endpoint.appendingPathComponent(path))
        request.httpMethod = "POST"; request.httpBody = body
        request.setValue("Bearer " + credential,forHTTPHeaderField:"Authorization")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        let (stream,response) = try await session.bytes(for:request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw InventoryWire.Failure.transport }
        if response.expectedContentLength > InventoryWire.responseLimit { throw InventoryWire.Failure.oversized }
        var data = Data()
        for try await byte in stream {
            try Task.checkCancellation()
            guard data.count < InventoryWire.responseLimit else { throw InventoryWire.Failure.oversized }
            data.append(byte)
        }
        return data
    }
    func close() { session.invalidateAndCancel() }
}
