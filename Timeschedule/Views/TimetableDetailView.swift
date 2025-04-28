import SwiftUI
import CoreData

// 時間割のコマ位置を表す構造体 (Hashableに準拠)
struct CellPosition: Hashable {
    let day: Int
    let period: Int
    
    init(day: Int, period: Int) {
        self.day = day
        self.period = period
    }
}

struct TimetableDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    // 現在の時間割データ（編集時に使用）
    @State private var existingTimetable: NSManagedObject?
    
    // 新規作成時のデフォルト値
    let defaultDay: Int
    let defaultPeriod: Int
    let defaultPattern: NSManagedObject  // UIの表示用に使用（時間表示など）
    
    // 選択モード（コマを選択する場合trueに）
    @State private var selectMode: Bool
    
    // 編集用の状態変数
    @State private var subjectName: String = ""
    @State private var classroom: String = ""
    @State private var task: String = ""
    @State private var textbook: String = ""
    @State private var selectedColor: String = "blue"
    
    // コマ選択用の状態変数
    @State private var selectedDay: Int
    @State private var selectedPeriod: Int
    
    // 複数選択機能用の状態変数
    @State private var isMultiSelectionMode: Bool = false
    @State private var selectedCells: [CellPosition] = [] // タプルから構造体配列に変更
    @State private var daySelections: [Bool] = Array(repeating: false, count: 7) // 曜日選択状態
    @State private var periodSelections: [Bool] = Array(repeating: false, count: 10) // 時限選択状態（最大10）
    
    // 曜日と時限
    private let daysOfWeek = ["月", "火", "水", "木", "金", "土", "日"]
    
    // 利用可能な色の配列
    private let availableColors = ["red", "blue", "green", "yellow", "purple", "gray"]
    
    // 初期化処理（既存の時間割編集用）
    init(timetable: NSManagedObject?, day: Int, period: Int, pattern: NSManagedObject) {
        self.defaultDay = day
        self.defaultPeriod = period
        self.defaultPattern = pattern
        
        // 状態変数の初期化
        _existingTimetable = State(initialValue: timetable)
        _selectMode = State(initialValue: false)
        _selectedDay = State(initialValue: day)
        _selectedPeriod = State(initialValue: period)
    }
    
    // 初期化処理（コマ選択モード用）
    init(pattern: NSManagedObject, selectMode: Bool = true) {
        self.defaultDay = 0
        self.defaultPeriod = 1
        self.defaultPattern = pattern
        
        // 状態変数の初期化
        _existingTimetable = State(initialValue: nil)
        _selectMode = State(initialValue: selectMode)
        _selectedDay = State(initialValue: 0)
        _selectedPeriod = State(initialValue: 1)
    }
    
    // Pattern型のプロパティにアクセスするためのプライベートメソッド
    private func getPatternPeriodCount(_ pattern: NSManagedObject) -> Int {
        guard let periodTimesData = pattern.value(forKey: "periodTimes") as? [[String: String]] else {
            return 6 // デフォルト値
        }
        return periodTimesData.count
    }
    
    private func getPatternStartTime(_ pattern: NSManagedObject, period: Int) -> String {
        guard let periodTimesData = pattern.value(forKey: "periodTimes") as? [[String: String]],
              period > 0, period <= periodTimesData.count else {
            return "--:--" // デフォルト値
        }
        return periodTimesData[period-1]["startTime"] ?? "--:--"
    }
    
    private func getPatternEndTime(_ pattern: NSManagedObject, period: Int) -> String {
        guard let periodTimesData = pattern.value(forKey: "periodTimes") as? [[String: String]],
              period > 0, period <= periodTimesData.count else {
            return "--:--" // デフォルト値
        }
        return periodTimesData[period-1]["endTime"] ?? "--:--"
    }
    
    private func getPatternDisplayName(_ pattern: NSManagedObject) -> String {
        return pattern.value(forKey: "name") as? String ?? "不明なパターン"
    }
    
    // Timetable型のプロパティにアクセスするためのプライベートメソッド
    private func getTimetableDayOfWeek(_ timetable: NSManagedObject) -> Int16 {
        return timetable.value(forKey: "dayOfWeek") as? Int16 ?? 0
    }
    
    private func getTimetablePeriod(_ timetable: NSManagedObject) -> Int16 {
        return timetable.value(forKey: "period") as? Int16 ?? 1
    }

    var body: some View {
        NavigationView {
            VStack {
                if selectMode {
                    selectionModeView()
                } else {
                    editModeView()
                }
            }
            .navigationBarItems(
                leading: cancelButton,
                trailing: saveButton
            )
            .onAppear {
                loadTimetableData()
            }
        }
    }
    
    // キャンセルボタン - 共通コンポーネント
    private var cancelButton: some View {
        Button("キャンセル") {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // 保存ボタン - 条件によって表示
    private var saveButton: some View {
        Group {
            if !selectMode {
                Button("保存") {
                    if !selectedCells.isEmpty {
                        // 複数コマの一括登録
                        saveMultipleTimetables()
                    } else {
                        // 単一コマの保存
                        saveTimetable()
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // セルの選択状態を切り替え
    private func toggleCellSelection(day: Int, period: Int) {
        let cell = CellPosition(day: day, period: period) // 構造体を使用
        
        if let index = selectedCells.firstIndex(of: cell) { // firstIndex(where:)の代わりにfirstIndex(of:)を使用
            // すでに選択されている場合は削除
            selectedCells.remove(at: index)
        } else {
            // 選択されていない場合は追加
            selectedCells.append(cell)
        }
        
        // 曜日と時限の選択状態も更新
        updateSelectionStates()
    }
    
    // 選択状態の更新（曜日と時限の選択状態を実際の選択に合わせる）
    private func updateSelectionStates() {
        // 曜日選択状態の更新
        for day in 0..<daySelections.count {
            daySelections[day] = selectedCells.contains { $0.day == day }
        }
        
        // 時限選択状態の更新
        for period in 1...getPatternPeriodCount(defaultPattern) {
            periodSelections[period-1] = selectedCells.contains { $0.period == period }
        }
    }
    
    // MARK: - 分割したサブビュー
    
    // 選択モードビュー
    private func selectionModeView() -> some View {
        Form {
            Section(header: Text("コマを選択")) {
                if !isMultiSelectionMode {
                    singleSelectionView()
                } else {
                    multiSelectionView()
                }
            }
        }
        .navigationTitle("時間割の追加")
    }
    
    // 単一選択モードのビュー
    private func singleSelectionView() -> some View {
        Group {
            // 曜日選択ピッカー
            Picker("曜日", selection: $selectedDay) {
                ForEach(0..<daysOfWeek.count, id: \.self) { index in
                    Text(daysOfWeek[index]).tag(index)
                }
            }
            
            // 時限選択ピッカー
            Picker("時限", selection: $selectedPeriod) {
                let count = getPatternPeriodCount(defaultPattern)
                ForEach(1...count, id: \.self) { period in
                    Text("\(period)限").tag(period)
                }
            }
            
            // 時間帯表示
            timeInfoView()
            
            // このコマを選択するボタン - 独立させる
            Button(action: {
                existingTimetable = fetchExistingTimetable()
                selectMode = false
            }) {
                Text("このコマを選択")
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle()) // タッチ領域を確保
            
            // 複数選択モード切替ボタン - 独立させる
            Button(action: {
                isMultiSelectionMode = true
                // 選択状態をリセット
                daySelections = Array(repeating: false, count: 7)
                periodSelections = Array(repeating: false, count: 10)
                selectedCells = []
            }) {
                Text("複数のコマを選択する")
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle()) // タッチ領域を確保
        }
    }
    
    // 時間帯表示ビュー
    private func timeInfoView() -> some View {
        HStack {
            Text("時間帯")
            Spacer()
            VStack(alignment: .trailing) {
                // 時間表示
                let startTime = getPatternStartTime(defaultPattern, period: selectedPeriod)
                let endTime = getPatternEndTime(defaultPattern, period: selectedPeriod)
                let timeText = "\(startTime)〜\(endTime)"
                
                Text(timeText)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // パターン名表示
                let patternText = "※時程パターン「\(getPatternDisplayName(defaultPattern))」の場合"
                Text(patternText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 複数選択モードのビュー
    private func multiSelectionView() -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("複数のコマをタップして選択")
                    .font(.headline)
                    .padding(.top, 8)
                
                // 時間割グリッドを表示
                timetableGridView()
                    .padding(.horizontal, 8)
                
                // 選択されたコマの表示
                selectedCellsView()
                    .padding(.horizontal, 8)
                
                Divider()
                
                // 操作ボタン
                HStack(spacing: 20) {
                    // キャンセルボタン
                    Button(action: {
                        isMultiSelectionMode = false
                    }) {
                        Text("キャンセル")
                            .padding()
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // 選択完了ボタン
                    Button(action: {
                        if !selectedCells.isEmpty {
                            // 最初のセルを基準にして編集モードに遷移
                            if let firstCell = selectedCells.first {
                                selectedDay = firstCell.day
                                selectedPeriod = firstCell.period
                                existingTimetable = fetchExistingTimetable(day: firstCell.day, period: firstCell.period)
                                selectMode = false
                            }
                        }
                    }) {
                        Text("選択完了")
                            .padding()
                            .foregroundColor(selectedCells.isEmpty ? .gray : .white)
                            .frame(maxWidth: .infinity)
                            .background(selectedCells.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(selectedCells.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    // 時間割グリッドビュー
    private func timetableGridView() -> some View {
        VStack(spacing: 8) {
            // 曜日ヘッダー行
            HStack(spacing: 4) {
                Text("")
                    .frame(width: 30)
                    .font(.caption)
                
                ForEach(0..<daysOfWeek.count, id: \.self) { day in
                    Text(daysOfWeek[day])
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 時限行
            ForEach(1...getPatternPeriodCount(defaultPattern), id: \.self) { period in
                HStack(spacing: 4) {
                    // 時限番号
                    Text("\(period)")
                        .font(.headline)
                        .frame(width: 30)
                    
                    // 曜日ごとのセル
                    ForEach(0..<daysOfWeek.count, id: \.self) { day in
                        selectionCellView(day: day, period: period)
                    }
                }
            }
        }
    }
    
    // 選択セルの表示
    private func selectionCellView(day: Int, period: Int) -> some View {
        let isSelected = selectedCells.contains(CellPosition(day: day, period: period))
        
        return Button(action: {
            // セルのタップ処理
            toggleCellSelection(day: day, period: period)
        }) {
            ZStack {
                // 背景
                Rectangle()
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.gray, lineWidth: isSelected ? 2 : 1)
                    )
                
                // チェックマーク（選択時のみ表示）
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(BorderlessButtonStyle()) // 重要：タップ領域を確保
    }
    
    // 選択されたコマ一覧表示
    private func selectedCellsView() -> some View {
        Group {
            if !selectedCells.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("選択されたコマ： \(selectedCells.count)個")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(selectedCells, id: \.self) { cell in
                                Text("\(daysOfWeek[cell.day])\(cell.period)限")
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 8)
            } else {
                Text("コマが選択されていません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
    
    // 編集モードビュー
    private func editModeView() -> some View {
        Form {
            // 基本情報セクション
            Section(header: Text("基本情報")) {
                basicInfoSection()
                
                TextField("教科名", text: $subjectName)
                TextField("教室", text: $classroom)
            }
            
            // 詳細情報セクション
            Section(header: Text("詳細情報")) {
                TextField("課題", text: $task)
                TextField("教科書", text: $textbook)
            }
            
            // 色選択セクション
            Section(header: Text("色")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                    ForEach(availableColors, id: \.self) { color in
                        colorCell(color)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // 科目関連の課題を表示するセクション（科目名が入力されている場合のみ表示）
            if !subjectName.isEmpty {
                Section(header: Text("この科目の課題")) {
                    NavigationLink(destination: 
                        TaskManagementView(filterSubject: subjectName)
                    ) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(.blue)
                            Text("\(subjectName)の課題を表示")
                        }
                    }
                    
                    NavigationLink(destination: 
                        TaskEditView(initialSubject: subjectName, initialColor: selectedColor)
                    ) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.green)
                            Text("\(subjectName)の課題を追加")
                        }
                    }
                }
            }
            
            // 削除ボタンセクション（既存データの場合のみ表示、複数選択時は非表示）
            deleteButtonSection()
        }
        .navigationTitle(getEditModeTitle())
    }
    
    // 編集モードのタイトルを取得
    private func getEditModeTitle() -> String {
        if existingTimetable != nil && selectedCells.isEmpty {
            return "時間割の編集"
        } else {
            return "時間割の追加"
        }
    }
    
    // 基本情報セクションの内容
    private func basicInfoSection() -> some View {
        Group {
            if selectedCells.isEmpty {
                singleCellInfoView()
            } else {
                multipleCellInfoView()
            }
        }
    }
    
    // 単一コマ選択時の情報表示
    private func singleCellInfoView() -> some View {
        Group {
            if existingTimetable == nil {
                // 新規作成時のコマ情報表示
                VStack {
                    HStack {
                        Text("コマ")
                        Spacer()
                        Text("\(daysOfWeek[selectedDay])\(selectedPeriod)限")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("現在の時間帯")
                        Spacer()
                        let startTime = getPatternStartTime(defaultPattern, period: selectedPeriod)
                        let endTime = getPatternEndTime(defaultPattern, period: selectedPeriod)
                        Text("\(startTime)〜\(endTime)")
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // 既存データの場合の情報表示
                VStack {
                    HStack {
                        Text("コマ")
                        Spacer()
                        if let timetable = existingTimetable {
                            let day = Int(getTimetableDayOfWeek(timetable))
                            let period = getTimetablePeriod(timetable)
                            Text("\(daysOfWeek[day])\(period)限")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("現在の時間帯")
                        Spacer()
                        if let timetable = existingTimetable {
                            let period = Int(getTimetablePeriod(timetable))
                            let startTime = getPatternStartTime(defaultPattern, period: period)
                            let endTime = getPatternEndTime(defaultPattern, period: period)
                            Text("\(startTime)〜\(endTime)")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }
    
    // 複数コマ選択時の情報表示
    private func multipleCellInfoView() -> some View {
        VStack {
            Text("複数のコマに一括登録（\(selectedCells.count)コマ）")
                .foregroundColor(.blue)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(selectedCells, id: \.self) { cell in
                        Text("\(daysOfWeek[cell.day])\(cell.period)限")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // 削除ボタンセクション
    private func deleteButtonSection() -> some View {
        Group {
            if existingTimetable != nil && selectedCells.isEmpty {
                Section {
                    Button(action: deleteTimetable) {
                        Text("削除")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    // 色選択セル
    private func colorCell(_ color: String) -> some View {
        let uiColor: Color = {
            switch color {
            case "red": return .red
            case "blue": return .blue
            case "green": return .green
            case "yellow": return .yellow
            case "purple": return .purple
            default: return .gray
            }
        }()
        
        return Circle()
            .fill(uiColor.opacity(0.7))
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
            )
            .onTapGesture {
                selectedColor = color
            }
    }
    
    // 既存のデータを取得（パターンに依存しない）
    private func fetchExistingTimetable() -> NSManagedObject? {
        return fetchExistingTimetable(day: selectedDay, period: selectedPeriod)
    }
    
    // 指定した日時のデータを取得
    private func fetchExistingTimetable(day: Int, period: Int) -> NSManagedObject? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Timetable")
        request.predicate = NSPredicate(format: "dayOfWeek == %d AND period == %d", 
                                    Int16(day), Int16(period))
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first as? NSManagedObject
        } catch {
            print("時間割データの取得エラー: \(error)")
            return nil
        }
    }
    
    // 既存データの読み込み
    private func loadTimetableData() {
        if let timetable = existingTimetable {
            subjectName = timetable.value(forKey: "subjectName") as? String ?? ""
            classroom = timetable.value(forKey: "classroom") as? String ?? ""
            task = timetable.value(forKey: "task") as? String ?? ""
            textbook = timetable.value(forKey: "textbook") as? String ?? ""
            selectedColor = timetable.value(forKey: "color") as? String ?? "blue"
        }
    }
    
    // 時間割データの保存
    private func saveTimetable() {
        withAnimation {
            // 新規作成または既存レコードの更新
            let timetable: NSManagedObject
            if let existing = existingTimetable {
                timetable = existing
            } else {
                let entity = NSEntityDescription.entity(forEntityName: "Timetable", in: viewContext)!
                timetable = NSManagedObject(entity: entity, insertInto: viewContext)
                timetable.setValue(UUID(), forKey: "id")
                timetable.setValue(Int16(selectedDay), forKey: "dayOfWeek")
                timetable.setValue(Int16(selectedPeriod), forKey: "period")
            }
            
            // 共通の更新処理
            timetable.setValue(subjectName, forKey: "subjectName")
            timetable.setValue(classroom, forKey: "classroom")
            timetable.setValue(task, forKey: "task")
            timetable.setValue(textbook, forKey: "textbook")
            timetable.setValue(selectedColor, forKey: "color")
            
            // 保存
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("時間割の保存エラー: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // 複数の時間割を一括保存
    private func saveMultipleTimetables() {
        withAnimation {
            for cell in selectedCells {
                // 既存データがあるか確認
                let existingTimetable = fetchExistingTimetable(day: cell.day, period: cell.period)
                
                let timetable: NSManagedObject
                if let existing = existingTimetable {
                    timetable = existing
                } else {
                    let entity = NSEntityDescription.entity(forEntityName: "Timetable", in: viewContext)!
                    timetable = NSManagedObject(entity: entity, insertInto: viewContext)
                    timetable.setValue(UUID(), forKey: "id")
                    timetable.setValue(Int16(cell.day), forKey: "dayOfWeek")
                    timetable.setValue(Int16(cell.period), forKey: "period")
                }
                
                // 共通の更新処理
                timetable.setValue(subjectName, forKey: "subjectName")
                timetable.setValue(classroom, forKey: "classroom")
                timetable.setValue(task, forKey: "task")
                timetable.setValue(textbook, forKey: "textbook")
                timetable.setValue(selectedColor, forKey: "color")
            }
            
            // 一括保存
            do {
                try viewContext.save()
                presentationMode.wrappedValue.dismiss()
            } catch {
                let nsError = error as NSError
                print("複数時間割の保存エラー: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // 時間割データの削除
    private func deleteTimetable() {
        withAnimation {
            if let timetable = existingTimetable {
                viewContext.delete(timetable)
                
                do {
                    try viewContext.save()
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    let nsError = error as NSError
                    print("時間割の削除エラー: \(nsError), \(nsError.userInfo)")
                }
            }
        }
    }
}

struct TimetableDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        // プレビュー用のPatternを作成
        let patternDesc = NSEntityDescription.entity(forEntityName: "Pattern", in: context)!
        let pattern = NSManagedObject(entity: patternDesc, insertInto: context)
        pattern.setValue(UUID(), forKey: "id")
        pattern.setValue("通常", forKey: "name")
        pattern.setValue(true, forKey: "isDefault")
        
        // 時限情報を設定
        let periodTimesData: [[String: String]] = [
            ["period": "1", "startTime": "8:30", "endTime": "9:20"],
            ["period": "2", "startTime": "9:30", "endTime": "10:20"],
            ["period": "3", "startTime": "10:40", "endTime": "11:30"],
            ["period": "4", "startTime": "11:40", "endTime": "12:30"],
            ["period": "5", "startTime": "13:20", "endTime": "14:10"],
            ["period": "6", "startTime": "14:20", "endTime": "15:10"]
        ]
        pattern.setValue(periodTimesData, forKey: "periodTimes")
        
        return TimetableDetailView(timetable: nil, day: 0, period: 1, pattern: pattern)
            .environment(\.managedObjectContext, context)
    }
}