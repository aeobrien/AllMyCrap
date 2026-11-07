import Foundation
import SwiftData

@MainActor
final class InventorySessionReads {
    private let reader: InventoryReadAdapter
    let binding: InventoryWire.Binding
    init(context: ModelContext, binding: InventoryWire.Binding) {
        self.reader = InventoryReadAdapter(context:context); self.binding = binding
    }
    func respond(_ data: Data) throws -> Data {
        let request = try InventoryWire.Request(data,expected:binding)
        var reply = request.fields
        reply["observed_at"] = ISO8601DateFormatter().string(from:Date())
        reply["build"] = "inventory-foreground-prototype-v1"
        reply["transactionalSnapshot"] = false
        do {
            let encoded: Data
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970
            switch request.operation {
            case .status: encoded = try encoder.encode(reader.status())
            case .list(let kind,let archive,let size,let cursor): encoded = try encoder.encode(reader.list(kind:kind,archive:archive,pageSize:size,cursor:cursor))
            case .show(let kind,let id): encoded = try encoder.encode(reader.show(kind:kind,id:id))
            }
            reply["result"] = try JSONSerialization.jsonObject(with:encoded); reply["error"] = NSNull()
        } catch let error as InventoryReadAdapter.Failure {
            reply["result"] = NSNull(); reply["error"] = String(describing:error)
        } catch {
            // Do not leak model paths or underlying store details.
            reply["result"] = NSNull(); reply["error"] = "readUnavailable"
        }
        let result = try InventoryWire.canonical(reply)
        guard result.count <= InventoryWire.responseLimit else { throw InventoryWire.Failure.oversized }
        return result
    }
}
