import Foundation
import CoreData
import EventKit

/// 特殊時程と時間割の調整を管理するクラス
class SpecialScheduleManager {
    static let shared = SpecialScheduleManager()
    
    private init() {}
    
    // 特殊時程の識別子
    enum ScheduleType: String {
        case normal = "通常"
        case shortA = "短縮A時程"
        case shortB = "短縮B時程"
        case shortC = "短縮C時程"
        case exam = "テスト時程"
        case custom = "カスタム"
        
        // 時程パターン名から列挙型を取得
        static func fromPatternName(_ name: String) -> ScheduleType {
            switch name.lowercased() {
            case _ where name.contains("短縮a"): return .shortA
            case _ where name.contains("短縮b"): return .shortB
            case _ where name.contains("短縮c"): return .shortC
            case _ where name.contains("テスト") || name.contains("試験"): return .exam
            case _ where name.contains("通常"): return .normal
            default: return .custom
            }
        }
    }
    
    // 時間割並べ替え設定
    struct PeriodReorderConfig {
        var originalDay: Int // 元の曜日（0=月曜日、1=火曜日...）
        var targetDay: Int   // 配置する曜日（0=月曜日、1=火曜日...）
        var originalPeriods: [Int] // 元の時限番号
        var targetPeriods: [Int]   // 配置先の時限番号
        
        init(originalDay: Int, targetDay: Int, originalPeriods: [Int], targetPeriods: [Int]) {
            self.originalDay = originalDay
            self.targetDay = targetDay
            self.originalPeriods = originalPeriods
            self.targetPeriods = targetPeriods
        }
        
        // 単一コマの移動設定
        static func singleMove(from: (day: Int, period: Int), to: (day: Int, period: Int)) -> PeriodReorderConfig {
            return PeriodReorderConfig(
                originalDay: from.day,
                targetDay: to.day,
                originalPeriods: [from.period],
                targetPeriods: [to.period]
            )
        }
    }
    
    // 特定の日の時間割並べ替え設定を生成
    func createReorderConfigForDate(_ date: Date, context: NSManagedObjectContext) -> [PeriodReorderConfig] {
        // カレンダーから特殊時程を取得
        guard let specialSchedule = CalendarManager.shared.getSpecialScheduleForDate(date) else {
            return [] // 特殊時程がなければ空の配列を返す
        }
        
        // パターン名から時程タイプを判定
        let scheduleType = ScheduleType.fromPatternName(specialSchedule.patternName)
        
        // 曜日を取得（0=日曜、1=月曜...）
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) - 1 // 曜日インデックス（0=日曜）
        let japaneseWeekday = (weekday + 6) % 7 // 日本式曜日インデックス（0=月曜）
        
