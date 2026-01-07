//
//  ContentView.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/03.
//

import SwiftUI
import RealityKit
import JBGE_RCP

final class GameLoopDriver {

    private var accumulator: Float = 0
    private let fixedDeltaTime: Float = 1.0 / 60.0

    func tick(gameMain: GameMain, deltaTime: Float) {
        // 可変フレーム更新
        gameMain.Update(deltaTime)

        // FixedUpdate 用に時間を貯める
        accumulator += deltaTime

        let maxSteps = 5
        var steps = 0

        while accumulator >= fixedDeltaTime && steps < maxSteps {
            gameMain.FixedUpdate(fixedDeltaTime)
            accumulator -= fixedDeltaTime
            steps += 1
        }
    }
}

struct ContentView: View {
    private let rootAnchor = AnchorEntity(world: .zero)

    private let loop = GameLoopDriver()
    private var gameMain = GameMain()
    private var gameObject: GameObject = GameObject("GameMain")

    var body: some View {
        GeometryReader { geo in
            RealityView { content in
                if let sceneEntity = try? await Entity(named: "Scene", in: JBGE_RCPBundle) {
                    content.add(sceneEntity)
                    content.add(gameObject)
                    content.add(rootAnchor)
                    rootAnchor.addChild(gameObject)

                    // Unity: Start equivalent
                    gameMain.start(gameObject: gameObject)

                    _ = content.subscribe(to: SceneEvents.Update.self) { event in
                        let deltaTime = Float(event.deltaTime)
                        loop.tick(gameMain: gameMain, deltaTime: deltaTime)
                    }
                }
            } update: { _ in
                // Update は SceneEvents.Update に一本化
                if gameMain.IsGameInitialized == false {
                    gameMain.UpdateScreenSize(
                        width: Float(geo.size.width),
                        height: Float(geo.size.height)
                    )
                    gameMain.IsGameInitialized = true
                }
            }
            .onChange(of: geo.size) { oldSize, newSize in
                guard oldSize != newSize else { return }
                gameMain.UpdateScreenSize(
                    width: Float(newSize.width),
                    height: Float(newSize.height)
                )
            }
        }
        .frame(minWidth: 960, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
