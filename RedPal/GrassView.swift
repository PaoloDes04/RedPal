//
//  GrassView.swift
//  RedPal
//
//  Created by Gianmarco Montella on 17/10/25.
//

import SwiftUI

struct GrassView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Image("SfondoErba2")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Esempio: pulsante Indietro in alto a destra
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss() // Torna alla home
                    } label: {
                        Image(systemName: "chevron.backward.circle.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                            .padding(.trailing, 20)
                            .padding(.top, 20)
                    }
                }
                Spacer()
            }
        }
    }
}

#Preview {
    GrassView()
}
