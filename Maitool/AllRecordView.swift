//
//  AllRecordView.swift
//  Maitool
//
//  Created by Luminous on 2024/9/16.
//

import SwiftUI

struct SongRecord: Codable {
    let achievements: Double
    let ds: Double
    let dxScore: Int
    let fc: String
    let fs: String
    let level: String
    let levelIndex: Int
    let levelLabel: String
    let ra: Int
    let rate: String
    let songId: Int
    let title: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case achievements
        case ds
        case dxScore = "dxScore"
        case fc
        case fs
        case level
        case levelIndex = "level_index"
        case levelLabel = "level_label"
        case ra
        case rate
        case songId = "song_id"
        case title
        case type
    }
}

struct AllRecordsResponse: Codable {
    let additionalRating: Int
    let nickname: String
    let plate: String
    let rating: Int
    let records: [SongRecord]

    enum CodingKeys: String, CodingKey {
        case additionalRating = "additional_rating"
        case nickname
        case plate
        case rating
        case records
    }
}

struct AllRecordView: View {
    @State private var allRecords: [SongRecord] = []
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var selectedSortOption = "定数 (ds)"
    
    let sortOptions = ["定数 (ds)", "达成率 (achievements)", "Rating (ra)"]
    @EnvironmentObject var userManager: UserManager

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("正在加载数据...")
                    .padding()
            } else if let errorMessage = errorMessage {
                Text("错误: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                VStack(alignment: .leading) {
                    Picker("排序方式", selection: $selectedSortOption) {
                        ForEach(sortOptions, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(sortedRecords(), id: \.songId) { record in
                                SongRecordView(songRecord: record)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .background(Color(UIColor.systemGray6))
                }
                .navigationTitle("全部歌曲成绩")
                .navigationBarTitleDisplayMode(.inline)  // 改为小标题
            }
        }
        .onAppear(perform: fetchAllRecords)
    }

    func sortedRecords() -> [SongRecord] {
        switch selectedSortOption {
        case "定数 (ds)":
            return allRecords.sorted { $0.ds > $1.ds }
        case "达成率 (achievements)":
            return allRecords.sorted { $0.achievements > $1.achievements }
        case "Rating (ra)":
            return allRecords.sorted { $0.ra > $1.ra }
        default:
            return allRecords
        }
    }

    func fetchAllRecords() {
        guard let token = UserDefaults.standard.string(forKey: "jwt_token") else {
            self.errorMessage = "未登录"
            return
        }

        guard let url = URL(string: "https://www.diving-fish.com/api/maimaidxprober/player/records") else {
            self.errorMessage = "无效的URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.errorMessage = "请求失败: \(error?.localizedDescription ?? "未知错误")"
                    self.isLoading = false
                }
                return
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("Received JSON: \(jsonString)")
            }

            do {
                let decodedResponse = try JSONDecoder().decode(AllRecordsResponse.self, from: data)
                DispatchQueue.main.async {
                    self.allRecords = decodedResponse.records
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "解析数据失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }.resume()
    }
}

struct SongRecordView: View {
    let songRecord: SongRecord

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(songRecord.title)
                        .font(.headline)

                    HStack {
                        Text("\(songRecord.levelLabel)")
                            .foregroundColor(colorForLevel(diff: songRecord.levelIndex))
                        Text("\(String(format: "%.1f", songRecord.ds))")
                        Spacer()
                        Text("\(String(format: "%.4f%%", songRecord.achievements))")
                    }
                    
                    HStack {
                        Text("Rating: \(songRecord.ra)")
                        Spacer()
                        Text("DX Score: \(songRecord.dxScore)")
                    }
                    
                    HStack {
                        Text("\(songRecord.fc)      ")
                        Text("\(songRecord.fs)")
                    }
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
        .padding(.vertical, 5)
    }
}

struct AllRecordPreviews: PreviewProvider {
    static var previews: some View {
        AllRecordView()
    }
}
