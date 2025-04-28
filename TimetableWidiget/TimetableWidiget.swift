import WidgetKit
import SwiftUI
import CoreData

// ウィジェット用のデータ管理クラス
class WidgetDataManager {
    // アプリグループ識別子
    private let appGroupIdentifier = "group.com.kanhina.timetable"
    
    // 共有UserDefaultsへのアクセスを強化
    private func getSharedUserDefaults() -> UserDefaults? {
        // 明示的にアプリグループIDを指定してUserDefaultsを取得
        let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        
        if sharedDefaults == nil {
            print("警告: ウィジェット - 共有UserDefaultsの取得に失敗しました。アプリグループIDの設定を確認してください。")
            print("アプリグループID: \(appGroupIdentifier)")
        }
        
        return sharedDefaults
    }
    
    // 特定の曜日の時間割データを取得する
    func getTimetableForWeekday(_ weekday: Int) throws -> [TimeTableItem] {
        print("ウィジェット - 曜日 \(weekday) の時間割を取得します")
        
        // 共有UserDefaultsを取得
        guard let sharedDefaults = getSharedUserDefaults() else {
            print("共有UserDefaultsにアクセスできません")
            return []
        }
        
        // デバッグ情報: 使用可能なキーを表示
        let allKeys = sharedDefaults.dictionaryRepresentation().keys
        print("利用可能なキー: \(Array(allKeys))")
        
        // データがあるかどうかをまず確認
        guard allKeys.contains("widgetTimetableData") else {
            print("キー 'widgetTimetableData' が存在しません")
            return []
        }
        
        // 保存されたデータを取得
        guard let savedData = sharedDefaults.array(forKey: "widgetTimetableData") as? [[String: Any]] else {
            print("時間割データが見つかりません")
            return []
        }
        
        print("読み込んだデータ件数: \(savedData.count)")
        
        // 指定された曜日の時間割のみフィルタリング (0=日曜, 1=月曜, 2=火曜...)
        let filteredItems = savedData.filter { item in
            if let dayOfWeek = item["dayOfWeek"] as? Int {
                // 曜日が一致するデータのみを取得
                let matches = dayOfWeek == weekday
                print("曜日比較: データ上の曜日 \(dayOfWeek) vs 検索曜日 \(weekday) = \(matches ? "一致" : "不一致")")
                return matches
            }
            return false
        }
        
        print("フィルタリング後のデータ件数: \(filteredItems.count)")
        
        // 空の場合は早期リターン
        if filteredItems.isEmpty {
            print("この曜日のデータはありません")
            return []
        }
        
        // データをTimeTableItem形式に変換
        let items: [TimeTableItem] = filteredItems.compactMap { (item: [String: Any]) -> TimeTableItem? in
            guard let subjectName = item["subjectName"] as? String,
                  let period = item["period"] as? String else {
                return nil
            }
            
            // 授業の開始・終了時間を取得
            let startTime = item["startTime"] as? String ?? ""
            let endTime = item["endTime"] as? String ?? ""
            
            // 時間帯を「開始-終了」形式に
            let timeSlot = startTime.isEmpty || endTime.isEmpty ? "" : "\(startTime)-\(endTime)"
            
            return TimeTableItem(
                subject: subjectName,
                startTime: timeSlot,
                teacher: item["teacher"] as? String ?? "",
                room: item["roomName"] as? String ?? "",
                period: "\(period)限"
            )
        }.sorted { (item1: TimeTableItem, item2: TimeTableItem) in
            // 時限順にソート
            guard let period1 = Int(item1.period?.replacingOccurrences(of: "限", with: "") ?? "0"),
                  let period2 = Int(item2.period?.replacingOccurrences(of: "限", with: "") ?? "0") else {
                return false
            }
            return period1 < period2
        }
        
        print("変換後のアイテム数: \(items.count)")
        return items
    }
    
    // すべての時間割データを取得する（デバッグ用）
    func getAllTimetableData() -> [TimeTableItem] {
        guard let sharedDefaults = getSharedUserDefaults(),
              let savedData = sharedDefaults.array(forKey: "widgetTimetableData") as? [[String: Any]] else {
            print("ウィジェットデータが見つかりません")
            return []
        }
        
        print("全データ件数: \(savedData.count)")
        
        // すべてのデータを変換（曜日でフィルタリングしない）
        return savedData.compactMap { (item: [String: Any]) -> TimeTableItem? in
            guard let subjectName = item["subjectName"] as? String,
                  let period = item["period"] as? String,
                  let dayOfWeek = item["dayOfWeek"] as? Int else {
                return nil
            }
            
            // 曜日名を取得
            let dayNames = ["日", "月", "火", "水", "木", "金", "土"]
            let dayName = (dayOfWeek >= 0 && dayOfWeek < dayNames.count) ? dayNames[dayOfWeek] : "?"
            
            // 授業の開始・終了時間を取得
            let startTime = item["startTime"] as? String ?? ""
            let endTime = item["endTime"] as? String ?? ""
            
            // 時間帯を「開始-終了」形式に
            let timeSlot = startTime.isEmpty || endTime.isEmpty ? "" : "\(startTime)-\(endTime)"
            
            return TimeTableItem(
                subject: "\(dayName): \(subjectName)",  // デバッグ用に曜日を追加
                startTime: timeSlot,
                teacher: item["teacher"] as? String ?? "",
                room: item["roomName"] as? String ?? "",
                period: "\(period)限"
            )
        }.sorted { (item1: TimeTableItem, item2: TimeTableItem) in
            // 時限順にソート
            guard let period1 = Int(item1.period?.replacingOccurrences(of: "限", with: "") ?? "0"),
                  let period2 = Int(item2.period?.replacingOccurrences(of: "限", with: "") ?? "0") else {
                return false
            }
            return period1 < period2
        }
    }
}

