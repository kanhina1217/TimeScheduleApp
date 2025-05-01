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
            // _Concurrency.Task を使用して名前衝突を回避
            _Concurrency.Task { // Changed Task to _Concurrency.Task
                do {
                    // Use requestFullAccessToEvents for iOS 17+
                    let granted = try await eventStore.requestFullAccessToEvents()
                    DispatchQueue.main.async {
                        self.hasAccess = granted
                        completion(granted, nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.hasAccess = false
                        completion(false, error)
                    }
                }
            }
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
        // イベントのタイトルからパターン名を抽出
        let patterns = ["通常", "短縮A時程", "短縮B時程", "短縮C時程", "テスト時程"]

        for pattern in patterns {
            if event.title.contains(pattern) {
                return pattern
            }
        }

        // カスタム設定の場合
        if event.title.contains("→") || event.notes?.contains("→") ?? false {
            return event.title // または詳細な解析ロジック
        }

        // タイトルからプレフィックスを除去する例
        if event.title.starts(with: specialScheduleEventTitle + ": ") {
            return String(event.title.dropFirst((specialScheduleEventTitle + ": ").count))
        }

        return nil // マッチしない場合
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