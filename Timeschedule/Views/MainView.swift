import SwiftUI
import CoreData
import WidgetKit

// 時間割のセル表示用コンポーネント
struct TimetableCellView: View {
    let timetable: Timetable?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack {
                if let timetable = timetable, let subjectName = timetable.subjectName, !subjectName.isEmpty {
                    // 時間割データがある場合
                    Text(subjectName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(timetable.classroom ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // 空きコマの場合
                    Text("")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(getCellColor(for: timetable))
            .cornerRadius(8)
        }
    }
    
    // セルの背景色を取得
    private func getCellColor(for timetable: Timetable?) -> Color {
        guard let timetable = timetable, let colorName = timetable.color, let subjectName = timetable.subjectName, !subjectName.isEmpty else {
            return Color(.systemGray6)  // データがない場合のデフォルト色
        }
        
        // 色名に基づいて色を返す
        switch colorName {
        case "red": return Color.red.opacity(0.3)
        case "blue": return Color.blue.opacity(0.3)
        case "green": return Color.green.opacity(0.3)
        case "yellow": return Color.yellow.opacity(0.3)
        case "purple": return Color.purple.opacity(0.3)
        default: return Color(.systemGray6)
        }
    }
}

// 時間情報表示コンポーネント
struct PeriodInfoView: View {
    let period: Int
    let pattern: Pattern?
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(period)")
                .font(.headline)
                .frame(width: 50)
            
            if let pattern = pattern {
                let startTime = pattern.startTimeForPeriod(period)
                Text(startTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                let endTime = pattern.endTimeForPeriod(period)
                Text(endTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 50)
    }
}

// パターン選択コンポーネント
struct PatternPickerView: View {
    @Binding var selectedPattern: Pattern?
    let patterns: FetchedResults<Pattern>
    
    var body: some View {
        Group {
            if patterns.isEmpty {
                EmptyView()
            } else {
                // 明示的な型で中間データを作成
                let items: [(id: UUID, pattern: Pattern, name: String)] = patterns.map { pattern in
                    (id: pattern.id ?? UUID(), pattern: pattern, name: pattern.name ?? "不明")
                }
                
                Picker("パターン", selection: $selectedPattern) {
                    ForEach(items, id: \.id) { item in
                        Text(item.name).tag(item.pattern as Pattern?)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
            }
        }
    }
}

// メインビュー
struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // パターンのFetchRequest
    @FetchRequest(
        entity: Pattern.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Pattern.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \Pattern.name, ascending: true)
        ],
        animation: .default)
    private var patterns: FetchedResults<Pattern>
    
    // 時間割データのFetchRequest
    @FetchRequest(
        entity: Timetable.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Timetable.dayOfWeek, ascending: true),
            NSSortDescriptor(keyPath: \Timetable.period, ascending: true)
        ],
        animation: .default)
    private var timetables: FetchedResults<Timetable>
    
    // 状態変数
    @State private var selectedPattern: Pattern?
    @State private var showingDetailSheet = false
    @State private var showingAddSheet = false
    @State private var selectedDay = 0
    @State private var selectedPeriod = 1
    @State private var selectedTimetable: Timetable?
    
    // 曜日と時限
    private let daysOfWeek = ["月", "火", "水", "木", "金", "土", "日"]
    private let periodCount = 6
    
    var body: some View {
        NavigationView {
            VStack {
                // パターン選択コンポーネント
                PatternPickerView(selectedPattern: $selectedPattern, patterns: patterns)
                
                // タブ切り替えボタン
                HStack {
                    NavigationLink(destination: TaskManagementView()) {
                        HStack {
                            Image(systemName: "checklist")
                            Text("課題管理")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // 時間割表示
                timetableGridView
                
                Spacer()
            }
            .navigationTitle("時間割")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: PatternSettingsView()) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadDefaultPattern() }
            // FetchedResultsはEquatableに準拠していないため、.onChangeは使用できない
            // 代わりにonReceiveメソッドを使用するか、FetchRequestの.onChangeを使用する
            .onChange(of: selectedPattern) { _, _ in
                updateWidgetData()
                saveSelectedPatternID()
            }
            // onAppearで一度だけデータを更新し、個別のビューの更新に任せる
            .sheet(isPresented: $showingDetailSheet) {
                if let pattern = selectedPattern {
                    TimetableDetailView(
                        timetable: selectedTimetable,
                        day: selectedDay,
                        period: selectedPeriod,
                        pattern: pattern
                    )
                    .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                if let pattern = selectedPattern {
                    TimetableDetailView(pattern: pattern)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }
    
    // 時間割グリッドの表示
    private var timetableGridView: some View {
        ScrollView {
            VStack(spacing: 10) {
                // 曜日ヘッダー行
                HStack {
                    Text("") // 左上の空白セル
                        .frame(width: 50)
                    
                    let weekDays = Array(daysOfWeek.prefix(5))
                    ForEach(0..<weekDays.count, id: \.self) { index in
                        Text(weekDays[index])
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // 時限行
                let maxPeriods = selectedPattern?.periodCount ?? periodCount
                ForEach(1...maxPeriods, id: \.self) { periodNum in
                    periodRowView(period: periodNum)
                }
            }
        }
    }
    
    // 時限ごとの行表示
    private func periodRowView(period: Int) -> some View {
        VStack(spacing: 2) {
            HStack {
                // 時限情報
                PeriodInfoView(period: period, pattern: selectedPattern)
                
                // 曜日ごとのセル
                ForEach(0..<5, id: \.self) { dayIndex in
                    let timetable = fetchTimetable(for: dayIndex, period: Int16(period))
                    TimetableCellView(timetable: timetable) {
                        selectedDay = dayIndex
                        selectedPeriod = period
                        selectedTimetable = timetable
                        showingDetailSheet = true
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }
    
    // デフォルトパターンの読み込み
    private func loadDefaultPattern() {
        if selectedPattern == nil {
            if let defaultPattern = patterns.first(where: { $0.isDefault }) {
                selectedPattern = defaultPattern
            } else {
                selectedPattern = patterns.first
            }
        }
        updateWidgetData()
    }
    
    // 選択中のパターンをUserDefaultsに保存
    private func saveSelectedPatternID() {
        if let pattern = selectedPattern {
            UserDefaults.standard.set(pattern.id?.uuidString ?? "default", forKey: "currentPatternID")
        }
    }
    
    // 時間割データを取得
    private func fetchTimetable(for day: Int, period: Int16) -> Timetable? {
        let filtered = timetables.filter { timetable in
            return timetable.dayOfWeek == day && timetable.period == period
        }
        return filtered.first
    }
    
    // ウィジェットデータを更新
    private func updateWidgetData() {
        WidgetDataManager.shared.exportDataForWidget(context: viewContext)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
