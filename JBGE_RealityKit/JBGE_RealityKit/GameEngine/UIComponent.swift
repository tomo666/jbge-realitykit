//
//  UIComponent.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/04.
//

import Foundation
import RealityKit

open class UIComponent {

    public let ID: Int = Int.random(in: 0..<Int.max)
    public unowned let GE: GameEngine

    public let ThisObject: GameObject
    public var Controller: GameObject?

    // --- Unity-compat state (Phase 1) ---
    // Unity-style viewport space: x,y are 0..1 where (0,0) is top-left.
    // We convert that into a local 3D coordinate space centered at (0,0).
    public var ScaleWidth: Float = 1.0
    public var ScaleHeight: Float = 1.0

    public var Pivot: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    public var Position: SIMD3<Float> = SIMD3<Float>(0.5, 0.5, 0)
    public var Scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    public var Rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0) // degrees

    public init(_ GE: GameEngine,
                _ objectName: String? = nil,
                _ parentObj: UIComponent? = nil,
                _ isControllerRequired: Bool = true) {

        self.GE = GE
        let name = objectName ?? "UIComponent"

        self.ThisObject = GameObject(name)

        // Phase 1 default: treat the UI space as a 2x2 plane centered at origin.
        // You can overwrite these from GameEngine later to match Unity camera/PPU behavior.
        self.ScaleWidth = 2.0
        self.ScaleHeight = 2.0

        if isControllerRequired {
            let controller = GameObject("\(name)_Controller")
            self.Controller = controller
            controller.transform.SetParent(parentObj?.ThisObject.transform ?? GE.UIRoot.transform)
            ThisObject.transform.SetParent(controller.transform)
        } else {
            ThisObject.transform.SetParent(parentObj?.ThisObject.transform ?? GE.UIRoot.transform)
        }
    }

    open func Update() {
        // Phase 0: do nothing
    }

    /// Unity-compatible: x,y are viewport coords (0..1), (0,0)=top-left.
    /// RealityKit-compatible: local space centered at (0,0), +Y up.
    public func SetPosition(_ x: Float, _ y: Float, _ z: Float = 0) {
        // Store Unity-style values
        Position = SIMD3<Float>(x, y, z)

        // Convert viewport -> centered local space
        let localX = (x - 0.5) * ScaleWidth
        let localY = (0.5 - y) * ScaleHeight
        let localZ = z

        (Controller ?? ThisObject).transform.localPosition = SIMD3<Float>(localX, localY, localZ)
    }

    public func SetScale(_ x: Float, _ y: Float, _ z: Float = 1) {
        Scale = SIMD3<Float>(x, y, z)
        (Controller ?? ThisObject).transform.localScale = SIMD3<Float>(x, y, z)
    }

    public func SetRotation(_ x: Int, _ y: Int, _ z: Int) {
        let radians = SIMD3<Float>(
            Float(x) * .pi / 180,
            Float(y) * .pi / 180,
            Float(z) * .pi / 180
        )

        let qx = simd_quatf(angle: radians.x, axis: [1,0,0])
        let qy = simd_quatf(angle: radians.y, axis: [0,1,0])
        let qz = simd_quatf(angle: radians.z, axis: [0,0,1])

        Rotation = SIMD3<Float>(Float(x), Float(y), Float(z))

        // Unity Quaternion.Euler is effectively Z, X, Y order (ZXY)
        // Quaternion multiplication applies right-to-left.
        (Controller ?? ThisObject).transform.localRotation = qy * qx * qz
    }

    /// Phase 1: store pivot (Phase 2 will apply proper pivot offset via Controller).
    public func SetPivot(_ x: Float, _ y: Float) {
        Pivot = SIMD2<Float>(x, y)
    }

    /// Unity-like reset (local).
    public func ResetTransform() {
        let target = (Controller ?? ThisObject)
        target.transform.localPosition = SIMD3<Float>(0, 0, 0)
        target.transform.localRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        target.transform.localScale = SIMD3<Float>(1, 1, 1)

        Pivot = SIMD2<Float>(0.5, 0.5)
        Position = SIMD3<Float>(0.5, 0.5, 0)
        Scale = SIMD3<Float>(1, 1, 1)
        Rotation = SIMD3<Float>(0, 0, 0)
    }
}
