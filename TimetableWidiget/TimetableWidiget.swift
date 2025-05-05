import WidgetKit
import SwiftUI
import CoreData

// ウィジェット用のデータ管理クラス
class WidgetDataManager {
    // アプリグループ識別子
    private let appGroupIdentifier = "group.com.kanhina.timetable"
    
    // 曜日のインデックス変換メソッド
    
    /// CoreDataの曜日(0=日曜, 1=月曜...)からUIの曜日インデックス(0=月曜, 1=火曜...)へ変換
    private func convertCoreDataDayToWeekdayIndex(_ coreDataDay: Int) -> Int {
        // CoreDataの日付が0=日曜、1=月曜...の場合
        // 0=月曜、1=火曜...に変換
        return (coreDataDay + 6) % 7
    }
    
    /// UIの曜日インデックス(0=月曜, 1=火曜...)からCoreDataの曜日(0=日曜, 1=月曜...)へ変換
    private func convertWeekdayIndexToCoreDataDay(_ weekdayIndex: Int) -> Int {
        // 0=月曜、1=火曜...から
        // CoreDataの0=日曜、1=月曜...に変換
        return (weekdayIndex + 1) % 7
    }
    
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
    
    /// 今日の特殊時程情報を取得する
    func getTodayPatternInfo() -> (hasSpecialSchedule: Bool, patternName: String) {
        guard let sharedDefaults = getSharedUserDefaults() else {
            return (false, "通常時程")
        }
        
        let hasSpecial = sharedDefaults.bool(forKey: "widgetTodayHasSpecialSchedule")
        let patternName = sharedDefaults.string(forKey: "widgetTodayPatternName") ?? "通常時程"
        
        return (hasSpecial, patternName)
    }
    
    // 特定の曜日の時間割データを取得する
    func getTimetableForWeekday(_ weekday: Int) throws -> [TimeTableItem] {
        print("ウィジェット - 曜日 \(weekday) の時間割を取得します (CoreData形式)")
        
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
        
        // 指定された曜日の時間割のみフィルタリング
        // パラメータweekdayはCoreDataの形式（0=日曜日、1=月曜日...）で渡される
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
            
            // 特殊時程の情報を取得
            let isSpecial = item["isSpecial"] as? Bool ?? false
            let originalInfo = item["originalInfo"] as? String
            let patternName = item["patternName"] as? String
            
            return TimeTableItem(
                subject: subjectName,
                startTime: timeSlot,
                teacher: item["teacher"] as? String ?? "",
                room: item["roomName"] as? String ?? "",
                period: "\(period)限",
                color: item["color"] as? String ?? "0",  // デフォルト色を設定
                isSpecial: isSpecial,
                originalInfo: originalInfo,
                patternName: patternName
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
            
            // 特殊時程の情報を取得
            let isSpecial = item["isSpecial"] as? Bool ?? false
            let originalInfo = item["originalInfo"] as? String
            let patternName = item["patternName"] as? String
            
            return TimeTableItem(
                subject: "\(dayName): \(subjectName)",  // デバッグ用に曜日を追加
                startTime: timeSlot,
                teacher: item["teacher"] as? String ?? "",
                room: item["roomName"] as? String ?? "",
                period: "\(period)限",
                color: item["color"] as? String ?? "0",  // デフォルト色を設定
                isSpecial: isSpecial,
                originalInfo: originalInfo,
                patternName: patternName
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

// ウィジェットプロバイダー
struct TimetableWidgetProvider: TimelineProvider {
    // アプリグループ識別子
    private let appGroupIdentifier = "group.com.kanhina.timetable"
    
    // プレースホルダーエントリー（プレビュー用）
    func placeholder(in context: Context) -> TimetableWidgetEntry {
        // サンプルの時間割で初期化
        let sampleItems = [
            TimeTableItem(subject: "プログラミング", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限", color: "1"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限", color: "2"),
            TimeTableItem(subject: "AI入門", startTime: "13:00-14:30", teacher: "佐藤先生", room: "C301", period: "3限", color: "3")
        ]
        
        return TimetableWidgetEntry(date: Date(), timetableItems: sampleItems)
    }
    
    // スナップショット取得（ウィジェット追加時のプレビュー用）
    func getSnapshot(in context: Context, completion: @escaping (TimetableWidgetEntry) -> Void) {
        var entry: TimetableWidgetEntry
        
        if context.isPreview {
            // プレビュー用のダミーデータ
            entry = placeholder(in: context)
        } else {
            // 実データの取得
            let timetableItems = loadTimetableData()
            let patternName = loadPatternName()
            entry = TimetableWidgetEntry(date: Date(), timetableItems: timetableItems, patternName: patternName)
        }
        
        completion(entry)
    }
    
    // タイムライン作成（ウィジェット更新スケジュール）
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimetableWidgetEntry>) -> Void) {
        // 現在時刻を取得
        var entries: [TimetableWidgetEntry] = []
        let currentDate = Date()
        
        // アプリ共有データから時間割を取得
        let timetableItems = loadTimetableData()
        let patternName = loadPatternName()
        
        // 24時間分のエントリーを作成（12時間ごとに更新）
        for hourOffset in 0 ..< 24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = TimetableWidgetEntry(date: entryDate, timetableItems: timetableItems, patternName: patternName)
            entries.append(entry)
        }
        
        // 次の日の0時に更新するタイムライン
        let nextDay = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!)
        let refreshPolicy = WidgetKit.RefreshPolicy.atEnd
        let timeline = Timeline(entries: entries, policy: refreshPolicy)
        
        completion(timeline)
    }
    
