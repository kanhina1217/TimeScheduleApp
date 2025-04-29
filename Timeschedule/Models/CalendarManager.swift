import Foundation
import EventKit
import CoreData

struct SpecialScheduleInfo {
    let date: Date
    let patternName: String
    let event: EKEvent
}

/// カレンダー連携機能を管理するクラス
class CalendarManager {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    private var hasAccess = false
    
    // カレンダー識別用の定数
    private let specialScheduleEventTitle = "特殊時程"
    
    private init() {
        requestAccess()
    }
    
    // カレンダーへのアクセス権要求
    func requestAccess() {
        eventStore.requestAccess(to: .event) { [weak self] granted, error in
            self?.hasAccess = granted
            if let error = error {
                print("カレンダーアクセスエラー: \(error.localizedDescription)")
            }
        }
    }
    
    // 特定日のイベントを取得
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard hasAccess else {
            requestAccess()
            return []
        }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    // イベントが特殊時程イベントかどうかを判定
    func isScheduleEvent(_ event: EKEvent) -> Bool {
        // タイトルに「時程」を含むか、特定のパターン名を含むイベントを特殊時程と判断
        let patterns = ["時程", "短縮", "テスト時程", "特殊", "カスタム"]
        return patterns.contains { event.title.contains($0) }
    }
    
    // イベントから特殊時程パターン名を抽出
    func extractSchedulePattern(from event: EKEvent) -> String? {
        // イベントのタイトルからパターン名を抽出
        let patterns = ["通常", "短縮A時程", "短縮B時程", "短縮C時程", "テスト時程"]
        
        for pattern in patterns {
            if event.title.contains(pattern) {
                return pattern
            }
        }
        
        // カスタム設定の場合
        if event.title.contains("→") || event.notes?.contains("→") ?? false {
            return event.title // カスタム設定はタイトルまたはノートに含まれる
        }
        
        // デフォルトはイベント名全体を返す
        return event.title
    }
    
    // 特定日の特殊時程を取得
    func getSpecialScheduleForDate(_ date: Date) -> SpecialScheduleInfo? {
        let events = fetchEvents(for: date)
        
        // 特殊時程を示すイベントを探す
        for event in events {
            if isScheduleEvent(event),
               let patternName = extractSchedulePattern(from: event) {
                return SpecialScheduleInfo(date: date, patternName: patternName, event: event)
            }
        }
        
        return nil
    }
    
    // 指定期間の特殊時程をすべて取得
    func getSpecialSchedules(from: Date, to: Date) -> [SpecialScheduleInfo] {
        guard hasAccess else {
            requestAccess()
            return []
        }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: from)
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to))!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        var result: [SpecialScheduleInfo] = []
        
        for event in events {
            if isScheduleEvent(event),
               let patternName = extractSchedulePattern(from: event) {
                result.append(SpecialScheduleInfo(
                    date: event.startDate,
                    patternName: patternName,
                    event: event
                ))
            }
        }
        
        return result
    }
    
    // カレンダーに特殊時程イベントを作成
    func createScheduleEvent(patternName: String, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            requestAccess()
            completion(false, nil)
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        // イベント開始時刻を8時に設定
        let eventStartDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startOfDay)!
        // イベント終了時刻を16時に設定
        let eventEndDate = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: startOfDay)!
        
        // 既存の同日の特殊時程イベントを削除
        deleteExistingScheduleEvents(for: date) { success, error in
            guard success else {
                completion(false, error)
                return
            }
            
            // 新しいイベントを作成
            let event = EKEvent(eventStore: self.eventStore)
            event.title = "特殊時程: \(patternName)"
            event.startDate = eventStartDate
            event.endDate = eventEndDate
            event.notes = "時間割アプリの特殊時程設定: \(patternName)"
            
            // デフォルトカレンダーに保存
            event.calendar = self.eventStore.defaultCalendarForNewEvents
            
            do {
                try self.eventStore.save(event, span: .thisEvent)
                completion(true, nil)
            } catch {
                print("特殊時程イベントの保存に失敗しました: \(error)")
                completion(false, error)
            }
        }
    }
    
    // 既存の特殊時程イベントを削除
    private func deleteExistingScheduleEvents(for date: Date, completion: @escaping (Bool, Error?) -> Void) {
        let events = fetchEvents(for: date)
        let specialEvents = events.filter { isScheduleEvent($0) }
        
        if specialEvents.isEmpty {
            completion(true, nil)
            return
        }
        
        var error: Error?
        for event in specialEvents {
            do {
                try eventStore.remove(event, span: .thisEvent)
            } catch let err {
                error = err
                print("イベント削除エラー: \(err)")
            }
        }
        
        completion(error == nil, error)
    }
    
    // 特殊時程イベントを削除
    func deleteScheduleEvent(_ event: EKEvent, completion: @escaping (Bool, Error?) -> Void) {
        guard hasAccess else {
            requestAccess()
            completion(false, nil)
            return
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            completion(true, nil)
        } catch {
            print("特殊時程イベントの削除に失敗しました: \(error)")
            completion(false, error)
        }
    }
}