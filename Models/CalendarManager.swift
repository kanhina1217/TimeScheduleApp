import Foundation
import EventKit

class CalendarManager {
    // EventKitのイベントストアインスタンス
    private let eventStore = EKEventStore()
    // シングルトンインスタンス
    static let shared = CalendarManager()
    // カレンダー認証状態
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    // アクセス権の有無
    private var hasAccess: Bool = false
    
    private init() {
        // 初期化時に現在の認証状態を取得
        updateAuthorizationStatus()
    }
    
    // 認証状態を更新
    private func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    // カレンダーへのアクセス許可をリクエスト
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        // iOS 17以降と以前で異なる処理
        if #available(iOS 17.0, *) {
            DispatchQueue.global().async {
                do {
                    let granted = try self.eventStore.requestFullAccessToEvents()
                    DispatchQueue.main.async {
                        self.updateAuthorizationStatus()
                        self.hasAccess = granted
                        completion(granted, nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(false, error)
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] (granted, error) in
                DispatchQueue.main.async {
                    self?.updateAuthorizationStatus()
                    self?.hasAccess = granted
                    completion(granted, error)
                }
            }
        }
    }
    
    // 指定した日付のカレンダーイベントを取得
    func fetchEvents(for date: Date, completion: @escaping ([EKEvent]?, Error?) -> Void) {
        // アクセス権をチェック
        if hasAccess {
            let events = fetchEventsSync(for: date)
            completion(events, nil)
        } else {
            requestAccess { granted, error in
                if granted {
                    let events = self.fetchEventsSync(for: date)
                    completion(events, nil)
                } else {
                    completion(nil, error)
                }
            }
        }
    }
    
    // 同期的にイベントを取得する内部関数
    private func fetchEventsSync(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    // 指定した期間のカレンダーイベントを取得
    func fetchEvents(from startDate: Date, to endDate: Date, completion: @escaping ([EKEvent]?, Error?) -> Void) {
        // アクセス権のチェック
        if authorizationStatus != .authorized && authorizationStatus != .fullAccess {
            completion(nil, NSError(domain: "CalendarManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "カレンダーへのアクセスが許可されていません"]))
            return
        }
        
        // 検索条件を設定
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // イベントを検索
        let events = eventStore.events(matching: predicate)
        completion(events, nil)
    }
    
    // 時程を示すカレンダーイベントを判別するための接頭辞
    private let schedulePrefix = "[時程]"
    
    // イベントが特別な時程を示すものか判断
    func isScheduleEvent(_ event: EKEvent) -> Bool {
        return event.title?.hasPrefix(schedulePrefix) == true
    }
    
    // イベントから時程パターンを判断する
    func extractSchedulePattern(from event: EKEvent) -> String? {
        guard isScheduleEvent(event) else { return nil }
        
        let title = event.title ?? ""
        // "[時程]" 以降の文字列を取得
        if let range = title.range(of: schedulePrefix) {
            // 接頭辞以降の文字列を取得し、前後の空白を削除
            let patternName = title[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return patternName.isEmpty ? nil : patternName
        }
        return nil
    }
    
    // 新しいイベントを作成
    func createEvent(title: String, startDate: Date, endDate: Date, location: String? = nil, notes: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        // アクセス権のチェック
        if authorizationStatus != .authorized && authorizationStatus != .fullAccess {
            completion(false, NSError(domain: "CalendarManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "カレンダーへのアクセスが許可されていません"]))
            return
        }
        
        // 新しいイベントを作成
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        
        if let location = location {
            event.location = location
        }
        
        if let notes = notes {
            event.notes = notes
        }
        
        // デフォルトのカレンダーを設定
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            // イベントを保存
            try eventStore.save(event, span: .thisEvent)
            completion(true, nil)
        } catch {
            completion(false, error)
        }
    }
    
    // 時程パターンをカレンダーに登録
    func createScheduleEvent(patternName: String, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        // カレンダーの日付範囲を取得
        let calendar = Calendar.current
        guard let startDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: date),
              let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) else {
            completion(false, NSError(domain: "CalendarManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "日付の範囲設定に失敗しました"]))
            return
        }
        
        // イベントタイトルに接頭辞を付ける
        let title = "\(schedulePrefix) \(patternName)"
        
        // 終日イベントとして登録
        createEvent(title: title, startDate: startDate, endDate: endDate, notes: "この日の時程パターン", completion: completion)
    }
}