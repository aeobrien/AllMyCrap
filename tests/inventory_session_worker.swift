import Foundation
import SwiftData

/// Disposable process entry only, never included in application target.
@main struct FixtureWorker {
 @MainActor static func main() async throws {
  let root=URL(fileURLWithPath:CommandLine.arguments[1]);let cfg=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("config.json"))) as! [String:String]
  let schema=Schema([Location.self,Item.self,Tag.self,ReviewHistory.self,DuplicateExclusion.self])
  let container=try ModelContainer(for:schema,configurations:[ModelConfiguration("HTTPFixture",schema:schema,url:root.appendingPathComponent("fixture.store"),cloudKitDatabase:.none)])
  let context=ModelContext(container);context.autosaveEnabled=false
  let location=Location(name:"Synthetic room"),tag=Tag(name:"Synthetic tag",color:"#123456")
  context.insert(location);context.insert(tag)
  let items=(0..<3).map {_ in Item(name:"Synthetic same name",location:location)}
  for item in items {context.insert(item)}
  try context.save()
  let worker=InventoryForegroundReadWorker(context:context,configuration:.init(device:cfg["device"]!,store:cfg["store"]!,client:cfg["client"]!,makeTransport:{ try InventoryURLSessionTransport(endpoint:URL(string:cfg["endpoint"]!)!,credential:cfg["token"]!,allowLoopbackHTTP:true) }))
  func write(_ name:String,_ value:[String:Any]) throws {try InventoryWire.canonical(value).write(to:root.appendingPathComponent(name),options:.atomic)}
  worker.setActive(true)
  try write("ready.json",["items":items.map {$0.id.uuidString.lowercased()},"locations":[location.id.uuidString.lowercased()],"tags":[tag.id.uuidString.lowercased()]])
  var last=0;var stop=false;let deadline=Date().addingTimeInterval(90)
  while !stop && Date()<deadline {
   if let raw=try? Data(contentsOf:root.appendingPathComponent("control.json")),let c=try? JSONSerialization.jsonObject(with:raw) as? [String:Any],let sequence=c["sequence"] as? Int,sequence>last,let action=c["action"] as? String {
    last=sequence;var result:[String:Any]=["sequence":sequence]
    switch action {
    case "edit":items[0].name="Synthetic changed"
    case "save":result["pending_before_save"]=context.hasChanges;try context.save()
    case "inactive":worker.setActive(false)
    case "active":worker.setActive(true)
    case "inspect":result["item_count"]=try context.fetchCount(FetchDescriptor<Item>())
    case "stop":worker.setActive(false);stop=true
    default:fatalError("Unknown synthetic control")
    }
    result["state"]=worker.state;try write("control-\(sequence).json",result)
   }
   try await Task.sleep(nanoseconds:10_000_000)
  }
  worker.setActive(false)
  if !stop {throw InventoryWire.Failure.unavailable}
 }
}
