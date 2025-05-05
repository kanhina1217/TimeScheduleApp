import SwiftUI
import CoreData
import EventKit

struct SpecialScheduleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    // パターンのFetchRequest
    @FetchRequest(
        entity: Pattern.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Pattern.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \Pattern.name, ascending: true)
        ],
        animation: .default)
    private var patterns: FetchedResults<Pattern>
    
    // 日付選択
    @State private var selectedDate = Date()
    
    // パターン選択
    @State private var selectedPatternName: String = "通常"
    
    // カスタム設定
    @State private var customMapping: String = ""
    
    // 処理状態
    @State private var isProcessing = false
    @State private var message = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // 適用済みの特殊時程
    @State private var appliedSchedules: [(date: String, patternName: String)] = []
    
    // 曜日の日本語表記
    private let dayNames = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        Form {
            // 日付選択セクション
            Section(header: Text("日付選択")) {
                DatePicker(
                    "日付",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                
                // 曜日表示
                let calendar = Calendar.current
                let weekday = calendar.component(.weekday, from: selectedDate) - 1
                Text("選択日: \(dayNames[weekday])曜日")
                    .foregroundColor(.secondary)
            }
            
            // パターン選択セクション
            Section(header: Text("時程パターン選択")) {
                Picker("パターン", selection: $selectedPatternName) {
                    Text("通常").tag("通常")
                    Text("短縮A時程").tag("短縮A時程")
                    Text("短縮B時程").tag("短縮B時程")
                    Text("短縮C時程").tag("短縮C時程")
                    Text("テスト時程").tag("テスト時程")
                    Text("カスタム").tag("カスタム")
                }
                .pickerStyle(MenuPickerStyle())
                
                if selectedPatternName == "カスタム" {
                    TextField("カスタム設定 (例: 月12345 → 月123金45)", text: $customMapping)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("書式: 元曜日+時限 → 先曜日+時限")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("例1: 月12345 → 月123水45 (月曜1-5限を月曜1-3限と水曜4-5限に配置)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("例2: 金12345 → 金1234 (金曜の5限を省略)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 適用済みの特殊時程リスト
            Section(header: Text("適用済みの特殊時程")) {
                if appliedSchedules.isEmpty {
                    Text("適用済みの特殊時程はありません")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(appliedSchedules, id: \.date) { schedule in
                            VStack(alignment: .leading) {
                                Text(schedule.date)
                                    .font(.headline)
                                Text(schedule.patternName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteSpecialSchedule)
                    }
                }
            }
            
            // 操作ボタン
            Section {
                Button(action: applySpecialSchedule) {
                    HStack {
                        Spacer()
                        Text("特殊時程を適用")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(isProcessing)
                
                if isProcessing {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text(message)
                            .padding(.leading, 10)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("特殊時程設定")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshSchedules) {
                    Label("更新", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            loadAppliedSchedules()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // 適用済みの特殊時程を読み込む
    private func loadAppliedSchedules() {
        // カレンダーから特殊時程の情報を取得
        let startDate = Date()
        let calendar = Calendar.current
        // 30日先までのイベントを取得
        guard let endDate = calendar.date(byAdding: .day, value: 30, to: startDate) else {
            return
        }
        
        let schedules = CalendarManager.shared.getSpecialSchedules(from: startDate, to: endDate)
        
        // 表示用に変換
        appliedSchedules = schedules.map { schedule in
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            dateFormatter.locale = Locale(identifier: "ja_JP")
            
            return (date: dateFormatter.string(from: schedule.date), patternName: schedule.patternName)
        }
    }
    
    // 特殊時程を削除
    private func deleteSpecialSchedule(at offsets: IndexSet) {
        guard !isProcessing else { return }
        
        isProcessing = true
        message = "特殊時程を削除中..."
        
        // 該当する日付の特殊時程を取得
        let calendar = Calendar.current
        let startDate = Date()
        guard let endDate = calendar.date(byAdding: .day, value: 30, to: startDate) else {
            isProcessing = false
            return
        }
        
        let schedules = CalendarManager.shared.getSpecialSchedules(from: startDate, to: endDate)
        
        // 削除対象のインデックスに該当するイベントを取得
        for offset in offsets {
            if offset < schedules.count {
                let scheduleToDelete = schedules[offset]
                
                // イベントを削除
                CalendarManager.shared.deleteScheduleEvent(scheduleToDelete.event) { success, error in
                    // 特殊時程のデータも削除
                    if success {
                        DispatchQueue.main.async {
                            deleteSpecialScheduleData(for: scheduleToDelete.date)
                            loadAppliedSchedules() // リストを更新
                            isProcessing = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            isProcessing = false
                            alertTitle = "エラー"
                            alertMessage = "特殊時程の削除に失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
                            showingAlert = true
                        }
                    }
                }
            }
        }
    }
    
    // 特殊時程のデータを削除
    private func deleteSpecialScheduleData(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SpecialSchedule")
        fetchRequest.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(batchDeleteRequest)
        } catch {
            print("特殊時程データの削除に失敗しました: \(error)")
        }
    }
    
    // 特殊時程を適用
    private func applySpecialSchedule() {
        isProcessing = true
        message = "特殊時程を適用中..."
        
        // カレンダーにイベントを追加
        CalendarManager.shared.createScheduleEvent(patternName: selectedPatternName, date: selectedDate) { success, error in
            if success {
                // 特殊時程パターンを適用
                DispatchQueue.main.async {
                    let applyResult = SpecialScheduleManager.shared.applySpecialSchedule(for: self.selectedDate, context: self.viewContext)
                    
                    if applyResult {
                        self.message = "特殊時程を適用しました"
                        self.loadAppliedSchedules() // リストを更新
                    } else {
                        self.alertTitle = "警告"
                        self.alertMessage = "特殊時程の適用処理は完了しましたが、一部の設定は適用されませんでした。"
                        self.showingAlert = true
                    }
                    
                    // 処理完了
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isProcessing = false
                        self.message = ""
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.alertTitle = "エラー"
                    self.alertMessage = "特殊時程の適用に失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
                    self.showingAlert = true
                }
            }
        }
    }
    
    // 特殊時程リストを更新
    private func refreshSchedules() {
        loadAppliedSchedules()
    }
}

struct SpecialScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SpecialScheduleView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}