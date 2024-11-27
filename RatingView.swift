//
//  RatingView.swift
//  Maitool
//
//  Created by Luminous on 2024/8/7.
//

import SwiftUI

struct RatingView: View {
    @State private var percentage: String = ""
    @State private var constantValue: String = ""
    @State private var finalRating: Int? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Image("PRiSM")
                    .resizable()
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    TextField("达成率", text: $percentage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .padding()
                        .opacity(0.7)

                    TextField("铺面定数", text: $constantValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .padding()
                        .opacity(0.7)

                    Button(action: calculateRating) {
                        Text("计算 Rating")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()

                    if let rating = finalRating {
                        Text("Rating: \(rating)")
                            .font(.title)
                            .padding()
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.body)
                            .padding()
                    }

                    Spacer()
                }
                .navigationTitle("Rating计算")
                .padding()
            }
        }
    }
    
    private func calculateRating() {
        guard let percentageValue = Double(percentage),
              let constant = Double(constantValue),
              percentageValue >= 0, percentageValue <= 101,
              constant >= 1, constant <= 16 else {
            errorMessage = "请输入有效的达成率或铺面定数"
            finalRating = nil
            return
        }
        finalRating = computeRa(ds: constant, achievement: percentageValue)
        errorMessage = nil
    }
}

#Preview {
    RatingView()
}
