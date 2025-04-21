import WidgetKit
import SwiftUI
import CoreData

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
        let entries = fetchTodaysSchedule()
        
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
    private func fetchTodaysSchedule() -> TimetableWidgetEntry {
        do {
            // WidgetDataManagerからデータを取得
            let widgetDataManager = WidgetDataManager()
            let todayItems = try widgetDataManager.getTodaysTimetable()
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
            TimeTableItem(subject: "プログラミング概論", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限目"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限目"),
            TimeTableItem(subject: "AI入門", startTime: "13:00-14:30", teacher: "佐藤先生", room: "C301", period: "3限目")
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
    let kind: String = "TimetableWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimetableWidgetProvider()) { entry in
            TimetableWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日の時間割")
        .description("今日の授業スケジュールを表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// ウィジェットのプレビュー
struct TimetableWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            TimeTableItem(subject: "プログラミング", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限目"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限目")
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