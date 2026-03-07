//
//  CustomButtonView.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 28/02/26.
//

import SwiftUI

struct CustomButtonView: View {
    var label: String = "Start Button"
    var type: Int = 0
    
    var body: some View {
        if type == 1 {
            Text(label)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(.black, lineWidth: 1)
                )
        } else if type == 0 {
            Text(label)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.black)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    CustomButtonView()
}