    // 共有UserDefaultsから時間割データを読み込む
    private func loadTimetableData() -> [TimeTableItem] {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let rawData = sharedDefaults.array(forKey: "widgetTimetableData") as? [[String: Any]] else {
            print("ウィジェット: 時間割データが読み込めませんでした")
            return []
        }
        
        // データを変換
        var timetableItems: [TimeTableItem] = []
        
        for itemData in rawData {
            // 必要なデータを取り出す
            let subject = itemData["subjectName"] as? String
            let room = itemData["roomName"] as? String
            let teacher = itemData["teacher"] as? String
            let period = itemData["period"] as? String
            let startTime = itemData["startTime"] as? String
            let color = itemData["color"] as? String
            let isSpecial = itemData["isSpecial"] as? Bool ?? false
            let originalInfo = itemData["originalInfo"] as? String
            
            // TimeTableItemを作成
            let item = TimeTableItem(
                subject: subject,
                startTime: startTime,
                teacher: teacher,
                room: room,
                period: period,
                color: color,
                isSpecial: isSpecial,
                originalInfo: originalInfo
            )
            
            timetableItems.append(item)
        }
        
        return timetableItems
    }
    
    // 特殊時程名を読み込む
    private func loadPatternName() -> String {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return "通常時程"
        }
        
        let hasSpecialSchedule = sharedDefaults.bool(forKey: "widgetTodayHasSpecialSchedule")
        if hasSpecialSchedule {
            return sharedDefaults.string(forKey: "widgetTodayPatternName") ?? "特殊時程"
        } else {
            return "通常時程"
        }
    }
}

// ウィジェット設定
struct TimetableWidget: Widget {
    let kind: String = "TimetableWidiget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimetableWidgetProvider()) { entry in
            TimetableWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("時間割ウィジェット")
        .description("今日の時間割をホーム画面に表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// プレビュー
struct TimetableWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            TimeTableItem(subject: "プログラミング", startTime: "9:00-10:30", teacher: "山田先生", room: "A101", period: "1限", color: "1"),
            TimeTableItem(subject: "データベース", startTime: "10:40-12:10", teacher: "鈴木先生", room: "B201", period: "2限", color: "2"),
            TimeTableItem(subject: "AI入門", startTime: "13:00-14:30", teacher: "佐藤先生", room: "C301", period: "3限", color: "3")
        ]
        
        let entry = TimetableWidgetEntry(date: Date(), timetableItems: sampleItems)
        
        return TimetableWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}