//
//  ContentView.swift
//  Timeschedule
//
//  Created by Kyoko Hobo on 2025/04/17.
//

import SwiftUI
import EventKit
import CoreData

struct WelcomeView: View {
    @State private var showingContinueAlert = false
    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var calendarAccessGranted = false
    @State private var selectedPattern: NSManagedObject? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.clock")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .font(.system(size: 50))
                    .padding(.bottom, 10)
                
                Text("時間スケジュールアプリ")
                    .font(.title)
                    .fontWeight(.bold)
                
                if isProcessing {
                    ProgressView(processingMessage)
                        .padding()
                } else {
                    VStack(spacing: 15) {
                        Button(action: {
                            requestCalendarAccess()
                        }) {
                            HStack {
                                Image(systemName: "calendar")
                                Text("カレンダーへのアクセスを許可")
                            }
                            .frame(minWidth: 200)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(calendarAccessGranted)
                        .opacity(calendarAccessGranted ? 0.5 : 1)
                        
                        Button(action: {
                            showingContinueAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("反復処理を開始")
                            }
                            .frame(minWidth: 200)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!calendarAccessGranted)
                        
                        // デフォルトのパターンを取得して渡す
                        NavigationLink(destination: {
                            if let pattern = selectedPattern {
                                TimetableDetailView(pattern: pattern)
                            } else {
                                Text("パターンを読み込み中...")
                                    .onAppear {
                                        loadDefaultPattern()
                                    }
                            }
                        }) {
                            HStack {
                                Image(systemName: "list.bullet.clipboard")
                                Text("時程表を確認")
                            }
                            .frame(minWidth: 200)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
            .onAppear {
                checkCalendarAuthorizationStatus()
                loadDefaultPattern()
            }
            .alert("反復処理を続行しますか?", isPresented: $showingContinueAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("続行") {
                    startRecurringProcess()
                }
            } message: {
                Text("カレンダーのチェックと時程パターンの適用を行います。この処理には時間がかかる場合があります。")
            }
        }
    }
    
    // デフォルトのパターンを読み込む
    private func loadDefaultPattern() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Pattern")
        fetchRequest.predicate = NSPredicate(format: "isDefault == YES")
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let pattern = results.first {
                selectedPattern = pattern
            } else {
                // デフォルトパターンがない場合は新規作成する処理を実装
                print("デフォルトパターンが見つかりません")
            }
        } catch {
            print("パターンの読み込みに失敗: \(error)")
        }
    }
    
    // カレンダー認証状態の確認
    private func checkCalendarAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        calendarAccessGranted = (status == .authorized || status == .fullAccess)
    }
    
    // カレンダーアクセスのリクエスト
    private func requestCalendarAccess() {
        isProcessing = true
        processingMessage = "カレンダーアクセスをリクエスト中..."
        
        // 引数名を指定せずにトレーリングクロージャを使用
        CalendarManager.shared.requestAccess { granted, error in
            isProcessing = false
            
            if granted {
                calendarAccessGranted = true
                processingMessage = ""
            } else {
                if let error = error {
                    processingMessage = "エラー: \(error.localizedDescription)"
                } else {
                    processingMessage = "カレンダーへのアクセスが拒否されました。"
                }
            }
        }
    }
    
    // 反復処理の開始
    private func startRecurringProcess() {
        isProcessing = true
        processingMessage = "処理を実行中..."
        
        // 現在日付の取得
        let today = Date()
        
        // カレンダーからその日のイベントを取得
        // コールバック形式に変更
        CalendarManager.shared.fetchEvents(for: today) { events, error in
            if let error = error {
                self.isProcessing = false
                self.processingMessage = "エラー: \(error.localizedDescription)"
                return
            }
            
            guard let events = events else {
                self.isProcessing = false
                self.processingMessage = "イベントの取得に失敗しました"
                return
            }
            
            // 時程パターンを示すイベントを探す
            var schedulePattern: String? = nil
            
            for event in events {
                if CalendarManager.shared.isScheduleEvent(event),
                   let pattern = CalendarManager.shared.extractSchedulePattern(from: event) {
                    schedulePattern = pattern
                    break
                }
            }
            
            // 時程パターンに基づいて処理
            if let pattern = schedulePattern {
                self.processingMessage = "時程パターン「\(pattern)」を適用中..."
                // ここで実際の時程パターン適用処理を実装
                // 例: applySchedulePattern(pattern)
                
                // 処理完了（実際の実装ではこの部分に時程パターン適用のロジックを入れる）
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.isProcessing = false
                    self.processingMessage = ""
                }
            } else {
                self.processingMessage = "デフォルトの時程を適用中..."
                
                // 処理完了（実際の実装ではこの部分にデフォルトパターン適用のロジックを入れる）
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.isProcessing = false
                    self.processingMessage = ""
                }
            }
        }
    }
}

struct CalendarOverviewView: View {
    var body: some View {
        Text("カレンダー画面")
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            WelcomeView()
                .tabItem {
                    Label("時間割", systemImage: "calendar")
                }

            CalendarOverviewView()
                .tabItem {
                    Label("カレンダー", systemImage: "calendar.badge.clock")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
