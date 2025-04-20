import Foundation
import CoreData
import SwiftUI

// MARK: - Taskエンティティの基本クラス定義
@objc(Task)
public class Task: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var subjectName: String?
    @NSManaged public var color: String?
    @NSManaged public var dueDate: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var priority: Int16
    @NSManaged public var note: String?
    @NSManaged public var timetable: Timetable?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Task> {
        return NSFetchRequest<Task>(entityName: "Task")
    }
}

extension Task {
    // 優先度の列挙型
    enum Priority: Int16, CaseIterable {
        case low = 0
        case normal = 1
        case high = 2
        
        var title: String {
            switch self {
            case .low: return "低"
            case .normal: return "中"
            case .high: return "高"
            }
        }
        
        var color: Color {
            switch self {
            case .low: return .green
            case .normal: return .blue
            case .high: return .red
            }
        }
    }
    
    // 期限ステータスの列挙型
    enum DueDateStatus {
        case overdue
        case today
        case tomorrow
        case soon
        case future
        case none
        
        var description: String {
            switch self {
            case .overdue: return "期限超過"
            case .today: return "今日まで"
            case .tomorrow: return "明日まで"
            case .soon: return "近日中"
            case .future: return "未来"
            case .none: return "期限なし"
            }
        }
        
        var color: Color {
            switch self {
            case .overdue: return .red
            case .today: return .orange
            case .tomorrow: return .yellow
            case .soon: return .blue
            case .future: return .green
            case .none: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .overdue: return "exclamationmark.circle"
            case .today: return "clock.fill"
            case .tomorrow: return "clock"
            case .soon: return "calendar"
            case .future: return "calendar"
            case .none: return "minus.circle"
            }
        }
    }
    
    // 優先度の列挙型にアクセスするプロパティ
    var priorityEnum: Priority {
        get {
            return Priority(rawValue: self.priority) ?? .normal
        }
        set {
            self.priority = newValue.rawValue
        }
    }
    
    // 科目の色
    var subjectColor: Color {
        guard let colorName = self.color else { return .gray }
        
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        default: return .gray
        }
    }
    
    // 期限のフォーマット
    var formattedDueDate: String {
        guard let dueDate = self.dueDate else { return "期限なし" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: dueDate)
    }
    
    // 期限のステータス
    var dueDateStatus: DueDateStatus {
        guard let dueDate = self.dueDate else { return .none }
        
        let now = Date()
        let calendar = Calendar.current
        
        if dueDate < now {
            return .overdue
        }
        
        if calendar.isDateInToday(dueDate) {
            return .today
        }
        
        if calendar.isDateInTomorrow(dueDate) {
            return .tomorrow
        }
        
        let components = calendar.dateComponents([.day], from: now, to: dueDate)
        if let days = components.day, days < 7 {
            return .soon
        }
        
        return .future
    }
    
    // 完了状態をトグルする
    func toggleCompletion() {
        self.isCompleted.toggle()
    }
}

// プレビュー用の拡張
extension Task {
    static var preview: Task {
        let context = PersistenceController.preview.container.viewContext
        let task = Task(context: context)
        task.id = UUID()
        task.title = "英語のレポート作成"
        task.subjectName = "英語"
        task.dueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        task.color = "blue"
        task.isCompleted = false
        task.priority = Priority.normal.rawValue
        task.note = "3ページのエッセイ、テーマ：自由"
        return task
    }
}