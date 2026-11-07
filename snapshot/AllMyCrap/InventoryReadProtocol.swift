import Foundation
import CryptoKit
import CoreFoundation

/// In-process prototype protocol: explicit injected identities, never store discovery.
enum InventoryWire {
    static let requestLimit = 16 * 1024
    static let responseLimit = 2 * 1024 * 1024
    enum Failure: String, Error { case invalid, binding, oversized, unavailable, cancelled, transport }
    static func canonical(_ object: Any) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object) else { throw Failure.invalid }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }
    static func object(_ data: Data, limit: Int) throws -> [String: Any] {
        guard data.count <= limit else { throw Failure.oversized }
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any], try canonical(value) == data else { throw Failure.invalid }
        return value // Canonical equality also rejects duplicate JSON keys/ambiguous encodings.
    }
    static func digest(_ object: [String: Any]) throws -> String {
        SHA256.hash(data: try canonical(object)).map { String(format: "%02x", $0) }.joined()
    }
    static func isBoolean(_ value: Any?) -> Bool {
        guard let n = value as? NSNumber else { return false }; return CFGetTypeID(n) == CFBooleanGetTypeID()
    }
    static func uuid(_ value: Any?) throws -> String {
        guard let text = value as? String, let id = UUID(uuidString: text), id.uuidString.lowercased() == text else { throw Failure.invalid }
        return text
    }
    struct Binding: Equatable {
        let device: String, store: String, client: String, scope: String
        init(device: String, store: String, client: String, scope: String) throws {
            self.device = try uuid(device); self.store = try uuid(store)
            self.client = try uuid(client); self.scope = try uuid(scope)
        }
        var fields: [String: Any] { ["device":device,"store":store,"client":client,"scope":scope] }
    }
    enum Operation {
        case status
        case list(InventoryReadAdapter.Kind, InventoryReadAdapter.ArchiveScope, Int, String?)
        case show(InventoryReadAdapter.Kind, UUID)
    }
    struct Request {
        let id: String, digest: String, binding: Binding, operation: Operation
        init(_ data: Data, expected: Binding) throws {
            var o = try object(data, limit: requestLimit)
            guard Set(o.keys) == Set(["version","request","digest","device","store","client","scope","arguments"]), o["version"] as? Int == 1,
                  !isBoolean(o["version"]), let hash = o.removeValue(forKey: "digest") as? String, try InventoryWire.digest(o) == hash else { throw Failure.invalid }
            id = try uuid(o["request"]); digest = hash
            binding = try Binding(device:uuid(o["device"]),store:uuid(o["store"]),client:uuid(o["client"]),scope:uuid(o["scope"]))
            guard binding == expected else { throw Failure.binding }
            guard let a = o["arguments"] as? [String:Any], let op = a["op"] as? String else { throw Failure.invalid }
            switch op {
            case "status": guard Set(a.keys)==["op"] else { throw Failure.invalid }; operation = .status
            case "list":
                guard Set(a.keys)==["op","kind","archive","size","cursor"], let k = a["kind"] as? String, let kind = InventoryReadAdapter.Kind(rawValue:k), let v = a["archive"] as? String, let archive = InventoryReadAdapter.ArchiveScope(rawValue:v), let size = a["size"] as? Int, !isBoolean(a["size"]), (1...100).contains(size), kind == .items || archive == .all else { throw Failure.invalid }
                let cursor: String?
                if a["cursor"] is NSNull { cursor = nil } else { guard let text = a["cursor"] as? String, text.utf8.count <= 2048 else { throw Failure.invalid }; cursor = text }
                operation = .list(kind,archive,size,cursor)
            case "show":
                guard Set(a.keys)==["op","kind","id"], let k = a["kind"] as? String, let kind = InventoryReadAdapter.Kind(rawValue:k), let id = UUID(uuidString:try uuid(a["id"])) else { throw Failure.invalid }
                operation = .show(kind,id)
            default: throw Failure.invalid
            }
        }
        var fields: [String:Any] { binding.fields.merging(["version":1,"request":id,"digest":digest],uniquingKeysWith: { _,new in new }) }
    }
}
