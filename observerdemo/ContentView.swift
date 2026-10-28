//
//  ContentView.swift
//  observerdemo
//
//  Created by Ishpreet singh on 06/10/26.
//

import SwiftUI

struct ContentView: View {

    @State private var result = "No API call yet"
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {

            Text("API Observability Test")
                .font(.title2)
                .fontWeight(.semibold)

            Button {
                testAPI()
            } label: {
                Text(isLoading ? "Loading..." : "Test API")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            ScrollView {
                Text(result)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxHeight: 300)
        }
        .padding()
    }

    private func testAPI() {

        guard let url = URL(
            string: "https://jsonplaceholder.typicode.com/posts/1"
        ) else {
            return
        }

        isLoading = true
        result = "Calling API..."

        URLSession.shared.dataTask(with: url) { data, response, error in

            DispatchQueue.main.async {
                isLoading = false
            }

            if let error {
                DispatchQueue.main.async {
                    result = "Error:\n\(error.localizedDescription)"
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
//                print("Status Code:", httpResponse.statusCode)
//                print("Headers:", httpResponse.allHeaderFields)
            }

            guard let data else {
                DispatchQueue.main.async {
                    result = "No response data"
                }
                return
            }

            let responseString =
                String(data: data, encoding: .utf8) ?? "Invalid response"

//            print("Response:")
//            print(responseString)

            DispatchQueue.main.async {
                result = responseString
            }
        }
        .resume()
    }
}

#Preview {
    ContentView()
}
