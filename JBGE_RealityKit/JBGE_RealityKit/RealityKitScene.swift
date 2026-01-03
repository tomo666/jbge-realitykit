//
//  RealityKitScene.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/04.
//

import RealityKit

public final class RealityKitScene {
    public let rootAnchor = AnchorEntity(world: .zero)

    public func AddToScene(_ gameObject: GameObject) {
        rootAnchor.addChild(gameObject.entity)
    }
}
