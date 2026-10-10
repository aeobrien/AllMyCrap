import Foundation
import SwiftData

/// Configured externally; never discovers a store, host or credential itself.
@MainActor
final class InventoryForegroundReadWorker {
    struct Configuration {
        let device: String, store: String, client: String
        let makeTransport: () throws -> InventoryMailboxTransport
    }
    private let context: ModelContext
    private let configuration: Configuration?
    private var generation = UUID()
    private var task: Task<Void,Never>?
    private var transport: InventoryMailboxTransport?
    private(set) var state = "unconfigured"
    init(context: ModelContext, configuration: Configuration? = nil) {
        self.context = context; self.configuration = configuration
        if configuration != nil { state = "inactive" }
    }
    func setActive(_ active: Bool) {
        if !active {
            generation = UUID(); task?.cancel(); task = nil
            transport?.close(); transport = nil
            state = configuration == nil ? "unconfigured" : "inactive"
            // Mailbox liveness expires independently; shutdown never needs network.
            return
        }
        guard task == nil, let config = configuration else { return }
        let token = UUID(); generation = token
        do {
            let binding = try InventoryWire.Binding(device:config.device,store:config.store,client:config.client,scope:token.uuidString.lowercased())
            let service = InventorySessionReads(context:context,binding:binding)
            let wire = try config.makeTransport(); transport = wire; state = "starting"
            task = Task { [weak self] in
                do {
                    _ = try await wire.post("worker/hello",InventoryWire.canonical(binding.fields))
                    while !Task.isCancelled, self?.generation == token {
                        self?.state = "active"
                        let packet = try await wire.post("worker/next",InventoryWire.canonical(binding.fields))
                        try Task.checkCancellation()
                        guard self?.generation == token else { break }
                        let body = try InventoryWire.object(packet,limit:InventoryWire.requestLimit)
                        if !body.isEmpty {
                            let reply = try service.respond(packet)
                            try Task.checkCancellation()
                            guard self?.generation == token else { break }
                            _ = try await wire.post("worker/result",reply)
                        }
                        try await Task.sleep(nanoseconds:1_000_000_000)
                    }
                } catch { if let owner = self, owner.generation == token { owner.state = Task.isCancelled ? "inactive" : "unavailable" } }
                wire.close()
                if let owner = self, owner.generation == token { owner.task = nil; owner.transport = nil }
            }
        } catch { state = "unavailable" }
    }
    deinit { task?.cancel(); transport?.close() }
}
