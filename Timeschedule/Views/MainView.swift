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
            .overlay(
                // 特殊時程のセルには特別な枠線を表示
                RoundedRectangle(cornerRadius: 8)
                    .stroke(getStrokeColor(for: timetable), lineWidth: 2)
            )
        }
    }
    
    // セルの背景色を取得
    private func getCellColor(for timetable: Timetable?) -> Color {
        guard let timetable = timetable, let colorName = timetable.color else {
            return Color(.systemGray6)  // デフォルトの背景色
        }
        
        // 特殊時程のセルには枠線を付ける
        let baseColor = getColorFromName(colorName)
        
        if timetable.isSpecial {
            return baseColor.opacity(0.8)  // 特殊時程は少し不透明度を下げる
        }
        
        return baseColor
    }
    
    // 枠線の色を取得（特殊時程の場合のみ表示）
    private func getStrokeColor(for timetable: Timetable?) -> Color {
        guard let timetable = timetable, timetable.isSpecial else {
            return Color.clear // 通常のセルは枠線なし
        }
        
        return Color.orange.opacity(0.8) // 特殊時程のセルは目立つ枠線
    }
    
    // 色名からカラーを取得
    private func getColorFromName(_ name: String) -> Color {
        switch name {
        case "red": return Color.red.opacity(0.3)
        case "blue": return Color.blue.opacity(0.3)
        case "green": return Color.green.opacity(0.3)
        case "yellow": return Color.yellow.opacity(0.3)
        case "orange": return Color.orange.opacity(0.3)
        case "purple": return Color.purple.opacity(0.3)
        default: return Color.gray.opacity(0.3)
        }
    }
}

// 時限情報を表示するコンポーネント
struct PeriodInfoView: View {
    let period: Int
    let pattern: Pattern?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(period)")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let startTime = getStartTime(), let endTime = getEndTime() {
                Text("\(startTime)\n-\(endTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 50)
    }
    
    // 開始時刻を取得
    private func getStartTime() -> String? {
        guard let pattern = pattern,
              let periodTimes = pattern.periodTimes as? [[String: String]],
              period <= periodTimes.count else {
            return nil
        }
        
        return periodTimes[period - 1]["startTime"]
    }
    
    // 終了時刻を取得
    private func getEndTime() -> String? {
        guard let pattern = pattern,
              let periodTimes = pattern.periodTimes as? [[String: String]],
              period <= periodTimes.count else {
            return nil
        }
        
        return periodTimes[period - 1]["endTime"]
    }
}

// パターン選択ビュー
struct PatternPickerView: View {
    @Binding var selectedPattern: Pattern?
    let items: [PatternItem]
    
    struct PatternItem: Identifiable {
        let id: UUID
        let name: String
        let pattern: Pattern
    }
    
