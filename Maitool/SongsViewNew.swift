//
//  SongsViewNew.swift
//  Maitool
//
//  Created by Luminous on 2024/9/8.
//

import SwiftUI
import Combine

struct Song: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let type: String
    let ds: [Float]
    let level: [String]
    let basic_info: BasicInfo
    let charts: [Chart]

    struct BasicInfo: Codable, Hashable {
        let title: String
        let artist: String
        let genre: String
        let bpm: Int
        let from: String
        let is_new: Bool
    }

    struct Chart: Codable, Hashable {
        let notes: [Int]
        let charter: String
    }
}

struct SongsView: View {
    @State private var songs: [Song] = []
    @State private var searchText: String = ""
    @State private var filteredSongs: [Song] = []
    @State private var selectedSong: Song?
    private let apiURL = "https://www.diving-fish.com/api/maimaidxprober/music_data"
    @State private var aliasMapping: [String: [Int]] = [:]
    @State private var searchDebounceTask: DispatchWorkItem?
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("PRiSM")
                    .resizable()
                    .edgesIgnoringSafeArea(.all)
                ScrollView {
                    VStack {
                        TextField("搜索歌曲", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .opacity(0.7)
                            .onChange(of: searchText) { newValue in
                                searchDebounceTask?.cancel()  // 取消前一个任务
                                let task = DispatchWorkItem {
                                    updateFilteredSongs()
                                }
                                searchDebounceTask = task
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)  // 0.5秒延迟
                            }

                        ScrollView {
                            LazyVStack(spacing: 16) {
                                Text("Ver.CN1.41-F")
                                    .foregroundColor(.gray)
                                    .padding(.top)

                                ForEach(filteredSongs) { song in
                                    SongRowView(song: song, getCoverID: get_cover_id)
                                        .onTapGesture {
                                            selectedSong = song
                                        }
                                }

                            }
                            .padding(.horizontal)
                        }
                        .background(Color(UIColor.systemGray6).opacity(0.5))
                        .padding(.horizontal)
                    }
                    .navigationTitle("歌曲列表")
                    .onAppear {
                        loadCachedSongs()
                        loadAliasMapping()
                    }
                    .refreshable {
                        refreshSongs()
                    }
                }
                .popover(item: $selectedSong) { song in
                    SongDetailView(song: song, getCoverID: get_cover_id,  aliasMapping: aliasMapping)
                }
            }
        }
    }

    func loadCachedSongs() {
        if let cachedSongs = UserDefaults.standard.object(forKey: "cachedSongs") as? Data {
            let decoder = JSONDecoder()
            if let decodedSongs = try? decoder.decode([Song].self, from: cachedSongs) {
                self.songs = decodedSongs.reversed()
                self.filteredSongs = decodedSongs.reversed() // 初始化过滤列表
            } else {
                loadSongs()
            }
        } else {
            loadSongs()
        }
    }

    func loadSongs() {
        guard let url = URL(string: apiURL) else { return }
        let request = URLRequest(url: url)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching data: \(String(describing: error))")
                return
            }

            do {
                let decoder = JSONDecoder()
                let songData = try decoder.decode([Song].self, from: data)
                DispatchQueue.main.async {
                    self.songs = songData.reversed()
                    self.filteredSongs = songData.reversed() // 更新过滤列表
                    self.saveSongsToCache(songData)
                }
            } catch {
                print("Error decoding data: \(error)")
            }
        }.resume()
    }
    
    func saveSongsToCache(_ songs: [Song]) {
        let encoder = JSONEncoder()
        if let encodedSongs = try? encoder.encode(songs) {
            UserDefaults.standard.set(encodedSongs, forKey: "cachedSongs")
        }
    }

    func refreshSongs() {
        loadSongs()
    }

//    func updateFilteredSongs() {
//        if searchText.isEmpty {
//            filteredSongs = songs
//        } else {
//            filteredSongs = songs.filter { song in
//                song.basic_info.title.localizedCaseInsensitiveContains(searchText) ||
//                song.basic_info.artist.localizedCaseInsensitiveContains(searchText)
//            }
//        }
//    }
    func loadAliasMapping() {
        if let path = Bundle.main.path(forResource: "alias", ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            let decoder = JSONDecoder()
            if let aliasDict = try? decoder.decode([String: [Int]].self, from: data) {
                aliasMapping = aliasDict
            } else {
                print("Failed to decode alias mapping.")
            }
        } else {
            print("Failed to locate alias.json file.")
        }
    }

    func updateFilteredSongs() {
        if searchText.isEmpty {
            filteredSongs = songs
            print("Search text is empty. Showing all songs.")
        } else {
            let matchedSongs = songs.filter { song in
                let isMatch = song.basic_info.title.localizedCaseInsensitiveContains(searchText) ||
                              song.basic_info.artist.localizedCaseInsensitiveContains(searchText) ||
                              song.id.localizedCaseInsensitiveContains(searchText)
                if isMatch {
                    print("Fuzzy match found for song: \(song.basic_info.title)")
                }
                return isMatch
            }
            if let songIds = aliasMapping[searchText.lowercased()] {
                print("Alias mapping found for '\(searchText)': \(songIds)")
                let aliasMatchedSongs = songs.filter { song in
                    let idInt = Int(song.id) ?? -1
                    let isAliasMatch = songIds.contains(idInt)
                    if isAliasMatch {
                        print("Alias match found for song: \(song.basic_info.title) with ID \(song.id)")
                    }
                    return isAliasMatch
                }
                filteredSongs = Array(Set(matchedSongs + aliasMatchedSongs))
                print("Combined matched songs: \(filteredSongs.map { $0.basic_info.title })")
            } else {
                print("No alias mapping found for '\(searchText)'.")
                filteredSongs = matchedSongs
            }
        }
    }

    func get_cover_id(mid: String) -> String {
        var id = Int(mid) ?? 0
        if id > 10000 && id <= 11000 {
            id -= 10000
        }
        return String(format: "%05d", id)
    }
}

