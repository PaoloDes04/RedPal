//
//  FarmingView.swift
//  RedPal
//
//  Created by Gianmarco Montella on 17/10/25.
//

import SwiftUI

struct FarmingView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack {
            Text("Welcome to Farming View!")
                .font(.largeTitle)
                .foregroundColor(.white)
            Button("Go Back") {
                onDismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green.opacity(0.8).ignoresSafeArea())
    }
}

#Preview {
    FarmingView {
        print("FarmingView dismissed")
    }
}
