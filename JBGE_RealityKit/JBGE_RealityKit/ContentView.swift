//
//  ContentView.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/03.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity(world: .zero)
            content.add(anchor)
        }
    }
}

#Preview {
    ContentView()
}
