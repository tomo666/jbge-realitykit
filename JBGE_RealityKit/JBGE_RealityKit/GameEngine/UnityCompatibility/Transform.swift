//
//  Transform.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/04.
//

import RealityKit
import simd

public final class Transform {
    private unowned let owner: GameObject

    internal init(owner: GameObject) {
        self.owner = owner
    }

    public func SetParent(_ parent: Transform?) {
        if let parent {
            owner.entity.setParent(parent.owner.entity)
        } else {
            owner.entity.setParent(nil)
        }
    }

    public func SetPosition(_ x: Float, _ y: Float, _ z: Float, ppu: Float) {
        owner.entity.position = SIMD3(x / ppu, y / ppu, z / ppu)
    }

    public func SetScale(_ x: Float, _ y: Float, _ z: Float) {
        owner.entity.scale = SIMD3(x, y, z)
    }

    public func SetRotation(_ x: Float, _ y: Float, _ z: Float) {
        // Convert degrees to radians explicitly (Unity-style Euler degrees)
        let radians = SIMD3<Float>(
            x * Float.pi / 180.0,
            y * Float.pi / 180.0,
            z * Float.pi / 180.0
        )

        // Unity-style explicit quaternion composition from Euler angles (XYZ order)
        let qx = simd_quatf(angle: radians.x, axis: SIMD3<Float>(1, 0, 0))
        let qy = simd_quatf(angle: radians.y, axis: SIMD3<Float>(0, 1, 0))
        let qz = simd_quatf(angle: radians.z, axis: SIMD3<Float>(0, 0, 1))

        // Unity-style Euler order: Z * X * Y (matches Transform.eulerAngles)
        owner.entity.orientation = qz * qx * qy
    }
}
