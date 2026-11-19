import Foundation
import SwiftData

@main struct IndependentMutationChecks {
    @MainActor static func main() throws {
        func check(_ value: Bool) { precondition(value) }
        let url=URL(fileURLWithPath:ProcessInfo.processInfo.environment["INVENTORY_AUDIT_STORE"]!)
        let schema=Schema([Location.self,Item.self,Tag.self,ReviewHistory.self,DuplicateExclusion.self])
        let container=try ModelContainer(for:schema,configurations:[ModelConfiguration("Independent",schema:schema,url:url,cloudKitDatabase:.none)])
        let c=ModelContext(container);c.autosaveEnabled=false
        let a=Location(name:"Identical"), b=Location(name:"Identical"), child=Location(name:"Box",parent:a)
        let book=Item(title:"Synthetic book",author:"Synthetic author",location:child)
        book.plan = .move;book.moveDestination="Later destination";book.isArchived=true;book.archivedDate=Date(timeIntervalSince1970:100)
        let kept=Item(name:"Keep",location:b), detached=Item(name:"Detached")
        let tag=Tag(name:"Synthetic")
        book.tags=[tag];kept.tags=[tag]
        for l in [a,b,child] {c.insert(l)}
        for i in [book,kept,detached] {c.insert(i)}
        c.insert(tag)
        let exclusion=DuplicateExclusion(itemID1:book.id,itemID2:kept.id);c.insert(exclusion)
        try c.save()
        let service=InventoryMutations(context:c)
        try service.moveItem(id:book.id,destinationID:b.id)
        let read=try ModelContext(container).fetch(FetchDescriptor<Item>()).first{$0.id==book.id}!
        check(read.location?.id==b.id && read.tags.map(\.id)==[tag.id])
        check(read.isArchived && read.bookTitle=="Synthetic book" && read.moveDestination=="Later destination" && read.plan == .move)
        print("PASS exact-ID move preserves book, archive, tag and plan metadata")
        let before=try service.previewDeletion(locationIDs:[a.id],itemIDs:[detached.id])
        check(Set(before.locationIDs)==Set([a.id,child.id]) && before.itemIDs==[detached.id])
        try service.applyDeletion(before,approved:true)
        let after=ModelContext(container)
        check(Set(try after.fetch(FetchDescriptor<Item>()).map(\.id))==Set([book.id,kept.id]))
        check(try after.fetch(FetchDescriptor<Tag>()).map(\.id)==[tag.id])
        check(try after.fetch(FetchDescriptor<DuplicateExclusion>()).map(\.id)==[exclusion.id])
        print("PASS combined location and detached-item removal preserves moved-out records and tags")
        let stale=try service.previewDeletion(locationIDs:[],itemIDs:[book.id])
        book.bookAuthor="Changed author";try c.save()
        var rejected=false
        do {try service.applyDeletion(stale,approved:true)} catch InventoryMutations.Failure.stalePreview {rejected=true}
        check(rejected)
        check(try ModelContext(container).fetch(FetchDescriptor<Item>()).count==2)
        print("PASS changed book metadata invalidates exact removal preview")
        let current=try service.previewDeletion(locationIDs:[],itemIDs:[book.id])
        kept.name="Unsaved edit"
        rejected=false
        do {try service.applyDeletion(current,approved:true)} catch InventoryMutations.Failure.pendingEdits {rejected=true}
        check(rejected && c.hasChanges && kept.name=="Unsaved edit")
        c.rollback()
        try service.applyDeletion(current,approved:true)
        let last=ModelContext(container)
        check(try last.fetch(FetchDescriptor<Item>()).map(\.id)==[kept.id])
        check(try last.fetch(FetchDescriptor<DuplicateExclusion>()).isEmpty)
        check(try last.fetch(FetchDescriptor<Tag>()).map(\.id)==[tag.id])
        print("PASS pending edits survive refusal; approved retry cleans only affected exclusions")
        print("ASTRA_INVENTORY_CHECKS passed=4 failed=0")
    }
}
