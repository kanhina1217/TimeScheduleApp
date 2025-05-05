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
    @FetchRequest private var timetables: FetchedResults<Timetable>
    @State private var patternName: String = "通常"
    
    init(date: Date) {
        self.date = date
        
        // 曜日を取得 (0=月曜日, 1=火曜日, ...)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // 日本の曜日に変換（月曜日=0）
        let japaneseWeekday = (weekday + 5) % 7
        
        // 当日の時間割を取得
        _timetables = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Timetable.period, ascending: true)
            ],
            predicate: NSPredicate(format: "dayOfWeek == %d", japaneseWeekday)
        )
        
        // 特殊時程を確認（本来はカレンダーから取得するロジックが必要）
        // ここでは簡易的に実装
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
            
            // 時間割リスト
            if timetables.isEmpty {
                Text("授業はありません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(timetables) { timetable in
                    TimetableRow(timetable: timetable)
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .onAppear {
            // カレンダーから特殊時程を取得する処理（実際の実装では必要）
            checkSpecialSchedule()
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
    
    // 特殊時程の確認（実際の実装では、カレンダーから取得する）
    func checkSpecialSchedule() {
        // TODO: CalendarManagerから特殊時程を取得する
        // サンプルとして、曜日によってパターンを変える
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        if weekday == 3 { // 水曜日
            patternName = "短縮時程"
        } else {
            patternName = "通常時程"
        }
    }
}

// 時間割の行
struct TimetableRow: View {
    let timetable: Timetable
    
    var body: some View {
        HStack(alignment: .center) {
            // 時限
            Text("\(timetable.period)限")
                .font(.headline)
                .frame(width: 40)
            
            // 時間（パターンから取得）
            if let pattern = timetable.pattern {
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}