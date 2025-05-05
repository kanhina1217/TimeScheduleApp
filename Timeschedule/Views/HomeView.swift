import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pattern.name, ascending: true)],
        animation: .default)
    private var patterns: FetchedResults<Pattern>
    
    @State private var today = Date()
    @State private var tomorrow: Date
    
    // 初期化
    init() {
        // 明日の日付を計算
        let calendar = Calendar.current
        let todayDate = Date()
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: todayDate) {
            _tomorrow = State(initialValue: nextDay)
        } else {
            _tomorrow = State(initialValue: todayDate)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 今日の日付セクション
                VStack(alignment: .leading) {
                    Text("今日の予定")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text(formattedDate(date: today))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // 今日の時間割カード
                    TodayScheduleCard(date: today)
                }
                
                Divider()
                
                // 明日の日付セクション
                VStack(alignment: .leading) {
                    Text("明日の予定")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text(formattedDate(date: tomorrow))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // 明日の時間割カード
                    TodayScheduleCard(date: tomorrow)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("ホーム")
        .onAppear {
            // 現在日時を更新
            today = Date()
            let calendar = Calendar.current
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: today) {
                tomorrow = nextDay
            }
        }
    }
    
    // 日付のフォーマット
    func formattedDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 (EEE)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// 1日の時間割を表示するカードView
struct TodayScheduleCard: View {
    let date: Date
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var timetables: FetchedResults<Timetable>
    @State private var specialTimetables: [NSManagedObject] = []
    @State private var specialScheduleConfigs: [SpecialScheduleManager.PeriodReorderConfig] = []
    @State private var patternName: String = "通常"
    @State private var isSpecialSchedule: Bool = false
    @State private var basePattern: Pattern? = nil
    
    // 1-5限の固定配列
    private let periods = [1, 2, 3, 4, 5]
    
    init(date: Date) {
        self.date = date
        
        // 曜日を取得 (1=日曜日, 2=月曜日, ...)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // 日本の曜日に変換（月曜日=1）
        // 月曜(2)→1, 火曜(3)→2, ..., 日曜(1)→7
        let japaneseWeekday = weekday == 1 ? 7 : weekday - 1
        
        // 当日の時間割を取得（特殊時程がない場合のデフォルト）
        _timetables = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Timetable.period, ascending: true)
            ],
            predicate: NSPredicate(format: "dayOfWeek == %d", japaneseWeekday)
        )
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // パターン情報
            HStack {
                Label(patternName, systemImage: "clock")
                    .font(.headline)
                Spacer()
                dayOfWeekBadge
            }
            .padding(.horizontal)
            
            // 時間割リスト - 常に1-5限を表示
            ForEach(periods, id: \.self) { period in
                if isSpecialSchedule {
                    // 特殊時程の場合
                    if let timetableForPeriod = findSpecialTimetable(forPeriod: period) {
                        TimetableRowWithOriginalInfo(
                            timetable: timetableForPeriod,
                            pattern: basePattern,
                            originalInfo: findOriginalInfo(forPeriod: period)
                        )
                    } else {
                        EmptyTimetableRow(
                            period: period,
                            pattern: basePattern
                        )
                    }
                } else {
                    // 通常時程の場合
                    if let timetable = findTimetable(forPeriod: period) {
                        TimetableRowWithPattern(
                            timetable: timetable,
                            pattern: basePattern ?? timetable.pattern
                        )
                    } else {
                        EmptyTimetableRow(
                            period: period,
                            pattern: findDefaultPattern()
                        )
                    }
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .onAppear {
            // カレンダーから特殊時程を取得
            checkSpecialSchedule()
        }
    }
    
    // 特殊時程の確認
    func checkSpecialSchedule() {
        // 環境オブジェクトからContext取得
        let context = PersistenceController.shared.container.viewContext
        
        // カレンダーから特殊時程を取得
        if let specialSchedule = CalendarManager.shared.getSpecialScheduleForDate(date) {
            // パターン名を設定
            patternName = specialSchedule.patternName
            
            // 特殊時程の時間割データを取得
            specialTimetables = SpecialScheduleManager.shared.getTimetableDataForSpecialSchedule(date: date, context: context)
            
            // 特殊時程の設定情報を取得（元の時程情報を表示するため）
            specialScheduleConfigs = SpecialScheduleManager.shared.getSpecialScheduleData(for: date, context: context)
            
            // ベースとなるパターンを取得
            basePattern = findDefaultPattern()
            
            isSpecialSchedule = !specialTimetables.isEmpty
        } else {
            // 特殊時程がなければデフォルトパターンの名前を表示
            let fetchRequest: NSFetchRequest<Pattern> = Pattern.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "isDefault == %@", NSNumber(value: true))
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                if let defaultPattern = results.first {
                    patternName = defaultPattern.name ?? "通常時程"
                    basePattern = defaultPattern
                } else {
                    patternName = "通常時程"
                    basePattern = nil
                }
            } catch {
                print("デフォルトパターンの取得に失敗しました: \(error)")
                patternName = "通常時程"
                basePattern = nil
            }
            
            // 特殊時程フラグをリセット
            isSpecialSchedule = false
        }
    }
    
    // 指定した限数の時間割を取得（通常時程用）
    private func findTimetable(forPeriod: Int) -> Timetable? {
        return timetables.first { Int($0.period) == forPeriod }
    }
    
    // 指定した限数の時間割を取得（特殊時程用）
    private func findSpecialTimetable(forPeriod: Int) -> Timetable? {
        return specialTimetables.first { 
            if let timetable = $0 as? Timetable {
                // periodプロパティを安全に比較
                return Int(timetable.period) == forPeriod 
            }
            return false
        } as? Timetable
    }
    
    // 元の時程情報を取得（特殊時程用）
    private func findOriginalInfo(forPeriod: Int) -> String? {
        // 特殊時程の設定から対象の時限に該当する情報を検索
        for config in specialScheduleConfigs {
            let targetIndex = config.targetPeriods.firstIndex(of: forPeriod)
            if let index = targetIndex {
                if index < config.originalPeriods.count {
                    let originalPeriod = config.originalPeriods[index]
                    let originalDay = config.originalDay
                    
                    // 曜日を日本語表記に変換（0=月、1=火...）
                    let days = ["月", "火", "水", "木", "金", "土", "日"]
                    if originalDay >= 0 && originalDay < days.count {
                        return "（\(days[originalDay])\(originalPeriod)）"
                    }
                }
            }
        }
        return nil
    }
    
    // デフォルトパターンを取得
    private func findDefaultPattern() -> Pattern? {
        let fetchRequest: NSFetchRequest<Pattern> = Pattern.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isDefault == %@", NSNumber(value: true))
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("デフォルトパターンの取得に失敗しました: \(error)")
            return nil
        }
    }
    
    // 曜日バッジ
    var dayOfWeekBadge: some View {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let days = ["日", "月", "火", "水", "木", "金", "土"]
        
        return Text(days[weekday - 1])
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(weekdayColor(for: weekday))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
    
    // 曜日に対応する色
    func weekdayColor(for weekday: Int) -> Color {
        switch weekday {
        case 1: return .red       // 日曜日
        case 7: return .blue      // 土曜日
        default: return .green    // 平日
        }
    }
}

