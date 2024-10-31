//
//  generate50.swift
//  Maitool
//
//  Created by Luminous on 2024/7/2.
//

import Foundation

struct ChartInfo: Comparable, Codable {
    let idNum: Int
    let diff: Int
    let tp: String
    let achievement: Double
    let ra: Int
    let comboId: Int
    let scoreId: Int
    let title: String
    let ds: Double
    let lv: String

    static func from(json: [String: Any]) -> ChartInfo? {
        let rate = ["d", "c", "b", "bb", "bbb", "a", "aa", "aaa", "s", "sp", "ss", "ssp", "sss", "sssp"]
        let fc = ["", "fc", "fcp", "ap", "app"]
        
        guard let title = json["title"] as? String,
              let levelIndex = json["level_index"] as? Int,
              let ds = json["ds"] as? Double,
              let level = json["level"] as? String,
              let achievements = json["achievements"] as? Double,
              let type = json["type"] as? String,
              let rateStr = json["rate"] as? String,
              let fcStr = json["fc"] as? String,
              let idNum = json["song_id"] as? Int
        else {
            return nil
        }
        
        let ri = rate.firstIndex(of: rateStr) ?? 0
        let fi = fc.firstIndex(of: fcStr) ?? 0
        
        return ChartInfo(
            idNum: idNum,
            diff: levelIndex,
            tp: type,
            achievement: achievements,
            ra: computeRa(ds: ds, achievement: achievements),
            comboId: fi,
            scoreId: ri,
            title: title,
            ds: ds,
            lv: level
        )
    }

    static func < (lhs: ChartInfo, rhs: ChartInfo) -> Bool {
        return lhs.ra < rhs.ra
    }
    
    static func == (lhs: ChartInfo, rhs: ChartInfo) -> Bool {
        return lhs.ra == rhs.ra
    }
}

func fetchFitConstant(idNum: Int, diff: String) -> Double? {
    if let url = Bundle.main.url(forResource: "fitConstant", withExtension: "json") {
        do {
            let data = try Data(contentsOf: url)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let charts = json["charts"] as? [String: [[String: Any]]],
                   let songCharts = charts["\(idNum)"] {
                    for chart in songCharts {
                        if let chartDiff = chart["diff"] as? String {
                            print("找到 diff: \(chartDiff)")
                            if chartDiff == diff {
                                if let fitDiff = chart["fit_diff"] as? Double {
                                    return fitDiff
                                } else {
                                    print("未找到对应的 fit_diff")
                                }
                            } else {
                                print("diff 不匹配: \(chartDiff) vs \(diff)")
                            }
                        } else {
                            print("未找到 diff 字段")
                        }
                    }
                    print("未找到对应的 diff: \(diff)")
                } else {
                    print("未找到 idNum: \(idNum) 的数据")
                }
            } else {
                print("JSON 解析失败")
            }
        } catch {
            print("Error loading fitConstant.json: \(error)")
        }
    } else {
        print("未能找到 fitConstant.json 文件")
    }
    return nil
}

// BestList 类
class BestList: Codable {
    private var data: [ChartInfo]
    private let size: Int
    
    init(size: Int) {
        self.size = size
        self.data = []
    }
    
    func push(_ elem: ChartInfo) {
        if data.count >= size && elem < data.last! {
            return
        }
        data.append(elem)
        data.sort(by: >)
        while data.count > size {
            data.removeLast()
        }
    }
    
    func pop() {
        if !data.isEmpty {
            data.removeLast()
        }
    }
    
    var description: String {
        return "[\n\t" + data.map { "\($0)" }.joined(separator: ", \n\t") + "\n]"
    }
    
    var count: Int {
        return data.count
    }
    
    subscript(index: Int) -> ChartInfo {
        return data[index]
    }
    
    var allData: [ChartInfo] {
        return data
    }
    
    var totalRating: Int {
        return data.reduce(0) { $0 + $1.ra }
    }
}

func generateBestLists(username: String, completion: @escaping (BestList?, BestList?, Error?) -> Void) {
    guard let url = URL(string: "https://www.diving-fish.com/api/maimaidxprober/query/player") else {
        completion(nil, nil, NSError(domain: "Invalid URL", code: 400, userInfo: nil))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let payload: [String: Any] = [
        "username": username,
        "b50": true
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
    } catch {
        completion(nil, nil, error)
        return
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            completion(nil, nil, error)
            return
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let obj = json,
                  let charts = obj["charts"] as? [String: Any],
                  let dxList = charts["dx"] as? [[String: Any]],
                  let sdList = charts["sd"] as? [[String: Any]] else {
                completion(nil, nil, NSError(domain: "Invalid Response", code: 400, userInfo: nil))
                return
            }
            
            let sd_best = BestList(size: 35)
            let dx_best = BestList(size: 15)
            
            for c in sdList {
                if let chartInfo = ChartInfo.from(json: c) {
                    sd_best.push(chartInfo)
                }
            }
            
            for c in dxList {
                if let chartInfo = ChartInfo.from(json: c) {
                    dx_best.push(chartInfo)
                }
            }
            
            let totalRating = sd_best.totalRating + dx_best.totalRating
            print("总Rating: \(totalRating)")
            print("旧版本b35 Rating: \(sd_best.totalRating)")
            print("新版本b15 Rating: \(dx_best.totalRating)")
            
            completion(sd_best, dx_best, nil)
            
        } catch {
            completion(nil, nil, error)
        }
    }.resume()
}

func computeRa(ds: Double, achievement: Double) -> Int {
    var baseRa = 22.4
    switch achievement {
    case ..<50:
        baseRa = 7.0
    case ..<60:
        baseRa = 8.0
    case ..<70:
        baseRa = 9.6
    case ..<75:
        baseRa = 11.2
    case ..<80:
        baseRa = 12.0
    case ..<90:
        baseRa = 13.6
    case ..<94:
        baseRa = 15.2
    case ..<97:
        baseRa = 16.8
    case ..<98:
        baseRa = 20.0
    case ..<99:
        baseRa = 20.3
    case ..<99.5:
        baseRa = 20.8
    case ..<100:
        baseRa = 21.1
    case ..<100.5:
        baseRa = 21.6
    default:
        break
    }
    return Int(floor(ds * (min(100.5, achievement) / 100) * baseRa))
}

extension UserDefaults {
    func saveBestList(_ list: BestList, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(list) {
            set(encoded, forKey: key)
        }
    }
    
    func loadBestList(forKey key: String, size: Int) -> BestList {
        if let data = data(forKey: key),
           let list = try? JSONDecoder().decode(BestList.self, from: data) {
            return list
        }
        return BestList(size: size)
    }
}
