import WidgetKit
import SwiftUI
import CoreData

// ウィジェット用のデータ管理クラス
class WidgetDataManager {
    // アプリグループ識別子（実際のものに変更してください）
    private let appGroupIdentifier = "group.com.yourapp.timetable"
    
    // 特定の曜日の時間割データを取得する
    func getTimetableForWeekday(_ weekday: Int) throws -> [TimeTableItem] {
        // UserDefaultsの共有インスタンスを取得
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("共有UserDefaultsにアクセスできません")
            return []
        }
        
        // 保存されたデータを取得
        guard let savedData = sharedDefaults.array(forKey: "widgetTimetableData") as? [[String: Any]] else {
            print("時間割データが見つかりません")
            return []
        }
        
        // 指定された曜日の時間割のみフィルタリング (0=日曜, 1=月曜, 2=火曜...)
        let filteredItems = savedData.filter { item in
            if let dayOfWeek = item["dayOfWeek"] as? Int {
                return dayOfWeek == weekday
            }
            return false
        }
        
        // データをTimeTableItem形式に変換
        return filteredItems.compactMap { item in
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
        }.sorted { (item1, item2) in
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
        
        // タイムラインを作成して返す
        let timeline = Timeline(entries: [entries], policy: .after(refreshDate))
        completion(timeline)
    }
    
    // データ取得関数を分離して整理
    private func fetchCurrentSchedule() -> TimetableWidgetEntry {
        do {
            // WidgetDataManagerからデータを取得
            let widgetDataManager = WidgetDataManager()
            
            // 今日の曜日を取得 (1 = 日曜日, 2 = 月曜日, ...)
            let calendar = Calendar.current
            let today = calendar.component(.weekday, from: Date())
            
            // 日本の曜日表記に合わせて調整 (0 = 日曜日, 1 = 月曜日, ...)
            let japaneseWeekday = today - 1
            
            // その曜日の時間割を取得
            let todayItems = try widgetDataManager.getTimetableForWeekday(japaneseWeekday)
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