import Foundation
import CoreData

extension Task {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Task> {
        return NSFetchRequest<Task>(entityName: "Task")
    }

    @NSManaged public var color: String?
    @NSManaged public var dueDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var note: String?
    @NSManaged public var priority: Int16
    @NSManaged public var subjectName: String?
    @NSManaged public var title: String?
    @NSManaged public var timetable: Timetable?
    @NSManaged public var taskType: String? // CoreDataモデルに追加
    
    // TaskExtensions.swiftで参照されているコンピューテッドプロパティ
    // これらはCoreDataモデルに保存せず、メモリ上で動作するように実装
    private static var _createdAtDates = [UUID: Date]()
    private static var _updatedAtDates = [UUID: Date]()
    
    public var createdAt: Date? {
        get {
            if let uuid = self.id {
                return Task._createdAtDates[uuid] ?? Date()
            }
            return Date()
        }
        set {
            if let uuid = self.id, let newValue = newValue {
                Task._createdAtDates[uuid] = newValue
            }
        }
    }
    
    public var updatedAt: Date? {
        get {
            if let uuid = self.id {
                return Task._updatedAtDates[uuid] ?? Date()
            }
            return Date()
        }
        set {
            if let uuid = self.id, let newValue = newValue {
                Task._updatedAtDates[uuid] = newValue
            }
        }
    }
}