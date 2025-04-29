import Foundation
import EventKit

/// カレンダー連携機能を管理するクラス
class CalendarManager {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    private var accessGranted = false
    
    private init() {}
    
    /// カレンダーへのアクセス権限をリクエスト
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.accessGranted = granted
                completion(granted, error)
            }
        }
    }
    
    /// 指定した日付のイベントを取得
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard accessGranted else { return [] }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    /// 指定した期間のイベントを取得
    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard accessGranted else { return [] }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    /// 特別な時程を示すイベントかどうかを判断
    func isSpecialScheduleEvent(_ event: EKEvent) -> Bool {
        // 特別時程を示すキーワードを含むか確認
        let specialKeywords = ["特別時程", "短縮", "行事", "テスト", "試験"]
        if let title = event.title {
            return specialKeywords.contains { title.contains($0) }
        }
        return false
    }
    
    /// イベントから時程パターンを判断
    func schedulePatternFromEvent(_ event: EKEvent) -> String? {
        if let title = event.title?.lowercased() {
            if title.contains("短縮a") || title.contains("短縮 a") {
                return "短縮A時程"
            } else if title.contains("短縮b") || title.contains("短縮 b") {
                return "短縮B時程"
            } else if title.contains("短縮c") || title.contains("短縮 c") {
                return "短縮C時程"
            } else if title.contains("テスト") || title.contains("試験") {
                return "テスト時程"
            }
        }
        return nil
    }
    
    /// 新しいイベントを作成
    func createEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        guard accessGranted else {
            completion(false, nil)
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
}