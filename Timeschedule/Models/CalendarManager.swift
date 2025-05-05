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
    private(set) var hasAccess = false // Make it private(set) for controlled modification

    // カレンダー識別用の定数
    private let specialScheduleEventTitle = "特殊時程"

    private init() {
        // Check initial access status without requesting immediately
        checkAccessStatus()
    }

    // Check current access status
    private func checkAccessStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasAccess = (status == .authorized || status == .fullAccess) // iOS 17+ uses fullAccess
    }

    // カレンダーへのアクセス権要求 (完了ハンドラ付き)
    func requestAccess(completion: @escaping (Bool, Error?) -> Void) {
        // iOS 17以降と以前で異なる処理
        if #available(iOS 17.0, *) {
            // Swift Concurrencyを使わない代替アプローチ
            // 非同期関数をラップして同期的に呼び出す
            let handler: EKEventStoreRequestAccessCompletionHandler = { granted, error in
                DispatchQueue.main.async {
                    self.hasAccess = granted
                    completion(granted, error)
                }
            }
            
            // EKEventStoreのprivateメソッドにアクセスすることはできませんが、
            // iOS 17では従来のrequestAccess(to:completion:)メソッドが内部的に
            // 新しいAPIを呼び出すようになっているので、それを使います
            eventStore.requestAccess(to: .event, completion: handler)
        } else {
            // Use requestAccess for older iOS versions
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async { // Ensure UI updates on main thread
                    self?.hasAccess = granted
                    completion(granted, error)
                }
            }
        }
    }

    // 特定日のイベントを取得 (非同期、完了ハンドラ付き)
    func fetchEvents(for date: Date, completion: @escaping ([EKEvent]?, Error?) -> Void) {
        checkAccessStatus() // Update access status before check
        guard hasAccess else {
            // アクセスがない場合はエラーを返すか、アクセスを要求するか選択
            // ここではエラーを返す例
            completion(nil, NSError(domain: "CalendarManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "カレンダーへのアクセスが許可されていません。"]))
            return
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
            completion(nil, NSError(domain: "CalendarManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "終了日の計算に失敗しました。"]))
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        completion(events, nil) // 成功時はイベント配列とnilエラーを返す
    }

    // イベントが特殊時程イベントかどうかを判定
    func isScheduleEvent(_ event: EKEvent) -> Bool {
        // タイトルに「時程」を含むか、特定のパターン名を含むイベントを特殊時程と判断
        let patterns = ["時程", "短縮", "テスト時程", "特殊", "カスタム"]
        return patterns.contains { event.title.contains($0) } || event.title.contains(specialScheduleEventTitle)
    }

    // イベントから特殊時程パターン名を抽出
    func extractSchedulePattern(from event: EKEvent) -> String? {
        // イベントタイトルをそのまま利用
        var patternName = event.title
        
        // 特殊時程プレフィックスを除去
        if event.title.starts(with: specialScheduleEventTitle + ": ") {
            patternName = String(event.title.dropFirst((specialScheduleEventTitle + ": ").count))
        }
        
        // イベントのタイトルをパターン名としてそのまま返す
        return patternName
    }

    // 特定日の特殊時程を取得
    func getSpecialScheduleForDate(_ date: Date) -> SpecialScheduleInfo? {
        var foundEvents: [EKEvent]?
        let semaphore = DispatchSemaphore(value: 0)
        var fetchError: Error?

        fetchEvents(for: date) { events, error in
            foundEvents = events
            fetchError = error
            semaphore.signal()
        }
        semaphore.wait() // 同期的に待機（UIスレッドでの使用は避ける）

        guard let events = foundEvents, fetchError == nil else {
            print("特殊時程のイベント取得エラー: \(fetchError?.localizedDescription ?? "不明なエラー")")
            return nil
        }

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
        checkAccessStatus()
        guard hasAccess else { return [] }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: from)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        var result: [SpecialScheduleInfo] = []
        for event in events {
            if isScheduleEvent(event),
               let patternName = extractSchedulePattern(from: event) {
                let eventDate = calendar.startOfDay(for: event.startDate)
                result.append(SpecialScheduleInfo(
                    date: eventDate,
                    patternName: patternName,
                    event: event
                ))
            }
        }

        let uniqueSchedules = Dictionary(grouping: result, by: { $0.date })
            .compactMap { $0.value.first }
            .sorted { $0.date < $1.date }

        return uniqueSchedules
    }

    // 利用可能なカレンダーを取得
    func getAvailableCalendars() -> [EKCalendar] {
        checkAccessStatus()
        guard hasAccess else { return [] }
        
        // 書き込み可能なカレンダーのみを取得
        let calendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
        
        return calendars.sorted { $0.title < $1.title }
    }
    
    // 指定したカレンダーに特殊時程イベントを作成
    func createScheduleEvent(patternName: String, date: Date, calendar: EKCalendar? = nil, completion: @escaping (Bool, Error?) -> Void) {
        checkAccessStatus()
        guard hasAccess else {
            completion(false, NSError(domain: "CalendarManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "カレンダーへのアクセスが許可されていません。"]))
            return
        }

        let calendarObj = calendar ?? eventStore.defaultCalendarForNewEvents
        guard calendarObj != nil else {
            completion(false, NSError(domain: "CalendarManager", code: 501, userInfo: [NSLocalizedDescriptionKey: "カレンダーが見つかりません。"]))
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let eventStartDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: startOfDay),
              let eventEndDate = calendar.date(byAdding: .day, value: 1, to: eventStartDate) else {
            completion(false, NSError(domain: "CalendarManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "日付の設定に失敗しました。"]))
            return
        }

        deleteExistingScheduleEvents(for: date) { [weak self] success, error in
            guard let self = self, success else {
                completion(false, error ?? NSError(domain: "CalendarManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "既存イベントの削除に失敗しました。"]))
                return
            }

            let event = EKEvent(eventStore: self.eventStore)
            event.title = "\(self.specialScheduleEventTitle): \(patternName)"
            event.startDate = eventStartDate
            event.endDate = eventEndDate
            event.isAllDay = true
            event.notes = "時間割アプリの特殊時程設定: \(patternName)"
            event.calendar = calendarObj

            do {
                try self.eventStore.save(event, span: .thisEvent)
                completion(true, nil)
            } catch {
                print("特殊時程イベントの保存に失敗しました: \(error)")
                completion(false, error)
            }
        }
    }

    // カレンダーに特殊時程イベントを作成
    func createScheduleEvent(patternName: String, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        checkAccessStatus()
        guard hasAccess else {
            completion(false, NSError(domain: "CalendarManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "カレンダーへのアクセスが許可されていません。"]))
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let eventStartDate = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: startOfDay),
              let eventEndDate = calendar.date(byAdding: .day, value: 1, to: eventStartDate) else {
            completion(false, NSError(domain: "CalendarManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "日付の設定に失敗しました。"]))
            return
        }

        deleteExistingScheduleEvents(for: date) { [weak self] success, error in
            guard let self = self, success else {
                completion(false, error ?? NSError(domain: "CalendarManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "既存イベントの削除に失敗しました。"]))
                return
            }

            let event = EKEvent(eventStore: self.eventStore)
            event.title = "\(self.specialScheduleEventTitle): \(patternName)"
            event.startDate = eventStartDate
            event.endDate = eventEndDate
            event.isAllDay = true
            event.notes = "時間割アプリの特殊時程設定: \(patternName)"
            event.calendar = self.eventStore.defaultCalendarForNewEvents

            if event.calendar == nil {
                completion(false, NSError(domain: "CalendarManager", code: 501, userInfo: [NSLocalizedDescriptionKey: "デフォルトカレンダーが見つかりません。"]))
                return
            }

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
        fetchEvents(for: date) { [weak self] events, error in
            guard let self = self else {
                completion(false, NSError(domain: "CalendarManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "内部エラー"]))
                return
            }
            if let error = error {
                completion(false, error)
                return
            }

            guard let events = events else {
                completion(true, nil)
                return
            }

            let specialEvents = events.filter { self.isScheduleEvent($0) }

            if specialEvents.isEmpty {
                completion(true, nil)
                return
            }

            var lastError: Error?
            let group = DispatchGroup()

            for event in specialEvents {
                group.enter()
                self.deleteScheduleEvent(event) { success, deleteError in
                    if !success {
                        lastError = deleteError ?? NSError(domain: "CalendarManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "イベント削除中に不明なエラーが発生しました。"])
                        print("イベント削除エラー: \(lastError!)")
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion(lastError == nil, lastError)
            }
        }
    }

    // 特殊時程イベントを削除 (個別のイベント用)
    func deleteScheduleEvent(_ event: EKEvent, completion: @escaping (Bool, Error?) -> Void) {
        checkAccessStatus()
        guard hasAccess else {
            completion(false, NSError(domain: "CalendarManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "カレンダーへのアクセスが許可されていません。"]))
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

// MARK: - ウィジェット連携
extension CalendarManager {
    /// ウィジェット用に時間割データをエクスポートする
    func exportTimetableDataForWidget() {
        // アプリグループ識別子
        let appGroupIdentifier = "group.com.kanhina.timetable"
        
        // 共有UserDefaultsを取得
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("エラー: 共有UserDefaultsを取得できません")
            return
        }
        
        // 現在のコンテキストを取得
        let context = PersistenceController.shared.container.viewContext
        
        // 時間割データをフェッチ
        let fetchRequest: NSFetchRequest<Timetable> = Timetable.fetchRequest()
        
        do {
            // 時間割データを取得
            let timetables = try context.fetch(fetchRequest)
            
            // エクスポート用の辞書の配列を作成
            var exportData: [[String: Any]] = []
            
            for timetable in timetables {
                let dayOfWeek = Int(timetable.dayOfWeek)
                let period = timetable.period ?? ""
                let subjectName = timetable.subject?.name ?? "未設定"
                let roomName = timetable.room?.name ?? ""
                let teacher = timetable.teacher?.name ?? ""
                let startTime = timetable.startTime ?? ""
                let endTime = timetable.endTime ?? ""
                let color = timetable.subject?.color ?? "0"
                
                var timetableData: [String: Any] = [
                    "dayOfWeek": dayOfWeek,
                    "period": period,
                    "subjectName": subjectName,
                    "roomName": roomName,
                    "teacher": teacher,
                    "startTime": startTime,
                    "endTime": endTime,
                    "color": color,
                    "isSpecial": false // 通常の時間割
                ]
                
                exportData.append(timetableData)
            }
            
            // 特殊時程の情報も追加
            exportSpecialScheduleDataForWidget(to: &exportData)
            
            // 今日の特殊時程情報を保存
            let today = Date()
            let patternInfo = getSpecialScheduleForDay(today)
            sharedDefaults.set(patternInfo.hasSpecialSchedule, forKey: "widgetTodayHasSpecialSchedule")
            sharedDefaults.set(patternInfo.name, forKey: "widgetTodayPatternName")
            
            // データを保存
            sharedDefaults.set(exportData, forKey: "widgetTimetableData")
            print("ウィジェット用に \(exportData.count) 件のデータをエクスポートしました")
        } catch {
            print("時間割データの取得中にエラーが発生: \(error.localizedDescription)")
        }
    }
    
    /// 特殊時程のデータをウィジェット用にエクスポート
    private func exportSpecialScheduleDataForWidget(to data: inout [[String: Any]]) {
        // 今日と明日の特殊時程をエクスポート
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        
        // 今日の特殊時程
        exportSpecialScheduleForDay(today, to: &data)
        
        // 明日の特殊時程
        exportSpecialScheduleForDay(tomorrow, to: &data)
    }
    
    /// 指定日の特殊時程をウィジェット用にエクスポート
    private func exportSpecialScheduleForDay(_ date: Date, to data: inout [[String: Any]]) {
        // 特殊時程マネージャーからデータを取得
        let specialManager = SpecialScheduleManager.shared
        guard let specialPattern = specialManager.getPatternForDate(date) else {
            // 特殊時程がない場合は何もしない
            return
        }
        
        // 日付から曜日を取得（0=日曜, 1=月曜...）
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) - 1
        
        // 特殊時程のデータを作成
        for item in specialPattern.items {
            // 元の曜日と時限を表示するための情報を作成
            let originalInfo = "(\(weekdayToString(item.originWeekday))\(item.originPeriod))"
            
            var timetableData: [String: Any] = [
                "dayOfWeek": weekday,
                "period": "\(item.period)",
                "subjectName": item.subject?.name ?? "未設定",
                "roomName": item.room?.name ?? "",
                "teacher": item.teacher?.name ?? "",
                "startTime": item.startTime ?? "",
                "endTime": item.endTime ?? "",
                "color": item.subject?.color ?? "0",
                "isSpecial": true,
                "originalInfo": originalInfo,
                "patternName": specialPattern.name
            ]
            
            // データに追加
            data.append(timetableData)
        }
    }
    
    /// 曜日の数値を文字列に変換（0=日, 1=月...）
    private func weekdayToString(_ weekday: Int16) -> String {
        let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
        let index = Int(weekday)
        if index >= 0 && index < weekdays.count {
            return weekdays[index]
        }
        return "?"
    }
    
    /// 指定日の特殊時程情報を取得
    func getSpecialScheduleForDay(_ date: Date) -> (hasSpecialSchedule: Bool, name: String) {
        let specialManager = SpecialScheduleManager.shared
        if let pattern = specialManager.getPatternForDate(date) {
            return (true, pattern.name ?? "特殊時程")
        }
        return (false, "通常時程")
    }
}