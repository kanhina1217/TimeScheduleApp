import SwiftUI
import CoreData

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
    @State private var selectedCells: [(day: Int, period: Int)] = []
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
                    // コマ選択モード
                    Form {
                        Section(header: Text("コマを選択")) {
                            if !isMultiSelectionMode {
                                // 単一選択モード
                                Picker("曜日", selection: $selectedDay) {
                                    ForEach(0..<daysOfWeek.count, id: \.self) { index in
                                        Text(daysOfWeek[index]).tag(index)
                                    }
                                }
                                
                                Picker("時限", selection: $selectedPeriod) {
                                    ForEach(1...defaultPattern.periodCount, id: \.self) { period in
                                        Text("\(period)限").tag(period)
                                    }
                                }
                                
                                // 現在のパターンの時間情報を表示
                                HStack {
                                    Text("時間帯")
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("\(defaultPattern.startTimeForPeriod(selectedPeriod))〜\(defaultPattern.endTimeForPeriod(selectedPeriod))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("※時程パターン「\(defaultPattern.displayName)」の場合")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Button("このコマを選択") {
                                    // コマが選択されたので入力モードに切り替え
                                    existingTimetable = fetchExistingTimetable()
                                    selectMode = false
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.blue)
                                
                                // 複数選択モードに切り替えるボタン
                                Button("複数のコマを選択する") {
                                    isMultiSelectionMode = true
                                    // 選択状態をリセット
                                    daySelections = Array(repeating: false, count: 7)
                                    periodSelections = Array(repeating: false, count: 10)
                                    selectedCells = []
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.blue)
                            } else {
                                // 複数選択モード
                                Text("複数のコマを選択できます")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                // 曜日選択
                                VStack(alignment: .leading) {
                                    Text("曜日を選択")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(0..<daysOfWeek.count) { day in
                                                Button(action: {
                                                    daySelections[day].toggle()
                                                    updateSelectedCells()
                                                }) {
                                                    Text(daysOfWeek[day])
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(daySelections[day] ? Color.blue : Color.gray.opacity(0.2))
                                                        .foregroundColor(daySelections[day] ? .white : .primary)
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                
                                // 時限選択
                                VStack(alignment: .leading) {
                                    Text("時限を選択")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(1...defaultPattern.periodCount, id: \.self) { period in
                                                Button(action: {
                                                    periodSelections[period-1].toggle()
                                                    updateSelectedCells()
                                                }) {
                                                    Text("\(period)限")
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(periodSelections[period-1] ? Color.blue : Color.gray.opacity(0.2))
                                                        .foregroundColor(periodSelections[period-1] ? .white : .primary)
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                
                                // 選択されたコマの表示
                                if !selectedCells.isEmpty {
                                    VStack(alignment: .leading) {
                                        Text("選択されたコマ")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        ScrollView {
                                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                                ForEach(selectedCells, id: \.0) { cell in
                                                    HStack {
                                                        Text("\(daysOfWeek[cell.day])\(cell.period)限")
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(Color.blue.opacity(0.1))
                                                            .cornerRadius(4)
                                                    }
                                                }
                                            }
                                        }
                                        .frame(height: 100)
                                    }
                                }
                                
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
                    }
                    .navigationTitle("時間割の追加")
                } else {
                    // 時間割データ入力モード
                    Form {
                        // 基本情報セクション
                        Section(header: Text("基本情報")) {
                            if selectedCells.isEmpty {
                                // 単一コマ選択時の表示
                                if existingTimetable == nil {
                                    // 新規作成時はコマ情報を表示
                                    HStack {
                                        Text("コマ")
                                        Spacer()
                                        Text("\(daysOfWeek[selectedDay])\(selectedPeriod)限")
                                            .foregroundColor(.gray)
                                    }
                                    // 選択されたパターンでの時間帯を表示（情報提供のみ）
                                    HStack {
                                        Text("現在の時間帯")
                                        Spacer()
                                        Text("\(defaultPattern.startTimeForPeriod(selectedPeriod))〜\(defaultPattern.endTimeForPeriod(selectedPeriod))")
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    // 既存データの場合も時間帯を表示
                                    HStack {
                                        Text("コマ")
                                        Spacer()
                                        Text("\(daysOfWeek[Int(existingTimetable!.dayOfWeek)])\(existingTimetable!.period)限")
                                            .foregroundColor(.gray)
                                    }
                                    // 選択されたパターンでの時間帯を表示（情報提供のみ）
                                    HStack {
                                        Text("現在の時間帯")
                                        Spacer()
                                        Text("\(defaultPattern.startTimeForPeriod(Int(existingTimetable!.period)))〜\(defaultPattern.endTimeForPeriod(Int(existingTimetable!.period)))")
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else {
                                // 複数コマ選択時の表示
                                Text("複数のコマに一括登録（\(selectedCells.count)コマ）")
                                    .foregroundColor(.blue)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(selectedCells, id: \.0) { cell in
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
                        if existingTimetable != nil && selectedCells.isEmpty {
                            Section {
                                Button(action: deleteTimetable) {
                                    Text("削除")
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                        }
                    }
                    .navigationTitle(existingTimetable != nil && selectedCells.isEmpty ? "時間割の編集" : "時間割の追加")
                }
            }
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: !selectMode ? Button("保存") {
                    if !selectedCells.isEmpty {
                        // 複数コマの一括登録
                        saveMultipleTimetables()
                    } else {
                        // 単一コマの保存
                        saveTimetable()
                    }
                } : nil
            )
            .onAppear {
                loadTimetableData()
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
    
    // 複数選択の状態を更新
    private func updateSelectedCells() {
        selectedCells = []
        
        // 選択された曜日と時限の組み合わせをすべて生成
        for day in 0..<daySelections.count {
            if daySelections[day] {
                for period in 0..<periodSelections.count {
                    if periodSelections[period] && period < defaultPattern.periodCount {
                        selectedCells.append((day: day, period: period + 1))
                    }
                }
            }
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