struct SongRowView: View {
    let song: Song
    let getCoverID: (String) -> String
    @State private var localCover: UIImage? = nil
    
    private static let imageLoadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
    var body: some View {
        HStack {
            if let image = localCover {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(7)
                    .clipped()
            } else {
                ProgressView()
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading) {
                Text(song.basic_info.title)
                    .font(.headline)
                Image(song.type)
                    .resizable()
                    .frame(width: 50, height: 15)
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
        .onAppear {
            loadImage(for: song.id)
        }
    }
    
    func loadImage(for songId: String) {
        if localCover != nil { return }
        let songId = String(Int(songId)! % 100000)
        let loadOperation = ImageLoadOperation(songId: songId, getCoverID: getCoverID)
        loadOperation.completionBlock = {
            guard !loadOperation.isCancelled, let image = loadOperation.image else { return }
            DispatchQueue.main.async {
                self.localCover = image
            }
        }
        
        SongRowView.imageLoadQueue.addOperation(loadOperation)
    }
}

class ImageLoadOperation: Operation, @unchecked Sendable {
    let songId: String
    let getCoverID: (String) -> String
    var image: UIImage?
    
    init(songId: String, getCoverID: @escaping (String) -> String) {
        self.songId = songId
        self.getCoverID = getCoverID
    }
    
    override func main() {
        if isCancelled { return }
        
        let fileName = "\(getCoverID(songId)).png"
        
        if let imagePath = Bundle.main.path(forResource: fileName, ofType: nil),
           let loadedImage = UIImage(contentsOfFile: imagePath) {
            self.image = loadedImage
        } else if let defaultImagePath = Bundle.main.path(forResource: "00000", ofType: "png"),
                  let defaultImage = UIImage(contentsOfFile: defaultImagePath) {
            self.image = defaultImage
        }
    }
}

struct SongDetailView: View {
    let song: Song
    let getCoverID: (String) -> String
    let aliasMapping: [String: [Int]]
    
    func colorForLevel(diff: Int) -> Color {
        if song.id.count == 6 {
                return Color(red: 238/255, green: 121/255, blue: 248/255)
            }
        switch diff {
        case 0:
            return Color(red: 90/255, green: 184/255, blue: 101/255) // Basic
        case 1:
            return Color(red: 238/255, green: 160/255, blue: 72/255) // Advanced
        case 2:
            return Color(red: 227/255, green: 86/255, blue: 101/255) // Expert
        case 3:
            return Color(red: 147/255, green: 74/255, blue: 218/255) // Master
        case 4:
            return Color(red: 175/255, green: 107/255, blue: 240/255) // Re:Master
        default:
            return Color.black
        }
    }
    
    func diffName(for index: Int) -> String {
        if song.id.count == 6 {
                return "Utage"
            }
        switch index {
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
            return ""
        }
    }
    
    var body: some View {
        ZStack {
            if let localCover = loadImage(for: song.id) {
                Image(uiImage: localCover)
                    .resizable()
                    .edgesIgnoringSafeArea(.all)
                    .blur(radius: 70)
                    .overlay(
                                    LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.5), Color.clear]), startPoint: .top, endPoint: .bottom)
                                        .edgesIgnoringSafeArea(.all)  // 使用渐变遮罩，减少背景色对内容的影响
                                )
            }
            ScrollView {
                VStack(alignment: .center) {
                    if let localCover = loadImage(for: song.id) {
                        Image(uiImage: localCover)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)
                            .cornerRadius(10)
                            .padding()
                    } else {
                        ProgressView()
                            .frame(width: 100, height: 100)
                    }
                    Text(song.basic_info.title)
                        .font(.headline)
                    HStack {
                        Text("# \(song.id)")
                            .foregroundStyle(.secondary)
                        Image(song.type)
                            .resizable()
                            .frame(width: 50, height: 15)
                    }
                    let matchingAliases = aliasMapping.filter { $0.value.contains(Int(song.id) ?? -1) }.keys

                    if !matchingAliases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(matchingAliases.joined(separator: " / "))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        Text("暂无别名")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                                    Group {
                                        HStack {
                                            Text("作曲")
                                                .bold()
                                            Spacer()
                                            Text(song.basic_info.artist)
                                        }
                                        Divider()
                                        
                                        HStack {
                                            Text("BPM")
                                                .bold()
                                            Spacer()
                                            Text("\(song.basic_info.bpm)")
                                        }
                                        Divider()
                                        
                                        HStack {
                                            Text("版本")
                                                .bold()
                                            Spacer()
                                            Text(song.basic_info.from)
                                        }
                                        Divider()
                                        
                                        HStack {
                                            Text("流派")
                                                .bold()
                                            Spacer()
                                            Text(song.basic_info.genre)
                                        }
                                    }
                                }
                                .padding()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView(.horizontal) {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("难度")
                                        .font(.headline)
                                        .frame(width: 120, alignment: .leading)
                                    Spacer()
                                    Text("定数")
                                        .font(.headline)
                                        .frame(width: 50, alignment: .leading)
                                    Spacer()
                                    Text("制谱")
                                        .font(.headline)
                                        .frame(width: 100, alignment: .leading)
                                    Spacer()
                                    Text("TAP")
                                        .font(.headline)
                                        .frame(width: 70, alignment: .leading)
                                    Spacer()
                                    Text("HOLD")
                                        .font(.headline)
                                        .frame(width: 70, alignment: .leading)
                                    Spacer()
                                    Text("SLIDE")
                                        .font(.headline)
                                        .frame(width: 70, alignment: .leading)
                                    Spacer()
                                    Text("TOUCH")
                                        .font(.headline)
                                        .frame(width: 70, alignment: .leading)
                                    Spacer()
                                    Text("BREAK")
                                        .font(.headline)
                                        .frame(width: 70, alignment: .leading)
                                }
                                .padding(.bottom, 4)
                            ForEach(0..<song.level.count, id: \.self) { index in
                                let levelName = song.level[index]
                                let dsValue = song.ds[index]
                                let diff = diffName(for: index)
                                let chart = song.charts[index]
                                let notes = chart.notes.prefix(5).map { $0 == 0 ? "-" : "\($0)" }

                                    HStack {
                                        Text("\(diff) \(levelName)")
                                            .font(.subheadline)
                                            .padding(6)
                                            .background(colorForLevel(diff: index))
                                            .cornerRadius(8)
                                            .foregroundColor(.white)
                                            .frame(width: 120, alignment: .leading)
                                        
                                        Text(String(format: "%.1f", dsValue))
                                            .font(.subheadline)
                                            .foregroundColor(colorForLevel(diff: index))
                                            .frame(width: 50, alignment: .leading)
                                        
                                        Text(chart.charter)
                                            .font(.subheadline)
                                            .frame(width: 100, alignment: .leading)
                                        if notes.count == 5 {
                                            Text(notes[0]) // TAP
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                            Spacer()
                                            Text(notes[1]) // HOLD
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                            Spacer()
                                            Text(notes[2]) // SLIDE
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                            Spacer()
                                            Text(notes[3]) // TOUCH
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                            Spacer()
                                            Text(notes[4]) // BREAK
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                        }
                                        else {
                                            Text(notes[0]) // TAP
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                            Spacer()
                                            Text(notes[1]) // HOLD
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                            Spacer()
                                            Text(notes[2]) // SLIDE
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                            Spacer()
                                            Text("-")
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                            Spacer()
                                            Text(notes[3]) // BREAK
                                                .font(.subheadline)
                                                .frame(width: 70, alignment: .leading)
                                        }
                                    }
                                }
                                Divider()
                            }
                        }
                    }
                    .padding()
                    
                    Button(action: {
                                    wakeUpBilibiliAndSearch(keyword: song.basic_info.title)
                                }) {
                                    Image("BiliBili")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                    Text("在 Bilibili 查看")
                                }
                    
                }
                .padding()
                .navigationTitle(song.basic_info.title)
            }
        }
    }
    
    func wakeUpBilibiliAndSearch(keyword: String) {
            let bilibiliAppURL = URL(string: "bilibili://search/?context=new_search&keyword=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            let bilibiliWebURL = URL(string: "https://www.bilibili.com/search?keyword=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            
            if UIApplication.shared.canOpenURL(bilibiliAppURL) {
                UIApplication.shared.open(bilibiliAppURL, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.open(bilibiliWebURL, options: [:], completionHandler: nil)
            }
        }

    func loadImage(for songId: String) -> UIImage? {
        let songId=String(Int(songId)! % 100000)
        let fileName = "\(getCoverID(songId)).png"
        if let imagePath = Bundle.main.path(forResource: fileName, ofType: nil),
           let image = UIImage(contentsOfFile: imagePath) {
            return image
        }
        if let defaultImagePath = Bundle.main.path(forResource: "00000", ofType: "png"),
           let defaultImage = UIImage(contentsOfFile: defaultImagePath) {
            return defaultImage
        }
        
        return nil
    }

}

struct SongsView_Previews: PreviewProvider {
    static var previews: some View {
        SongsView()
    }
}
