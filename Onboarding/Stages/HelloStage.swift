//
//  HelloStage.swift
//  Nook
//
//  Created by Maciek Bagiński on 19/02/2026.
//

import SwiftUI

struct HelloStage: View {

    var body: some View {
        VStack(spacing: 24){
            Text("Say Hi to Lexon Browser")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            LexonBrandMark(size: 128)
            Text("Your new open-source browser.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