    var body: some View {
        if !items.isEmpty {
            VStack {
                Text("時程パターン")
                    .font(.headline)
                
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
    @State private var selectedDate = Date() // 表示する日付
    @State private var isDatePickerVisible = false // 日付選択の表示状態
    @State private var isSpecialScheduleActive = false // 特殊時程設定画面への遷移状態
    @State private var showingCalendarAlert = false // カレンダー連携のアラート
    @State private var specialTimetables: [NSManagedObject] = [] // 特殊時程のデータ
    @State private var isSpecialMode = false // 特殊時程表示モード
    
    // 曜日と時限
    private let daysOfWeek = ["月", "火", "水", "木", "金", "土", "日"]
    private let periodCount = 6
    
    // 曜日配列をプロパティに
    private var weekDays: [String] {
        Array(daysOfWeek.prefix(5))
    }

    // DateFormatterをプロパティに
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }

    // 曜日のインデックス変換メソッド
    
    /// CoreDataの曜日(0=日曜, 1=月曜...)から平日インデックス(0=月曜, 1=火曜...)へ変換
    private func convertCoreDataDayToWeekdayIndex(_ coreDataDay: Int) -> Int {
        // CoreDataの日付が0=日曜、1=月曜...の場合
        // 0=月曜、1=火曜...に変換
        return (coreDataDay + 6) % 7
    }
    
    /// 平日インデックス(0=月曜, 1=火曜...)からCoreDataの曜日(0=日曜, 1=月曜...)へ変換
    private func convertWeekdayIndexToCoreDataDay(_ weekdayIndex: Int) -> Int {
        // 0=月曜、1=火曜...から
        // CoreDataの0=日曜、1=月曜...に変換
        return (weekdayIndex + 1) % 7
    }
    
    private var patternItems: [PatternPickerView.PatternItem] {
        patterns.map { pattern in
            PatternPickerView.PatternItem(
                id: pattern.id ?? UUID(),
                name: pattern.name ?? "不明なパターン",
                pattern: pattern
            )
        }
    }
    
    // 特殊時程表示部分を抽出（onChangeの部分を修正）
    private var specialScheduleToggleView: some View {
        HStack {
            Label("特殊時程適用中", systemImage: "star.fill")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(5)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(5)
            
            // 特殊時程表示モードの切り替えスイッチ - onChangeを削除
            Toggle("特殊時程モード", isOn: $isSpecialMode)
                .labelsHidden()
                // onChange修飾子を適用せず、Toggleが値を変更
        }
    }
    
    // 日付表示部を修正 - isSpecialModeのチェックを分離
    private var dateHeaderView: some View {
        HStack {
            // 日付表示ボタン
            Button(action: { isDatePickerVisible.toggle() }) {
                HStack {
                    Image(systemName: "calendar")
                    Text(dateFormatter.string(from: selectedDate))
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // 特殊時程が適用されているかを別の変数でチェック
            if specialScheduleIsApplied() {
                specialScheduleToggleView
            }
            
            // 今日の日付に戻るボタン
            Button(action: {
                selectedDate = Date()
                loadTimetableForDate(selectedDate)
            }) {
                Text("今日")
                    .padding(8)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }

    // 特殊時程の適用をチェックする新しいメソッド（レンダリング時に毎回評価されないように分離）
    private func specialScheduleIsApplied() -> Bool {
        return isSpecialScheduleApplied(for: selectedDate)
    }

    // 日付ピッカー部を抽出
    private var datePickerView: some View {
        DatePicker("日付を選択", selection: $selectedDate, displayedComponents: .date)
            .datePickerStyle(GraphicalDatePickerStyle())
            .padding()
            .onChange(of: selectedDate) { _, newValue in
                loadTimetableForDate(newValue)
            }
    }

    // 曜日ヘッダー行を抽出
    private var weekdayHeaderView: some View {
        HStack {
            Text("") // 左上の空白セル
                .frame(width: 50)
            ForEach(weekDays, id: \.self) { day in
                Text(day)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
    
    // 時間割グリッドの表示を修正
    private var timetableGridView: some View {
        ScrollView {
            VStack(spacing: 10) {
                // 曜日ヘッダー行
                weekdayHeaderView
                
                // 時限行
                periodsView
            }
        }
    }
    
    // 時限行のコンテナ（ForEachを分離）
    private var periodsView: some View {
        let maxPeriods = selectedPattern?.periodCount ?? periodCount
        return VStack(spacing: 0) {
            ForEach(1...maxPeriods, id: \.self) { periodNum in
                periodRowView(period: periodNum)
            }
        }
    }

    // 1コマ分の行（1時限の5日分セル）を表示するビュー
    private struct CellRowView: View {
        let period: Int
        let selectedPattern: Pattern?
        let specialTimetables: [NSManagedObject]
        let isSpecialMode: Bool
        let timetables: FetchedResults<Timetable>
        let convertWeekdayIndexToCoreDataDay: (Int) -> Int
        let onTap: (Int, Timetable?) -> Void
        
        var body: some View {
            HStack {
                // 時限情報
                PeriodInfoView(period: period, pattern: selectedPattern)
                
                // 曜日ごとのセル
                ForEach(0..<5, id: \.self) { dayIndex in
                    let timetable = getTimetableForCell(dayIndex: dayIndex, period: Int16(period))
                    TimetableCellView(timetable: timetable) {
                        onTap(dayIndex, timetable)
                    }
                }
            }
            .padding(.horizontal)
        }
        
        // セル用の時間割データを取得（通常or特殊）
        private func getTimetableForCell(dayIndex: Int, period: Int16) -> Timetable? {
            if isSpecialMode && !specialTimetables.isEmpty {
                // 特殊時程データから該当するコマを探す
                let coreDataDay = convertWeekdayIndexToCoreDataDay(dayIndex)
                
                // 特殊時程のデータから該当するコマを探す
                for specialData in specialTimetables {
                    if let day = specialData.value(forKey: "dayOfWeek") as? Int16,
                       let p = specialData.value(forKey: "period") as? Int16,
                       day == coreDataDay && p == period {
                        
                        // NSManagedObjectをTimetableにキャスト
                        return specialData as? Timetable
                    }
                }
                return nil
            } else {
                // 通常の時間割データを取得
                return fetchTimetable(for: dayIndex, period: period)
            }
        }
        
        // 時間割データを取得
        private func fetchTimetable(for day: Int, period: Int16) -> Timetable? {
            // 新しいインデックス（月曜=0）からCoreData形式（日曜=0）に変換
            let coreDataDay = convertWeekdayIndexToCoreDataDay(day)
            let filtered = timetables.filter { timetable in
                return timetable.dayOfWeek == coreDataDay && timetable.period == period
            }
            return filtered.first
        }
    }

    // 時限ごとの行表示
    private func periodRowView(period: Int) -> some View {
        VStack(spacing: 2) {
            CellRowView(
                period: period,
                selectedPattern: selectedPattern,
                specialTimetables: specialTimetables,
                isSpecialMode: isSpecialMode,
                timetables: timetables,
                convertWeekdayIndexToCoreDataDay: convertWeekdayIndexToCoreDataDay,
                onTap: { dayIndex, timetable in
                    selectedDay = dayIndex
                    selectedPeriod = period
                    selectedTimetable = timetable
                    showingDetailSheet = true
                }
            )
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
    
    // ウィジェットデータを更新
    private func updateWidgetData() {
        WidgetDataManager.shared.exportDataForWidget(context: viewContext)
    }
    
    // 特定の日付に特殊時程が適用されているかチェック
    private func isSpecialScheduleApplied(for date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SpecialSchedule")
        fetchRequest.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return !results.isEmpty
        } catch {
            print("特殊時程データの確認に失敗しました: \(error)")
            return false
        }
    }
    
    // 選択した日付の時間割を読み込む
    private func loadTimetableForDate(_ date: Date) {
        // 特殊時程が適用されており、かつ特殊モードが有効な場合
        if isSpecialScheduleApplied(for: date) && isSpecialMode {
            // 特殊時程データに基づいて表示
            print("特殊時程が適用されているため、その内容を表示します")
            
            // 特殊時程データを取得
            specialTimetables = SpecialScheduleManager.shared.getTimetableDataForSpecialSchedule(date: date, context: viewContext)
            
            // 特殊時程フラグをオンに
            for (i, obj) in specialTimetables.enumerated() {
                if let timetable = obj as? Timetable {
                    timetable.isSpecial = true
                    specialTimetables[i] = timetable
                }
            }
        } else {
            // 通常時程または特殊時程が無効な場合
            print("通常の時間割を表示します")
            specialTimetables = []
            
            // 日付に対応する曜日を取得
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date) - 1 // 0=日曜日
            selectedDay = (weekday + 6) % 7 // 日本式 0=月曜日
        }
    }
    
    // カレンダーから特殊時程を読み込む
    private func loadScheduleFromCalendar() {
        let today = Date()

        // カレンダーからイベントを取得 (非同期に変更)
        CalendarManager.shared.fetchEvents(for: today) { events, error in
            if let error = error {
                print("カレンダーイベントの取得に失敗しました: \(error.localizedDescription)")
                // 必要に応じてユーザーにエラーを表示
                return
            }

            guard let events = events else {
                print("カレンダーイベントが見つかりませんでした。")
                return
            }

            // 時程パターンを示すイベントを探す
            var foundSchedule = false
            for event in events {
                if CalendarManager.shared.isScheduleEvent(event),
                   let pattern = CalendarManager.shared.extractSchedulePattern(from: event) {
                    print("カレンダーから時程パターン「\(pattern)」を検出しました。適用します。")
                    // 特殊時程があれば適用
                    let result = SpecialScheduleManager.shared.applySpecialSchedule(for: today, context: viewContext)

                    if result {
                        // 特殊時程モードを有効にする
                        isSpecialMode = true
                        print("特殊時程モードを有効にしました。")
                    }

                    // UIを更新
                    selectedDate = today
                    loadTimetableForDate(today)
                    foundSchedule = true
                    break // 最初の特殊時程イベントが見つかったらループを抜ける
                }
            }

            if !foundSchedule {
                // 特殊時程が見つからなかった場合
                print("今日の特殊時程は見つかりませんでした")
                // 必要に応じてユーザーに通知
            }
        }
    }

    // Main content extracted to reduce type-check complexity
    private var contentStackView: some View {
        VStack {
            PatternPickerView(selectedPattern: $selectedPattern, items: patternItems)

            if selectedDate != Date.distantPast {
                dateHeaderView
            }

            if isDatePickerVisible {
                datePickerView
            }

            timetableGridView

            Spacer()
        }
    }

    // シート表示のためのViewBuilder
    @ViewBuilder
    private func detailSheetContent() -> some View {
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
    
    // 追加シート表示のためのViewBuilder
    @ViewBuilder
    private func addSheetContent() -> some View {
        if let pattern = selectedPattern {
            TimetableDetailView(pattern: pattern)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    
    // アラート表示のためのViewBuilder
    private var calendarAlert: Alert {
        Alert(
            title: Text("カレンダーから時程を読み込みますか？"),
            message: Text("カレンダーから特殊時程の情報を読み込み、今日の表示に適用します。"),
            primaryButton: .default(Text("読み込む"), action: loadScheduleFromCalendar),
            secondaryButton: .cancel(Text("キャンセル"))
        )
    }

    // ナビゲーション関連のモディファイアをまとめて適用するメソッド
    private func applyNavigationModifiers<T: View>(to view: T) -> some View {
        view
            .navigationTitle("時間割")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: PatternSettingsView()) {
                        Label("時程設定", systemImage: "clock")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingAddSheet = true }) {
                            Label("コマを追加", systemImage: "plus")
                        }
                        NavigationLink(destination: TaskManagementView()) {
                            Label("課題管理", systemImage: "list.bullet.clipboard")
                        }
                        NavigationLink(destination: SpecialScheduleView(), isActive: $isSpecialScheduleActive) {
                            Label("特殊時程設定", systemImage: "calendar.badge.clock")
                        }
                        Button(action: loadScheduleFromCalendar) {
                            Label("カレンダーから時程を読み込む", systemImage: "arrow.clockwise.circle")
                        }
                    } label: {
                        Label("メニュー", systemImage: "ellipsis.circle")
                    }
                }
            }
    }

    // イベントハンドラ関連のモディファイアをまとめて適用するメソッド
    private func applyEventHandlerModifiers<T: View>(to view: T) -> some View {
        view
            .onAppear {
                loadDefaultPattern()
                selectedDate = Date()
                loadTimetableForDate(selectedDate)
            }
            .onChange(of: selectedPattern) { _, _ in
                updateWidgetData()
                saveSelectedPatternID()
            }
    }
    
    // シートとアラート関連のモディファイアをまとめて適用するメソッド
    private func applySheetAndAlertModifiers<T: View>(to view: T) -> some View {
        view
            .sheet(isPresented: $showingDetailSheet) {
                detailSheetContent()
            }
            .sheet(isPresented: $showingAddSheet) {
                addSheetContent()
            }
            .alert(isPresented: $showingCalendarAlert) {
                calendarAlert
            }
    }

    var body: some View {
        let navigationStack = NavigationStack {
            contentStackView
        }
        
        let viewWithNavigation = applyNavigationModifiers(to: navigationStack)
        let viewWithEvents = applyEventHandlerModifiers(to: viewWithNavigation)
        
        return applySheetAndAlertModifiers(to: viewWithEvents)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
