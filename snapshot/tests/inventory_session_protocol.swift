import Foundation
import SwiftData

final class DelayedFixtureTransport: InventoryMailboxTransport {
 var calls:[String]=[]; var pending:CheckedContinuation<Data,Error>?; var hello:[String:Any]=[:]; var closes=0
 func post(_ path:String,_ body:Data) async throws -> Data {
  calls.append(path)
  if path=="worker/hello" {hello=try InventoryWire.object(body,limit:InventoryWire.requestLimit)}
  if path=="worker/next" {return try await withCheckedThrowingContinuation { pending=$0 }}
  return Data("{}".utf8)
 }
 func close() {closes+=1}
}
@main struct ProtocolTests {
 @MainActor static func main() async throws {
  let base=URL(fileURLWithPath:ProcessInfo.processInfo.environment["INVENTORY_FIXTURE_ROOT"]!)
  let schema=Schema([Location.self,Item.self,Tag.self,ReviewHistory.self,DuplicateExclusion.self])
  let container=try ModelContainer(for:schema,configurations:[ModelConfiguration("Fixture",schema:schema,url:base.appendingPathComponent("fixture.store"),cloudKitDatabase:.none)])
  let context=ModelContext(container);context.autosaveEnabled=false
  let binding=try InventoryWire.Binding(device:UUID().uuidString.lowercased(),store:UUID().uuidString.lowercased(),client:UUID().uuidString.lowercased(),scope:UUID().uuidString.lowercased())
  let service=InventorySessionReads(context:context,binding:binding)
  var passed=0
  func check(_ value:Bool) { precondition(value);passed+=1 }
  func packet(_ a:[String:Any],_ b:InventoryWire.Binding?=nil) throws -> Data {
   var o=(b ?? binding).fields;o["version"]=1;o["request"]=UUID().uuidString.lowercased();o["arguments"]=a;o["digest"]=try InventoryWire.digest(o);return try InventoryWire.canonical(o)
  }
  func response(_ a:[String:Any]) throws -> [String:Any] { try InventoryWire.object(service.respond(packet(a)),limit:InventoryWire.responseLimit) }
  let one=Item(name:"Synthetic"),two=Item(name:"Synthetic");context.insert(one);context.insert(two)
  check(context.hasChanges);check(try response(["op":"status"])["error"] as? String == "pendingEdits");check(context.hasChanges)
  try context.save()
  let status=try response(["op":"status"]);check(status["transactionalSnapshot"] as? Bool == false)
  check(((status["result"] as! [String:Any])["counts"] as! [String:Any])["items"] as? Int == 2)
  var list:[String:Any] = ["op":"list","kind":"items","archive":"all","size":1,"cursor":NSNull()]
  let first=try response(list)["result"] as! [String:Any];let cursor=first["next"] as! String;list["cursor"]=cursor
  let second=try response(list)["result"] as! [String:Any];check(first["scope"] as? String == second["scope"] as? String);check(second["complete"] as? Bool == true)
  let another=InventorySessionReads(context:context,binding:binding)
  check(try InventoryWire.object(another.respond(packet(list)),limit:InventoryWire.responseLimit)["error"] as? String == "invalidCursor")
  one.name="Saved";try context.save();check(try response(list)["error"] as? String == "staleCursor")
  check(try response(["op":"show","kind":"items","id":UUID().uuidString.lowercased()])["error"] as? String == "notFound")
  for arguments in [["op":"remove"],["op":"status","path":"/SYNTHETIC"]] {
   do {_ = try service.respond(packet(arguments));fatalError("accepted unsupported") }catch is InventoryWire.Failure {passed+=1}
  }
  var wrong=binding.fields;wrong["store"]=UUID().uuidString.lowercased()
  let wrongBinding=try InventoryWire.Binding(device:wrong["device"] as! String,store:wrong["store"] as! String,client:wrong["client"] as! String,scope:wrong["scope"] as! String)
  do {_ = try service.respond(packet(["op":"status"],wrongBinding));fatalError("wrong binding") }catch InventoryWire.Failure.binding {passed+=1}
  let raw=try packet(["op":"status"]);let duplicate=Data((String(data:raw,encoding:.utf8)!.dropLast()+",\"version\":1}").utf8)
  do {_ = try service.respond(duplicate);fatalError("duplicate") }catch InventoryWire.Failure.invalid {passed+=1}
  check(!context.hasChanges)
  let disabled=InventoryForegroundReadWorker(context:context);disabled.setActive(true);check(disabled.state=="unconfigured");disabled.setActive(false);check(disabled.state=="unconfigured")
  check(try context.fetchCount(FetchDescriptor<Item>())==2)
  let fake=DelayedFixtureTransport()
  let worker=InventoryForegroundReadWorker(context:context,configuration:.init(device:binding.device,store:binding.store,client:binding.client,makeTransport:{fake}))
  worker.setActive(true);worker.setActive(true)
  for _ in 0..<100 {if fake.pending != nil {break};try await Task.sleep(nanoseconds:10_000_000)}
  check(fake.calls.filter {$0=="worker/hello"}.count==1 && fake.pending != nil)
  worker.setActive(false);check(worker.state=="inactive")
  var late=fake.hello;late["version"]=1;late["request"]=UUID().uuidString.lowercased();late["arguments"]=["op":"status"];late["digest"]=try InventoryWire.digest(late)
  fake.pending?.resume(returning:try InventoryWire.canonical(late));fake.pending=nil
  try await Task.sleep(nanoseconds:100_000_000)
  check(!fake.calls.contains("worker/result"));check(fake.closes>=1)
  for endpoint in ["http://example.invalid","http://localhost:12345","https://user:pass@example.invalid","https://example.invalid/path"] {
   do {_ = try InventoryURLSessionTransport(endpoint:URL(string:endpoint)!,credential:"fixture",allowLoopbackHTTP:true);fatalError("invalid endpoint")}catch InventoryWire.Failure.invalid {passed+=1}
  }
  let otherContainer=try ModelContainer(for:schema,configurations:[ModelConfiguration("OtherFixture",schema:schema,url:base.appendingPathComponent("other.store"),cloudKitDatabase:.none)])
  let otherContext=ModelContext(otherContainer);otherContext.autosaveEnabled=false;otherContext.insert(Item(name:"Other store"));try otherContext.save()
  let otherService=InventorySessionReads(context:otherContext,binding:wrongBinding)
  let otherReply=try InventoryWire.object(otherService.respond(packet(["op":"status"],wrongBinding)),limit:InventoryWire.responseLimit)
  check(((otherReply["result"] as! [String:Any])["counts"] as! [String:Any])["items"] as? Int == 1)
  check(try InventoryWire.object(otherService.respond(packet(["op":"show","kind":"items","id":one.id.uuidString.lowercased()],wrongBinding)),limit:InventoryWire.responseLimit)["error"] as? String == "notFound")
  let abandonedTransport=DelayedFixtureTransport()
  var abandoned:InventoryForegroundReadWorker?=InventoryForegroundReadWorker(context:context,configuration:.init(device:binding.device,store:binding.store,client:binding.client,makeTransport:{abandonedTransport}))
  weak var observed=abandoned;abandoned?.setActive(true)
  for _ in 0..<100 {if abandonedTransport.pending != nil {break};try await Task.sleep(nanoseconds:10_000_000)}
  check(abandonedTransport.pending != nil);abandoned=nil
  check(observed == nil && abandonedTransport.closes>=1)
  abandonedTransport.pending?.resume(returning:Data("{}".utf8));abandonedTransport.pending=nil
  try await Task.sleep(nanoseconds:20_000_000)
  precondition(passed==30);print("PROTOCOL_RESULT="+String(passed))
 }
}
