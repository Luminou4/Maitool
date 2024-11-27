//
//  UserView.swift
//  Maitool
//
//  Created by Luminous on 2024/9/14.
//

import SwiftUI
import Combine

class UserManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var username: String = ""

    private let jwtTokenKey = "jwt_token"
    private let usernameKey = "username"

    init() {
        checkLoginStatus()
    }

    func login(username: String, jwtToken: String) {
        self.isLoggedIn = true
        self.username = username
        UserDefaults.standard.set(jwtToken, forKey: jwtTokenKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
    }

    func logout() {
        self.isLoggedIn = false
        self.username = ""
        UserDefaults.standard.removeObject(forKey: jwtTokenKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
    }

    private func checkLoginStatus() {
        if let token = UserDefaults.standard.string(forKey: jwtTokenKey),
           let storedUsername = UserDefaults.standard.string(forKey: usernameKey) {
            self.isLoggedIn = true
            self.username = storedUsername
        } else {
            self.isLoggedIn = false
        }
    }
}

struct UserView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var showLoginWindow: Bool = false
    
    var body: some View {
        VStack {
            if userManager.isLoggedIn {
                HomeView(username: userManager.username)
            }
        }
        .onAppear {
            if !userManager.isLoggedIn {
                showLoginWindow = true
            }
        }
        .sheet(isPresented: $showLoginWindow) {
            LoginView()
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack {
            Text("登录")
                .font(.headline)
                .padding()

            TextField("用户名", text: $username)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(5)
                .padding(.horizontal)

            SecureField("密码", text: $password)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(5)
                .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: {
                    login()
                }) {
                    Text("登录")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .frame(width: 300, height: 250)
    }

    func login() {
        isLoading = true
        errorMessage = ""
        
        guard let url = URL(string: "https://www.diving-fish.com/api/maimaidxprober/login") else {
            errorMessage = "无效的URL"
            isLoading = false
            return
        }

        let loginData: [String: String] = [
            "username": username,
            "password": password
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: loginData) else {
            errorMessage = "JSON序列化失败"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }

            guard error == nil else {
                DispatchQueue.main.async {
                    errorMessage = "请求失败: \(error!.localizedDescription)"
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    errorMessage = "账号或密码错误"
                }
                return
            }

            if let fields = httpResponse.allHeaderFields as? [String: String],
               let url = response?.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
                if let jwtCookie = cookies.first(where: { $0.name == "jwt_token" }) {
                    let jwtToken = jwtCookie.value
                    print("JWT Token: \(jwtToken)")
                    UserDefaults.standard.set(jwtToken, forKey: "jwt_token")
                    UserDefaults.standard.set(username, forKey: "username")
                    DispatchQueue.main.async {
                        userManager.login(username: username, jwtToken: jwtToken)
                    }
                } else {
                    DispatchQueue.main.async {
                        errorMessage = "登录成功，但未找到JWT Token"
                    }
                }
            }
        }.resume()
    }
}

struct HomeView: View {
    var username: String
    @State private var isLoggedOut: Bool = false

    var body: some View {
        NavigationView {
            Form {
                HStack {
                    Text("用户名")
                    Spacer()
                    Text(username)
                        .foregroundColor(.gray)
                }
                .padding()

                NavigationLink(destination: Text("预留选项1")) {
                    Text("预留选项1")
                }

                NavigationLink(destination: Text("预留选项2")) {
                    Text("预留选项2")
                }

                Button(action: {
                    logOut()
                }) {
                    Text("退出登录")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("用户")
        }
    }

    private func logOut() {
        UserDefaults.standard.removeObject(forKey: "jwt_token")
        UserDefaults.standard.removeObject(forKey: "username")
        isLoggedOut = true
    }
}

struct UserView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建 UserManager 实例
        let userManager = UserManager()
        
        // 注入 UserManager 环境对象
        UserView()
            .environmentObject(userManager)
    }
}
