//
//  GameObject.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/04.
//

import RealityKit
import simd

public final class GameObject {
    public var name: String {
        didSet { entity.name = name }
    }

    // RealityKit実体
    internal let entity: Entity

    // Unity互換Transform
    public lazy var transform: Transform = Transform(owner: self)

    public init(_ name: String) {
        self.name = name
        self.entity = Entity()
        self.entity.name = name
    }
}