struct TimetableWidgetProvider: TimelineProvider {
    // デバッグモード（問題が発生している場合にtrue）
    private let debugMode = false
    
    // プレースホルダーエントリー（ウィジェットがロードされる前に表示される）
    func placeholder(in context: Context) -> TimetableWidgetEntry {
        return TimetableWidgetEntry(date: Date(), timetableItems: [])
    }

    // スナップショットエントリー（ウィジェットギャラリーで表示される）
    func getSnapshot(in context: Context, completion: @escaping (TimetableWidgetEntry) -> Void) {
        // プレビュー用のサンプルデータを使用
        let entry = TimetableWidgetEntry(date: Date(), timetableItems: sampleTimetableItems())
        completion(entry)
    }

    // タイムラインエントリー（実際のウィジェット表示に使用される）
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableWidgetEntry>) -> Void) {
        // データ取得処理
        let entries = fetchCurrentSchedule()
        
        // 更新のスケジューリング（日付が変わるときと数時間ごと）
        var refreshDate = calculateNextRefreshDate()
        
        // デバッグ中は頻繁に更新（開発時のみ）
        #if DEBUG
        refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        #endif
        
        print("ウィジェット更新予定: \(refreshDate)")
        
        // タイムラインを作成して返す
        let timeline = Timeline(entries: [entries], policy: .after(refreshDate))
        completion(timeline)
    }
    
    // データ取得関数を分離して整理
    private func fetchCurrentSchedule() -> TimetableWidgetEntry {
        do {
            // WidgetDataManagerからデータを取得
            let widgetDataManager = WidgetDataManager()
            
            // デバッグモードの場合、すべてのデータを表示
            if debugMode {
                let allItems = widgetDataManager.getAllTimetableData()
                return TimetableWidgetEntry(date: Date(), timetableItems: allItems)
            }
            
            // 今日の曜日を取得 (1 = 日曜日, 2 = 月曜日, ...)
            let calendar = Calendar.current
            let today = calendar.component(.weekday, from: Date())
            
            // 日本の曜日表記に合わせて調整 (0 = 日曜日, 1 = 月曜日, ...)
            let japaneseWeekday = today - 1
            
            print("ウィジェット - 現在の曜日: \(today) → 日本式インデックス: \(japaneseWeekday)")
            
            // その曜日の時間割を取得
            let todayItems = try widgetDataManager.getTimetableForWeekday(japaneseWeekday)
            
            if todayItems.isEmpty {
                print("警告: 今日(\(japaneseWeekday))の授業データがありません")
            } else {
                print("今日の授業データ: \(todayItems.count)件")
            }
            
            return TimetableWidgetEntry(date: Date(), timetableItems: todayItems)
        } catch {
            print("ウィジェットデータの取得中にエラーが発生: \(error.localizedDescription)")
            // エラーが発生した場合は空のデータを返す
            return TimetableWidgetEntry(date: Date(), timetableItems: [])
        }
    }
    
    // 次回の更新時刻を計算
    private func calculateNextRefreshDate() -> Date {
        let calendar = Calendar.current
        
        // 次の更新時刻を計算（1. 日付が変わるとき、2. 授業開始時間に近いとき）
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        
        // 現在時刻
        let now = Date()
        
        // 午後11時以降なら次の日の朝6時、それ以外は3時間ごとに更新
        if calendar.component(.hour, from: now) >= 23 {
            // 次の日の朝6時
            return calendar.date(bySettingHour: 6, minute: 0, second: 0, of: midnight)!
        } else {
            // 3時間後（最大でも翌日の午前0時）
            let threeHoursLater = calendar.date(byAdding: .hour, value: 3, to: now)!
            return min(threeHoursLater, midnight)
        }
    }
    
    // プレビュー用のサンプルデータ
    private func sampleTimetableItems() -> [TimeTableItem] {
        return [
            TimeTableItem(subject: "プログラミング概論", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限"),
            TimeTableItem(subject: "AI入門", startTime: "13:00-14:30", teacher: "佐藤先生", room: "C301", period: "3限")
        ]
    }
}

// ウィジェットのエントリーモデル
struct TimetableWidgetEntry: TimelineEntry {
    let date: Date
    let timetableItems: [TimeTableItem]
}

// 時間割アイテムのデータモデル
struct TimeTableItem: Hashable {
    var subject: String?
    var startTime: String?
    var teacher: String?
    var room: String?
    var period: String?
    
    // 位置情報をroomに統合
    var location: String? {
        get {
            return room
        }
        set {
            room = newValue
        }
    }
}

// ウィジェット本体の設定
struct TimetableWidget: Widget {
    let kind: String = "TimetableWidiget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimetableWidgetProvider()) { entry in
            TimetableWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("時間割")
        .description("授業スケジュールを表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ウィジェットのプレビュー
struct TimetableWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            TimeTableItem(subject: "プログラミング", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限")
        ]
        
        let entry = TimetableWidgetEntry(date: Date(), timetableItems: sampleItems)
        
        TimetableWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("標準サイズ")
        
        TimetableWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("小サイズ")
    }
}