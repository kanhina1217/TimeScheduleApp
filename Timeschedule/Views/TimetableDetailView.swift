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
    @State private var existingTimetable: Timetable?
    
    // 新規作成時のデフォルト値
    let defaultDay: Int
    let defaultPeriod: Int
    let defaultPattern: Pattern  // UIの表示用に使用（時間表示など）
    
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
    init(timetable: Timetable?, day: Int, period: Int, pattern: Pattern) {
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
    init(pattern: Pattern, selectMode: Bool = true) {
        self.defaultDay = 0
        self.defaultPeriod = 1
        self.defaultPattern = pattern
        
        // 状態変数の初期化
        _existingTimetable = State(initialValue: nil)
        _selectMode = State(initialValue: selectMode)
        _selectedDay = State(initialValue: 0)
        _selectedPeriod = State(initialValue: 1)
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
        for period in 1...defaultPattern.periodCount {
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
        VStack {
            // 曜日選択ピッカー
            Picker("曜日", selection: $selectedDay) {
                ForEach(0..<daysOfWeek.count, id: \.self) { index in
                    Text(daysOfWeek[index]).tag(index)
                }
            }
            
            // 時限選択ピッカー
            Picker("時限", selection: $selectedPeriod) {
                let count = defaultPattern.periodCount
                ForEach(1...count, id: \.self) { period in
                    Text("\(period)限").tag(period)
                }
            }
            
            // 時間帯表示
            timeInfoView()
            
            // このコマを選択するボタン
            Button("このコマを選択") {
                existingTimetable = fetchExistingTimetable()
                selectMode = false
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.blue)
            
            // 複数選択モード切替ボタン
            Button("複数のコマを選択する") {
                isMultiSelectionMode = true
                // 選択状態をリセット
                daySelections = Array(repeating: false, count: 7)
                periodSelections = Array(repeating: false, count: 10)
                selectedCells = []
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.blue)
        }
    }
    
    // 時間帯表示ビュー
    private func timeInfoView() -> some View {
        HStack {
            Text("時間帯")
            Spacer()
            VStack(alignment: .trailing) {
                // 時間表示
                let startTime = defaultPattern.startTimeForPeriod(selectedPeriod)
                let endTime = defaultPattern.endTimeForPeriod(selectedPeriod)
                let timeText = "\(startTime)〜\(endTime)"
                
                Text(timeText)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // パターン名表示
                let patternText = "※時程パターン「\(defaultPattern.displayName)」の場合"
                Text(patternText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 複数選択モードのビュー
    private func multiSelectionView() -> some View {
        VStack {
            Text("複数のコマをタップして選択")
                .font(.headline)
                .padding(.bottom, 8)
            
            // 時間割グリッドを表示
            timetableGridView()
                .padding()
            
            // 選択されたコマの表示
            selectedCellsView()
            
            // 操作ボタン
            HStack {
                // キャンセルボタン
                Button("キャンセル") {
                    isMultiSelectionMode = false
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.red)
                
                // 選択完了ボタン
                Button("選択完了") {
                    if !selectedCells.isEmpty {
                        // 最初のセルを基準にして編集モードに遷移
                        let firstCell = selectedCells.first!
                        selectedDay = firstCell.day
                        selectedPeriod = firstCell.period
                        existingTimetable = fetchExistingTimetable(day: firstCell.day, period: firstCell.period)
                        selectMode = false
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.blue)
                .disabled(selectedCells.isEmpty)
            }
        }
    }
    
    // 時間割グリッドビュー
    private func timetableGridView() -> some View {
        VStack(spacing: 10) {
            // 曜日ヘッダー行
            HStack {
                Text("") // 左上の空白セル
                    .frame(width: 40)
                
                ForEach(0..<daysOfWeek.count, id: \.self) { day in
                    Text(daysOfWeek[day])
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 時限行
            ForEach(1...defaultPattern.periodCount, id: \.self) { period in
                HStack {
                    // 時限番号
                    Text("\(period)")
                        .font(.headline)
                        .frame(width: 40)
                    
                    // 曜日ごとのセル
                    ForEach(0..<daysOfWeek.count, id: \.self) { day in
                        selectionCellView(day: day, period: period)
                    }
                }
            }
        }
    }
    
    // 選択されたコマ一覧表示
    private func selectedCellsView() -> some View {
        Group {
            if !selectedCells.isEmpty {
                VStack(alignment: .leading) {
                    Text("選択されたコマ： \(selectedCells.count)個")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
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
            } else {
                EmptyView()
            }
        }
    }
    
    // 選択セルの表示
    private func selectionCellView(day: Int, period: Int) -> some View {
        let isSelected = selectedCells.contains(CellPosition(day: day, period: period)) // 構造体で検索
        
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
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)
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
                        let startTime = defaultPattern.startTimeForPeriod(selectedPeriod)
                        let endTime = defaultPattern.endTimeForPeriod(selectedPeriod)
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
                            let day = Int(timetable.dayOfWeek)
                            let period = timetable.period
                            Text("\(daysOfWeek[day])\(period)限")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("現在の時間帯")
                        Spacer()
                        if let timetable = existingTimetable {
                            let period = Int(timetable.period)
                            let startTime = defaultPattern.startTimeForPeriod(period)
                            let endTime = defaultPattern.endTimeForPeriod(period)
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
    private func fetchExistingTimetable() -> Timetable? {
        return fetchExistingTimetable(day: selectedDay, period: selectedPeriod)
    }
    
    // 指定した日時のデータを取得
    private func fetchExistingTimetable(day: Int, period: Int) -> Timetable? {
        let request: NSFetchRequest<Timetable> = Timetable.fetchRequest()
        request.predicate = NSPredicate(format: "dayOfWeek == %d AND period == %d", 
                                    Int16(day), Int16(period))
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            print("時間割データの取得エラー: \(error)")
            return nil
        }
    }
    
    // 既存データの読み込み
    private func loadTimetableData() {
        if let timetable = existingTimetable {
            subjectName = timetable.subjectName ?? ""
            classroom = timetable.classroom ?? ""
            task = timetable.task ?? ""
            textbook = timetable.textbook ?? ""
            selectedColor = timetable.color ?? "blue"
        }
    }
    
    // 時間割データの保存
    private func saveTimetable() {
        withAnimation {
            // 新規作成または既存レコードの更新
            let timetable = existingTimetable ?? Timetable(context: viewContext)
            
            // 既存データがない場合のみIDと基本情報を設定
            if existingTimetable == nil {
                timetable.id = UUID()
                timetable.dayOfWeek = Int16(selectedDay)
                timetable.period = Int16(selectedPeriod)
            }
            
            // 共通の更新処理
            timetable.subjectName = subjectName
            timetable.classroom = classroom
            timetable.task = task
            timetable.textbook = textbook
            timetable.color = selectedColor
            
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
                let timetable = existingTimetable ?? Timetable(context: viewContext)
                
                // 新規作成の場合は基本情報を設定
                if existingTimetable == nil {
                    timetable.id = UUID()
                    timetable.dayOfWeek = Int16(cell.day)
                    timetable.period = Int16(cell.period)
                }
                
                // 共通の更新処理
                timetable.subjectName = subjectName
                timetable.classroom = classroom
                timetable.task = task
                timetable.textbook = textbook
                timetable.color = selectedColor
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
        let pattern = Pattern(context: context)
        pattern.id = UUID()
        pattern.name = "通常"
        pattern.isDefault = true
        
        return TimetableDetailView(timetable: nil, day: 0, period: 1, pattern: pattern)
            .environment(\.managedObjectContext, context)
    }
}