// 時間割の行（特殊時程の元情報付き）
struct TimetableRowWithOriginalInfo: View {
    let timetable: Timetable
    let pattern: Pattern?
    let originalInfo: String?
    
    var body: some View {
        HStack(alignment: .center) {
            // 時限
            Text("\(timetable.period)限")
                .font(.headline)
                .frame(width: 40)
            
            // 時間（パターンから取得）
            if let pattern = pattern ?? timetable.pattern {
                VStack(alignment: .center) {
                    Text(pattern.startTimeForPeriod(Int(timetable.period)))
                        .font(.caption)
                    Text("〜")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(pattern.endTimeForPeriod(Int(timetable.period)))
                        .font(.caption)
                }
                .frame(width: 60)
            } else {
                Text("--:-- - --:--")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
            
            // 縦線
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 36)
            
            // 教科情報
            VStack(alignment: .leading) {
                // 科目名と元の時程情報を表示
                Text((timetable.subjectName ?? "未設定") + (originalInfo ?? ""))
                    .fontWeight(.medium)
                
                if let classroom = timetable.classroom, !classroom.isEmpty {
                    Text(classroom)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 8)
            
            Spacer()
            
            // 教科の色
            Circle()
                .fill(timetable.displayColor)
                .frame(width: 12, height: 12)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// 時間割の行（通常時程、パターン指定）
struct TimetableRowWithPattern: View {
    let timetable: Timetable
    let pattern: Pattern?
    
    var body: some View {
        HStack(alignment: .center) {
            // 時限
            Text("\(timetable.period)限")
                .font(.headline)
                .frame(width: 40)
            
            // 時間（指定されたパターンから取得）
            if let pattern = pattern {
                VStack(alignment: .center) {
                    Text(pattern.startTimeForPeriod(Int(timetable.period)))
                        .font(.caption)
                    Text("〜")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(pattern.endTimeForPeriod(Int(timetable.period)))
                        .font(.caption)
                }
                .frame(width: 60)
            } else {
                Text("--:-- - --:--")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
            
            // 縦線
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 36)
            
            // 教科情報
            VStack(alignment: .leading) {
                Text(timetable.subjectName ?? "未設定")
                    .fontWeight(.medium)
                
                if let classroom = timetable.classroom, !classroom.isEmpty {
                    Text(classroom)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 8)
            
            Spacer()
            
            // 教科の色
            Circle()
                .fill(timetable.displayColor)
                .frame(width: 12, height: 12)
                .padding(.trailing, 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// 空の時間割行（授業がない場合）
struct EmptyTimetableRow: View {
    let period: Int
    let pattern: Pattern?
    
    var body: some View {
        HStack(alignment: .center) {
            // 時限
            Text("\(period)限")
                .font(.headline)
                .frame(width: 40)
            
            // 時間（パターンから取得）
            if let pattern = pattern {
                VStack(alignment: .center) {
                    Text(pattern.startTimeForPeriod(period))
                        .font(.caption)
                    Text("〜")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(pattern.endTimeForPeriod(period))
                        .font(.caption)
                }
                .frame(width: 60)
            } else {
                Text("--:-- - --:--")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
            
            // 縦線
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 36)
            
            // 教科情報
            Text("授業なし")
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}