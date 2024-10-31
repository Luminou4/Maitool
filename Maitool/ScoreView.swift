//
//  ScoreView.swift
//  Maitool
//
//  Created by Luminous on 2024/8/7.
//

import SwiftUI

struct ScoreView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var sdBestList: [ChartInfo] = UserDefaults.standard.loadBestList(forKey: "sdBestList", size: 35).allData
    @State private var dxBestList: [ChartInfo] = UserDefaults.standard.loadBestList(forKey: "dxBestList", size: 15).allData
    @State private var errorMessage: String?
    @State private var hasSearched: Bool = false
    @State private var showLoginSheet: Bool = false
    @State private var showModifiedResults: Bool = false

    var totalRating: Int {
        return sdBestList.reduce(0) { $0 + (showModifiedResults ? getModifiedRating($1) : $1.ra) } + dxBestList.reduce(0) { $0 + (showModifiedResults ? getModifiedRating($1) : $1.ra) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Image("PRiSM")
                    .resizable()
                    .edgesIgnoringSafeArea(.all)
                ScrollView {
                    VStack {
                        if userManager.username.isEmpty {
                            Text("请登录后再查询")
                                .foregroundColor(.red)
                                .padding()

                            Button("登录") {
                                showLoginSheet = true
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .sheet(isPresented: $showLoginSheet) {
                                LoginView()
                            }
                            .padding()
                        } else {
                            Button(action: {
                                hasSearched = true
                                generateBestLists(username: userManager.username) { sdBest, dxBest, error in
                                    DispatchQueue.main.async {
                                        if let error = error {
                                            errorMessage = error.localizedDescription
                                        } else {
                                            errorMessage = nil
                                            if let sdBest = sdBest {
                                                sdBestList = Array(sdBest.allData.prefix(35))
                                                UserDefaults.standard.saveBestList(sdBest, forKey: "sdBestList")
                                            }
                                            if let dxBest = dxBest {
                                                dxBestList = Array(dxBest.allData.prefix(15))
                                                UserDefaults.standard.saveBestList(dxBest, forKey: "dxBestList")
                                            }
                                        }
                                    }
                                }
                            }) {
                                Text("获取B50")
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .padding(.top)

                            if let errorMessage = errorMessage {
                                Text("Error: \(errorMessage)")
                                    .foregroundColor(.red)
                                    .padding()
                            }

                            // 显示查询结果
                            if hasSearched {
                                ScrollView {
                                    Text("")
                                    Text("Rating: \(totalRating)")
                                        .foregroundColor(.blue)
                                        .padding()

                                    VStack(alignment: .leading, spacing: 16) {
                                        SectionView(title: "旧版本B35", list: $sdBestList, showModified: $showModifiedResults)
                                        SectionView(title: "新版本B15", list: $dxBestList, showModified: $showModifiedResults)
                                        
                                        Button(showModifiedResults ? "恢复原始B50" : "看看我的B50有多水") {
                                            showModifiedResults.toggle()
                                        }
                                        .padding()
                                    }
                                    .padding(.horizontal)
                                }
                                .background(Color(UIColor.systemGray6).opacity(0.7))
                            }
                        }
                    }
                    .navigationTitle("查分")
                    .padding(.horizontal)
                    .toolbar {
                        if !userManager.username.isEmpty {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                NavigationLink(destination: AllRecordView()) {
                                    Text("所有成绩")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func getModifiedDS(for chartInfo: ChartInfo) -> Double {
        return fetchFitConstant(idNum: chartInfo.idNum, diff: chartInfo.lv) ?? chartInfo.ds
    }

    func getModifiedRating(_ chartInfo: ChartInfo) -> Int {
        return computeRa(ds: getModifiedDS(for: chartInfo), achievement: chartInfo.achievement)
    }
}

struct SectionView: View {
    var title: String
    @Binding var list: [ChartInfo]
    @Binding var showModified: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

            if list.isEmpty {
                Text("暂无成绩")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(list.indices, id: \.self) { index in
                        ChartInfoView(chartInfo: list[index], showModified: showModified)
                    }
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChartInfoView: View {
    let chartInfo: ChartInfo
    let showModified: Bool // 根据这个值来决定展示哪个 ds

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(chartInfo.title)
                        .font(.headline)
                    let modifiedDS = getModifiedDS()
                    HStack {
                        Text(levelText(from: chartInfo.diff))
                            .font(.custom("Kuzoka Gothic Pro", size: 16))
                            .foregroundColor(colorForLevel(diff: chartInfo.diff))
                        Text("\(String(format: "%.1f", showModified ? modifiedDS : chartInfo.ds))")
                            .font(.custom("Kuzoka Gothic Pro", size: 16))
                    }
                    
                    Text("Achievement: \(String(format: "%.4f%%", chartInfo.achievement))")
                        .font(.custom("Kuzoka Gothic Pro", size: 16))
                    Text("Rating: \(showModified ? computeRa(ds: modifiedDS ,achievement:chartInfo.achievement) : chartInfo.ra)")
                        .font(.custom("Kuzoka Gothic Pro", size: 16))
                }
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 2)
            )
        }
    }

    func getModifiedDS() -> Double {
        return fetchFitConstant(idNum: chartInfo.idNum, diff: chartInfo.lv) ?? chartInfo.ds
    }

    func levelText(from diff: Int) -> String {
        switch diff {
        case 0:
            return "Basic"
        case 1:
            return "Advanced"
        case 2:
            return "Expert"
        case 3:
            return "Master"
        case 4:
            return "Re:Master"
        default:
            return "Utage"
        }
    }
}

func colorForLevel(diff: Int) -> Color {
    switch diff {
    case 0:
        return Color(red: 90/255, green: 184/255, blue: 101/255)
    case 1:
        return Color(red: 238/255, green: 160/255, blue: 72/255)
    case 2:
        return Color(red: 227/255, green: 86/255, blue: 101/255)
    case 3:
        return Color(red: 147/255, green: 74/255, blue: 218/255)
    case 4:
        return Color(red: 175/255, green: 107/255, blue: 240/255)
    default:
        return Color.black
    }
}

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建 UserManager 实例
        let userManager = UserManager()
        // 注入 UserManager 环境对象
        ScoreView()
            .environmentObject(userManager)
    }
}