        // 時程タイプに基づいて設定を生成
        switch scheduleType {
        case .shortA:
            return createShortAConfig(forWeekday: japaneseWeekday)
        case .shortB:
            return createShortBConfig(forWeekday: japaneseWeekday)
        case .shortC:
            return createShortCConfig(forWeekday: japaneseWeekday)
        case .exam:
            return createExamConfig(forWeekday: japaneseWeekday)
        case .custom:
            // カスタム設定の場合はパターン名から解析
            return parseCustomConfig(patternName: specialSchedule.patternName, forWeekday: japaneseWeekday)
        case .normal:
            return [] // 通常時程の場合は変更なし
        }
    }
    
    // 短縮A時程の設定を生成（例：5時間を4時間に圧縮）
    private func createShortAConfig(forWeekday: Int) -> [PeriodReorderConfig] {
        // 短縮A時程: 5時限を4時限に圧縮（5限目を省略）
        return [
            PeriodReorderConfig(
                originalDay: forWeekday,
                targetDay: forWeekday,
                originalPeriods: [1, 2, 3, 4],
                targetPeriods: [1, 2, 3, 4]
            )
            // 5限目は表示しない
        ]
    }
    
    // 短縮B時程の設定を生成（例：5時間を3時間に圧縮）
    private func createShortBConfig(forWeekday: Int) -> [PeriodReorderConfig] {
        // 短縮B時程: 5時限を3時限に圧縮（4,5限目を省略）
        return [
            PeriodReorderConfig(
                originalDay: forWeekday,
                targetDay: forWeekday,
                originalPeriods: [1, 2, 3],
                targetPeriods: [1, 2, 3]
            )
            // 4,5限目は表示しない
        ]
    }
    
    // 短縮C時程の設定を生成（例：午前のみ、午後なし）
    private func createShortCConfig(forWeekday: Int) -> [PeriodReorderConfig] {
        // 短縮C時程: 午前中のみ（1-3限）
        return [
            PeriodReorderConfig(
                originalDay: forWeekday,
                targetDay: forWeekday,
                originalPeriods: [1, 2, 3],
                targetPeriods: [1, 2, 3]
            )
        ]
    }
    
    // テスト時程の設定を生成
    private func createExamConfig(forWeekday: Int) -> [PeriodReorderConfig] {
        // テスト時程: デフォルトは1-3限のみ
        return [
            PeriodReorderConfig(
                originalDay: forWeekday,
                targetDay: forWeekday,
                originalPeriods: [1, 2, 3],
                targetPeriods: [1, 2, 3]
            )
        ]
    }
    
    // カスタム時程の設定を解析
    private func parseCustomConfig(patternName: String, forWeekday: Int) -> [PeriodReorderConfig] {
        print("parseCustomConfig: 解析開始 - パターン名: \(patternName), 曜日: \(forWeekday)")
        
        // 単純に曜日と時限の組み合わせを解析
        let parts = parseMultiDayAndPeriods(from: patternName)
        print("parseCustomConfig: 解析された時程パーツ数: \(parts.count)")
        
        var configs: [PeriodReorderConfig] = []
        var currentTargetPeriod = 1  // 表示する時限は1から順番に割り当てる
        
        // 各曜日・時限の組み合わせを処理
        for (index, part) in parts.enumerated() {
            if let day = part.day, let periods = part.periods, !periods.isEmpty {
                print("parseCustomConfig: パーツ[\(index)] - 曜日: \(day), 時限: \(periods)")
                
                // 元の曜日と時限をそのまま特殊時程の配置先にマッピング
                configs.append(PeriodReorderConfig(
                    originalDay: day,            // 元の曜日
                    targetDay: forWeekday,       // 配置先は現在の曜日
                    originalPeriods: periods,    // 元の時限
                    targetPeriods: Array(currentTargetPeriod...(currentTargetPeriod + periods.count - 1))  // 1,2,3...と順番に割り当て
                ))
                
                print("parseCustomConfig: 設定追加 - 元曜日: \(day), 元時限: \(periods), 先時限: \(Array(currentTargetPeriod...(currentTargetPeriod + periods.count - 1)))")
                
                // 次の時限開始位置を更新
                currentTargetPeriod += periods.count
            }
        }
        
        // 設定がない場合は元の曜日のデフォルト設定を使用
        if configs.isEmpty {
            print("parseCustomConfig: 有効な設定が見つかりませんでした。デフォルト設定を使用")
            // 文字列中に数字を探して時限として解釈する
            let periods = extractNumbers(from: patternName)
            if !periods.isEmpty {
                print("parseCustomConfig: 見つかった時限: \(periods)")
                configs.append(PeriodReorderConfig(
                    originalDay: forWeekday,
                    targetDay: forWeekday,
                    originalPeriods: periods,
                    targetPeriods: periods
                ))
            } else {
                print("parseCustomConfig: 時限も見つかりませんでした。")
            }
        }
        
        print("parseCustomConfig: 解析完了 - 最終設定数: \(configs.count)")
        return configs
    }
    
    // 文字列から数字を抽出
    private func extractNumbers(from text: String) -> [Int] {
        return text.compactMap { char in
            Int(String(char))
        }.filter { $0 > 0 && $0 < 10 } // 1~9の数字のみ
    }
    
    // 曜日と時限のパース（例: "月12345" → 曜日=0, 時限=[1,2,3,4,5]）
    private func parseDayAndPeriods(from text: String) -> (day: Int?, periods: [Int]?) {
        let dayMap = ["月": 0, "火": 1, "水": 2, "木": 3, "金": 4, "土": 5, "日": 6]
        var day: Int? = nil
        var periods: [Int] = []
        
        // 先頭の文字を曜日として解釈
        if let firstChar = text.first, let mappedDay = dayMap[String(firstChar)] {
            day = mappedDay
            
            // 残りの文字を時限として解釈
            let startIndex = text.index(after: text.startIndex)
            let periodText = String(text[startIndex...])
            
            for char in periodText {
                if let period = Int(String(char)) {
                    periods.append(period)
                }
            }
        }
        
        return (day, periods.isEmpty ? nil : periods)
    }
    
    // 複数曜日と時限のパース（例: "月123水45" → [(曜日=0, 時限=[1,2,3]), (曜日=2, 時限=[4,5])]）
    private func parseMultiDayAndPeriods(from text: String) -> [(day: Int?, periods: [Int]?)] {
        let dayMap = ["月": 0, "火": 1, "水": 2, "木": 3, "金": 4, "土": 5, "日": 6]
        var result: [(day: Int?, periods: [Int]?)] = []
        
        var currentDay: Int? = nil
        var currentPeriods: [Int] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let char = text[currentIndex]
            let charString = String(char)
            
            // 曜日かチェック
            if let dayIndex = dayMap[charString] {
                // 前の曜日のデータがあれば保存
                if currentDay != nil && !currentPeriods.isEmpty {
                    result.append((currentDay, currentPeriods))
                    currentPeriods = []
                }
                currentDay = dayIndex
            }
            // 数字（時限）かチェック
            else if let period = Int(charString) {
                currentPeriods.append(period)
            }
            
            currentIndex = text.index(after: currentIndex)
        }
        
        // 最後の曜日のデータを保存
        if currentDay != nil && !currentPeriods.isEmpty {
            result.append((currentDay, currentPeriods))
        }
        
        return result
    }
    
    // 特殊時程に基づいて時間割データを適用
    func applySpecialSchedule(for date: Date, context: NSManagedObjectContext) -> Bool {
        // 設定を取得
        let configs = createReorderConfigForDate(date, context: context)
        guard !configs.isEmpty else {
            return false // 適用する設定がない
        }
        
        // 特殊時程の情報を臨時データとして保存
        saveSpecialScheduleData(for: date, configs: configs, context: context)
        
        return true
    }
    
    // 特殊時程に基づいて時間割データを適用（カスタムマッピングとベースパターン名指定版）
    func applySpecialSchedule(for date: Date, context: NSManagedObjectContext, customMapping: String? = nil, basePatternName: String? = nil) -> Bool {
        print("applySpecialSchedule: 特殊時程を適用します - 日付: \(date), カスタムマッピング: \(customMapping ?? "なし"), ベースパターン: \(basePatternName ?? "なし")")
        
        // カスタムマッピングが指定されている場合
        if let mapping = customMapping, !mapping.isEmpty {
            print("applySpecialSchedule: カスタムマッピングを処理: \(mapping)")
            
            // カスタムマッピングを解析
            let configs = parseCustomConfig(patternName: mapping, forWeekday: getWeekdayIndex(for: date))
            
            if !configs.isEmpty {
                print("applySpecialSchedule: カスタム設定の解析に成功 - 設定数: \(configs.count)")
                // 特殊時程の情報を臨時データとして保存
                saveSpecialScheduleData(for: date, configs: configs, context: context)
                
                // デバッグ: 保存した設定内容を確認
                let savedConfigs = getSpecialScheduleData(for: date, context: context)
                print("applySpecialSchedule: 保存された設定数: \(savedConfigs.count)")
                
                return true
            } else {
                print("applySpecialSchedule: カスタム設定の解析結果が空です")
            }
        } else {
            print("applySpecialSchedule: カスタムマッピングなし")
        }
        
        // カスタムマッピングがない場合は通常の特殊時程を適用
        return applySpecialSchedule(for: date, context: context)
    }
    
    // 日付から曜日インデックスを取得（0=月曜、1=火曜...）
    private func getWeekdayIndex(for date: Date) -> Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) - 1 // 曜日インデックス（0=日曜）
        return (weekday + 6) % 7 // 日本式曜日インデックス（0=月曜）
    }
    
    // 特殊時程のマッピング情報を保存
    private func saveSpecialScheduleData(for date: Date, configs: [PeriodReorderConfig], context: NSManagedObjectContext) {
        // 同じ日付の既存データを削除
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SpecialSchedule")
        fetchRequest.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        
        do {
            // 既存データがあれば削除
            if let existingItems = try context.fetch(fetchRequest) as? [NSManagedObject], !existingItems.isEmpty {
                for item in existingItems {
                    context.delete(item)
                }
            }
            
            // 新しい設定を保存
            for config in configs {
                for i in 0..<config.originalPeriods.count {
                    guard i < config.targetPeriods.count else { continue }
                    
                    let originalPeriod = config.originalPeriods[i]
                    let targetPeriod = config.targetPeriods[i]
                    
                    // コアデータエンティティが存在することを前提としています
                    let specialSchedule = NSEntityDescription.insertNewObject(forEntityName: "SpecialSchedule", into: context)
                    specialSchedule.setValue(UUID(), forKey: "id")
                    specialSchedule.setValue(startOfDay, forKey: "date")
                    specialSchedule.setValue(Int16(config.originalDay), forKey: "originalDay")
                    specialSchedule.setValue(Int16(config.targetDay), forKey: "targetDay")
                    specialSchedule.setValue(Int16(originalPeriod), forKey: "originalPeriod")
                    specialSchedule.setValue(Int16(targetPeriod), forKey: "targetPeriod")
                    
                    // パターン名をカレンダーから取得して保存
                    if let scheduleInfo = CalendarManager.shared.getSpecialScheduleForDate(date) {
                        specialSchedule.setValue(scheduleInfo.patternName, forKey: "patternName")
                    }
                }
            }
            
            try context.save()
        } catch {
            print("特殊時程データの保存に失敗しました: \(error)")
        }
    }
    
    // 指定した日付の特殊時程データを取得
    func getSpecialScheduleData(for date: Date, context: NSManagedObjectContext) -> [PeriodReorderConfig] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SpecialSchedule")
        fetchRequest.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        
        do {
            if let items = try context.fetch(fetchRequest) as? [NSManagedObject], !items.isEmpty {
                // データからPeriodReorderConfigを再構築
                var configsMap = [String: PeriodReorderConfig]()
                
                for item in items {
                    let originalDay = item.value(forKey: "originalDay") as? Int16 ?? 0
                    let targetDay = item.value(forKey: "targetDay") as? Int16 ?? 0
                    let originalPeriod = item.value(forKey: "originalPeriod") as? Int16 ?? 0
                    let targetPeriod = item.value(forKey: "targetPeriod") as? Int16 ?? 0
                    
                    let key = "\(originalDay)-\(targetDay)"
                    if var config = configsMap[key] {
                        config.originalPeriods.append(Int(originalPeriod))
                        config.targetPeriods.append(Int(targetPeriod))
                        configsMap[key] = config
                    } else {
                        configsMap[key] = PeriodReorderConfig(
                            originalDay: Int(originalDay),
                            targetDay: Int(targetDay),
                            originalPeriods: [Int(originalPeriod)],
                            targetPeriods: [Int(targetPeriod)]
                        )
                    }
                }
                
                return Array(configsMap.values)
            }
        } catch {
            print("特殊時程データの取得に失敗しました: \(error)")
        }
        
        return []
    }
    
    // 特殊時程に基づいて時間割データを取得（表示用）
    func getTimetableDataForSpecialSchedule(date: Date, context: NSManagedObjectContext) -> [NSManagedObject] {
        print("getTimetableDataForSpecialSchedule: 特殊時程の時間割データを取得 - 日付: \(date)")
        
        // 特殊時程の設定を取得
        let configs = getSpecialScheduleData(for: date, context: context)
        print("getTimetableDataForSpecialSchedule: 取得した設定数: \(configs.count)")
        
        if configs.isEmpty {
            // 特殊時程がなければ通常のデータを返す
            print("getTimetableDataForSpecialSchedule: 特殊時程の設定がありません")
            return fetchRegularTimetableData(context: context)
        }
        
        // 特殊時程に基づいて時間割を再構成
        var result: [NSManagedObject] = []
        
        for (index, config) in configs.enumerated() {
            print("getTimetableDataForSpecialSchedule: 設定[\(index)]を処理 - 元曜日: \(config.originalDay), 先曜日: \(config.targetDay)")
            
            // 元の曜日のデータを取得
            let originalTimetables = fetchTimetableData(for: config.originalDay, context: context)
            print("getTimetableDataForSpecialSchedule: 元曜日の時間割数: \(originalTimetables.count)")
            
            // 各時限ごとに特殊時程用のデータを作成
            for i in 0..<config.originalPeriods.count {
                guard i < config.targetPeriods.count else { continue }
                
                let originalPeriod = config.originalPeriods[i]
                let targetPeriod = config.targetPeriods[i]
                
                print("getTimetableDataForSpecialSchedule: 時限マッピング - 元: \(originalPeriod) → 先: \(targetPeriod)")
                
                // 元の時限のデータを探す
                if let originalData = originalTimetables.first(where: { $0.value(forKey: "period") as? Int16 == Int16(originalPeriod) }) {
                    // 特殊時程用に時間割データをコピー
                    let specialTimetable = copyTimetableData(
                        original: originalData,
                        targetDay: config.targetDay,
                        targetPeriod: targetPeriod,
                        context: context
                    )
                    
                    result.append(specialTimetable)
                    print("getTimetableDataForSpecialSchedule: 時間割データを追加 - 科目: \(originalData.value(forKey: "subjectName") ?? "未設定")")
                } else {
                    print("getTimetableDataForSpecialSchedule: 元時限のデータが見つかりません - 曜日: \(config.originalDay), 時限: \(originalPeriod)")
                }
            }
        }
        
        print("getTimetableDataForSpecialSchedule: 結果の時間割数: \(result.count)")
        return result
    }
    
    // 通常の時間割データを取得
    private func fetchRegularTimetableData(context: NSManagedObjectContext) -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Timetable")
        
        do {
            return try context.fetch(fetchRequest) as? [NSManagedObject] ?? []
        } catch {
            print("時間割データの取得に失敗しました: \(error)")
            return []
        }
    }
    
    // 特定の曜日の時間割データを取得
    private func fetchTimetableData(for day: Int, context: NSManagedObjectContext) -> [NSManagedObject] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Timetable")
        // UIインデックス（0=月曜）からCoreData形式（0=日曜）に変換
        let coreDataDay = (day + 1) % 7
        fetchRequest.predicate = NSPredicate(format: "dayOfWeek == %d", Int16(coreDataDay))
        
        do {
            return try context.fetch(fetchRequest) as? [NSManagedObject] ?? []
        } catch {
            print("曜日別時間割データの取得に失敗しました: \(error)")
            return []
        }
    }
    
    // 時間割データをコピーして特殊時程用に変更
    private func copyTimetableData(original: NSManagedObject, targetDay: Int, targetPeriod: Int, context: NSManagedObjectContext) -> NSManagedObject {
        // CoreData形式の曜日に変換
        let coreDataTargetDay = (targetDay + 1) % 7
        
        // 新しいメモリ上の時間割データを作成（保存はしない）
        let entity = NSEntityDescription.entity(forEntityName: "Timetable", in: context)!
        let specialTimetable = NSManagedObject(entity: entity, insertInto: nil) // コンテキストには追加しない
        
        // 元のデータの属性をコピー
        let attributes = entity.attributesByName
        for (name, _) in attributes {
            if let value = original.value(forKey: name) {
                specialTimetable.setValue(value, forKey: name)
            }
        }
        
        // 特殊時程用の設定を上書き
        specialTimetable.setValue(Int16(coreDataTargetDay), forKey: "dayOfWeek")
        specialTimetable.setValue(Int16(targetPeriod), forKey: "period")
        specialTimetable.setValue(true, forKey: "isSpecial") // 特殊時程用フラグ
        
        return specialTimetable
    }
}