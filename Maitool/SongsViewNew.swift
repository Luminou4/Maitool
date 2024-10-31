//
//  SongsViewNew.swift
//  Maitool
//
//  Created by Luminous on 2024/9/8.
//

import SwiftUI

struct Song: Identifiable, Codable {
    let id: String
    let title: String
    let type: String
    let ds: [Float]
    let level: [String]
    let basic_info: BasicInfo
    let charts: [Chart]

    struct BasicInfo: Codable {
        let title: String
        let artist: String
        let genre: String
        let bpm: Int
        let from: String
        let is_new: Bool
    }

    struct Chart: Codable {
        let notes: [Int]
        let charter: String
    }
}

struct SongsView: View {
    @State private var songs: [Song] = []
    @State private var searchText: String = ""
    @State private var isRefreshing: Bool = false
    @State private var selectedSong: Song?
    private let apiURL = "https://www.diving-fish.com/api/maimaidxprober/music_data"

    var filteredSongs: [Song] {
        if searchText.isEmpty {
            return songs
        } else {
            return searchSongs(query: searchText)
        }
    }

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
                            //.background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .opacity(0.7)

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
                    }
                    .refreshable {
                        refreshSongs()
                    }
                }
                .popover(item: $selectedSong) { song in
                    SongDetailView(song: song, getCoverID: get_cover_id)
                }
            }
        }
    }

    func loadCachedSongs() {
        if let cachedSongs = UserDefaults.standard.object(forKey: "cachedSongs") as? Data {
            let decoder = JSONDecoder()
            if let decodedSongs = try? decoder.decode([Song].self, from: cachedSongs) {
                self.songs = decodedSongs.reversed()
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

    func searchSongs(query: String) -> [Song] {
        return songs.filter { song in
            song.basic_info.title.localizedCaseInsensitiveContains(query) ||
            song.basic_info.artist.localizedCaseInsensitiveContains(query)
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
        let songId=String(Int(songId)! % 100000)
        DispatchQueue.global(qos: .background).async {
            let fileName = "\(getCoverID(songId)).png"
            if let imagePath = Bundle.main.path(forResource: fileName, ofType: nil),
               let image = UIImage(contentsOfFile: imagePath) {
                DispatchQueue.main.async {
                    self.localCover = image
                }
            } else if let defaultImagePath = Bundle.main.path(forResource: "00000", ofType: "png"),
                      let defaultImage = UIImage(contentsOfFile: defaultImagePath) {
                DispatchQueue.main.async {
                    self.localCover = defaultImage
                }
            }
        }
    }
}

struct SongDetailView: View {
    let song: Song
    let getCoverID: (String) -> String
    
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
            return "？？？"
        }
    }
    
    var body: some View {
        ZStack {
            Image("PRiSM")
                .resizable()
                .edgesIgnoringSafeArea(.all)
                .blur(radius: 50)
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
                    HStack {
                        Text(song.basic_info.title)
                            .font(.headline)
                        Image(song.type)
                            .resizable()
                            .frame(width: 50, height: 15)
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
                                    Text("铺师")
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
