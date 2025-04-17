import SwiftUI
import CoreData

struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // パターンのFetchRequest（デフォルトパターンが先に来るようにソート）
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Pattern.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \Pattern.name, ascending: true)
        ],
        animation: .default)
    private var patterns: FetchedResults<Pattern>
    
    // 選択された時程パターン
    @State private var selectedPattern: Pattern?
    // 科目追加/編集シートの表示フラグ
    @State private var showingSubjectSheet = false
    // 選択された曜日と時限（編集用）
    @State private var selectedDay = 0
    @State private var selectedPeriod = 0
    
    // 曜日の配列
    private let daysOfWeek = ["月", "火", "水", "木", "金", "土", "日"]
    // 時限数（設定画面で変更可能にする予定）
    private let periodCount = 6
    
    var body: some View {
        NavigationView {
            VStack {
                // 時程パターン選択
                if !patterns.isEmpty {
                    Picker("パターン", selection: $selectedPattern) {
                        ForEach(patterns, id: \.self) { pattern in
                            Text(pattern.name ?? "不明").tag(pattern as Pattern?)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .onChange(of: selectedPattern) { _ in
                        // パターン変更時の処理（必要に応じて実装）
                    }
                }
                
                // 時間割表示
                ScrollView {
                    VStack(spacing: 10) {
                        // 曜日ヘッダー行
                        HStack {
                            Text("") // 左上の空白セル
                                .frame(width: 40)
                            
                            ForEach(daysOfWeek.prefix(5), id: \.self) { day in
                                Text(day)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 時限行
                        ForEach(1...periodCount, id: \.self) { period in
                            HStack {
                                // 時限番号
                                Text("\(period)")
                                    .font(.headline)
                                    .frame(width: 40)
                                
                                // 曜日ごとのセル
                                ForEach(0..<5) { day in
                                    timetableCell(day: day, period: Int16(period))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("時間割")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 設定画面へ（後で実装）
                    }) {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 時間割追加/編集
                        showingSubjectSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                // デフォルトパターンの選択
                if selectedPattern == nil {
                    if let defaultPattern = patterns.first(where: { $0.isDefault }) {
                        selectedPattern = defaultPattern
                    } else {
                        selectedPattern = patterns.first
                    }
                }
            }
            .sheet(isPresented: $showingSubjectSheet) {
                // 時間割追加/編集シート（ここでは仮の実装）
                VStack {
                    Text("科目の追加/編集")
                        .font(.headline)
                    Text("選択: \(daysOfWeek[selectedDay])曜日 \(selectedPeriod+1)時限")
                    
                    Spacer()
                    
                    Button("閉じる") {
                        showingSubjectSheet = false
                    }
                    .padding()
                }
                .padding()
            }
        }
    }
    
    // 時間割のセルを生成
    private func timetableCell(day: Int, period: Int16) -> some View {
        // この曜日・時限の時間割データを取得
        let timetable = fetchTimetable(for: day, period: period)
        
        return Button(action: {
            // セルタップ時の処理
            selectedDay = day
            selectedPeriod = Int(period) - 1
            showingSubjectSheet = true
        }) {
            VStack {
                if let timetable = timetable {
                    // 時間割データがある場合
                    Text(timetable.subjectName ?? "")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(timetable.classroom ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(getCellColor(for: timetable))
            .cornerRadius(8)
        }
    }
    
    // 時間割データを取得
    private func fetchTimetable(for day: Int, period: Int16) -> Timetable? {
        guard let pattern = selectedPattern else { return nil }
        
        let request: NSFetchRequest<Timetable> = Timetable.fetchRequest()
        request.predicate = NSPredicate(format: "dayOfWeek == %d AND period == %d AND relationship == %@", 
                                     Int16(day), period, pattern)
        request.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            print("時間割データの取得エラー: \(error)")
            return nil
        }
    }
    
    // セルの背景色を取得
    private func getCellColor(for timetable: Timetable?) -> Color {
        guard let timetable = timetable, let colorName = timetable.color else {
            return Color(.systemGray6)  // データがない場合のデフォルト色
        }
        
        // 色名に基づいて色を返す
        switch colorName {
        case "red":
            return Color.red.opacity(0.3)
        case "blue":
            return Color.blue.opacity(0.3)
        case "green":
            return Color.green.opacity(0.3)
        case "yellow":
            return Color.yellow.opacity(0.3)
        case "purple":
            return Color.purple.opacity(0.3)
        default:
            return Color(.systemGray6)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
