//
//  UIComponent.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/04.
//

import Foundation
import RealityKit
internal import AppKit

open class UIComponent {
    // NOTE:
    // RealityKit's effective viewport height does not match the theoretical
    // perspective frustum due to SwiftUI + RealityView layout and safe margins.
    // This value was empirically calibrated to match full visible screen height
    // across common resolutions (640x480 .. 1920x1080).
    public let UIWorldUnitPerLogicalUnit: Float = 0.866

    public var ID: Int = Int.random(in: 0..<Int.max)
    public unowned let GE: GameEngine

    public lazy var ThisObject: GameObject = GameObject("")
    public var Controller: GameObject?
    /// <summary>Sort order of this layer</summary>
    public var SortOrder: Int = 0

    // --- Unity-compat state (Phase 1) ---
    // Unity-style viewport space: x,y are 0..1 where (0,0) is top-left.
    // We convert that into a local 3D coordinate space centered at (0,0).
    public var ScaleWidth: Float = 1.0
    public var ScaleHeight: Float = 1.0
    /// <summary>The scaled width of the UICamera's viewport width</summary>
    public var ScaleScreenWidth: Float = 0.0
    /// <summary>The scaled height of the UICamera's viewport height</summary>
    public var ScaleScreenHeight: Float = 0.0

    public var Pivot: Vector2 = Vector2(0.5, 0.5)
    public var Position: Vector3 = Vector3(0.5, 0.5, 0)
    public var Scale: Vector3 = Vector3(1, 1, 1)
    public var Rotation: Vector3 = Vector3(0, 0, 0) // degrees
    
    /// <summary>Unity-compatible visibility flag</summary>
    public var IsVisible: Bool {
        get {
            let go = Controller ?? ThisObject
            return go.isEnabled
        }
        set {
            let go = Controller ?? ThisObject
            go.isEnabled = newValue
        }
    }

    // --- Unity-compatible RectTransform-like accessors ---

    public var LocalWidth: Float {
        get {
            let go = Controller ?? ThisObject
            return go.localSize.x
        }
        set {
            let go = Controller ?? ThisObject
            go.localSize = Vector2(newValue, go.localSize.y)
        }
    }

    public var LocalHeight: Float {
        get {
            let go = Controller ?? ThisObject
            return go.localSize.y
        }
        set {
            let go = Controller ?? ThisObject
            go.localSize = Vector2(go.localSize.x, newValue)
        }
    }

    public var LocalPositionX: Float {
        get {
            let go = Controller ?? ThisObject
            return go.transform.localPosition.x
        }
        set {
            let go = Controller ?? ThisObject
            let p = go.transform.localPosition
            go.transform.localPosition = Vector3(newValue, p.y, p.z)
        }
    }

    public var LocalPositionY: Float {
        get {
            let go = Controller ?? ThisObject
            return go.transform.localPosition.y
        }
        set {
            let go = Controller ?? ThisObject
            let p = go.transform.localPosition
            go.transform.localPosition = Vector3(p.x, newValue, p.z)
        }
    }

    public var LocalPositionZ: Float {
        get {
            let go = Controller ?? ThisObject
            return go.transform.localPosition.z
        }
        set {
            let go = Controller ?? ThisObject
            let p = go.transform.localPosition
            go.transform.localPosition = Vector3(p.x, p.y, newValue)
        }
    }

    // --- Motion Tweening State ---
    public enum TargetProperty: Int {
        case Position = 0
        case Rotation = 1
        case Scale = 2
    }
    private var motionTweenWaitCount: Int = 0
    private var currentMotionTweenWaitCount: Int = 0

    private var motionDistanceFromPrevFrame: Int = 0
    private var motionTotalFrames: Int = 1

    // [0] = Position, [1] = Rotation, [2] = Scale
    private var motionTweenData: [MotionTweenData?] = [nil, nil, nil]
    
    /// <summary>Determines if we should update on each frames</summary>
    public var IsUpdate: Bool = true

    /// <summary>Stores the accumulated frame count of this object (based on the game's main FPS)</summary>
    public var Frames: Int = 0

    /// <summary>The maximum frame count that this object will accumulate (Once the frame count reaches this max value, frame count will reset to 0)</summary>
    public var MaxFrames: Int = 0
    
    
    public init(
        _ GE: GameEngine,
        _ objectName: String? = nil,
        _ parentObj: UIComponent? = nil,
        _ isControllerRequired: Bool = true,
        _ isCreatePlaneForThisObject: Bool = false
    ) {
        self.GE = GE
        let name = objectName ?? String("UIComponent")
        self.ID = Int.random(in: 0..<Int.max)

        // --- Unity-compatible UI camera viewport sizing ---
        // Matches Unity: orthographicSize * 2 = viewport height in world units
        let pixelUnit: Float = 1.0
        
        // Full viewport size in world units
        ScaleScreenHeight = GE.UICamera.orthoSize * pixelUnit
        ScaleScreenWidth = ScaleScreenHeight * GE.UICamera.aspect

        // Logical UI space matches full viewport
        ScaleHeight = ScaleScreenHeight
        ScaleWidth = ScaleScreenWidth
        
        // Create an empty UIPlane and set it in the hierarchy, if told to do so
        if isCreatePlaneForThisObject {
            self.ThisObject = CreateUIPlane(name, Vector4(Float.random(in: 0..<1), Float.random(in: 0..<1), Float.random(in: 0..<1), 0.7))
        } else {
            // Otherwise, just create an empty GameObject
            self.ThisObject = GameObject(name)
            self.ThisObject.layer = 5
        }

        if isControllerRequired {
            // Create a container to encapsulate this object so we can control the pivots
            let controller = GameObject("UIComponentController")
            self.Controller = controller

            // If we don't have any parent object specified, then this container will be directly the child of the UICamera
            controller.transform.SetParent(parentObj == nil ? GE.MainGameObject.transform : parentObj?.ThisObject.transform)
            ThisObject.transform.SetParent(controller.transform)

            // Unity: Controller positioned at center of viewport
            controller.transform.localPosition = Vector3(0, 0, 0)

            // Controller logical size equals viewport size
            controller.localSize = Vector2(ScaleScreenWidth, ScaleScreenHeight)
        } else {
            // If we don't have any parent object specified, then this container will be directly the child of the UICamera
            ThisObject.transform.SetParent(parentObj?.ThisObject.transform)
        }

        // Unity: UI element defaults to full viewport size
        ThisObject.localSize = Vector2(ScaleScreenWidth, ScaleScreenHeight)
    }

    open func Update() {

        if !IsUpdate { return }

        Frames = GE.FrameCount % GE.TargetFrameRate
        if Frames >= MaxFrames {
            Frames = 0
        }

        // --- Motion Tween Execution (Unity-compatible) ---
        if motionTotalFrames > 1 {

            if currentMotionTweenWaitCount > 0 {
                currentMotionTweenWaitCount -= 1
            }

            if currentMotionTweenWaitCount == 0 {

                currentMotionTweenWaitCount = motionTweenWaitCount

                // Order matters: Position → Scale → Rotation
                let order: [TargetProperty] = [.Position, .Scale, .Rotation]

                ResetTransform()

                let t = Float(motionDistanceFromPrevFrame) / Float(motionTotalFrames)

                for prop in order {
                    guard let mtd = motionTweenData[prop.rawValue] else { continue }

                    let curvePoint = BezierPoint(
                        t,
                        mtd.motionBezierPoints[0],
                        mtd.motionBezierPoints[1],
                        mtd.motionBezierPoints[2],
                        mtd.motionBezierPoints[3]
                    )

                    let lerp = curvePoint.y

                    let newX = mtd.originalTransformVector3.x +
                        (mtd.motionTargetVector3.x - mtd.originalTransformVector3.x) * lerp
                    let newY = mtd.originalTransformVector3.y +
                        (mtd.motionTargetVector3.y - mtd.originalTransformVector3.y) * lerp
                    let newZ = mtd.originalTransformVector3.z +
                        (mtd.motionTargetVector3.z - mtd.originalTransformVector3.z) * lerp

                    let newPivotX = mtd.originalPivotVector2.x +
                        (mtd.motionTargetPivot.x - mtd.originalPivotVector2.x) * lerp
                    let newPivotY = mtd.originalPivotVector2.y +
                        (mtd.motionTargetPivot.y - mtd.originalPivotVector2.y) * lerp

                    SetPivot(newPivotX, newPivotY)

                    if prop == .Position {
                        SetPosition(newX, newY, newZ)
                    } else if prop == .Rotation {
                        SetRotation(Int(newX), Int(newY), Int(newZ))
                    } else if prop == .Scale {
                        SetScale(newX, newY, newZ)
                    }
                }

                motionDistanceFromPrevFrame += 1
                if motionDistanceFromPrevFrame >= motionTotalFrames {
                    motionDistanceFromPrevFrame = 0
                }
            }
        }
    }
    
    public func SetPosition(_ x: Float, _ y: Float, _ z: Float = 0.0) {
        Position = Vector3(x, y, z)
        let fullWorldHeight: Float = UIWorldUnitPerLogicalUnit * 2
        let fullWorldWidth: Float = UIWorldUnitPerLogicalUnit * GE.UICamera.aspect * 2
        let fullWorldDepth: Float = 0.1
        
        let target = Controller ?? ThisObject
        target.position = SIMD3(
            fullWorldWidth * x,
            fullWorldHeight * -y,
            fullWorldDepth * z)
        
/*
        let logicalW = 1.0 * Scale.x
        let logicalH = 1.0 * Scale.y

        let worldW = logicalW * UIWorldUnitPerLogicalUnit * GE.UICamera.aspect
        let worldH = logicalH * UIWorldUnitPerLogicalUnit

        let worldX = (x - 0.5) * worldW
        let worldY = (0.5 - y) * worldH

        target.position = SIMD3(worldX, worldY, z)
         */
    }

    /*
    /// Unity-compatible: x,y are viewport coords (0..1), (0,0)=top-left.
    /// RealityKit-compatible: local space centered at (0,0), +Y up.
    public func SetPosition(_ x: Float, _ y: Float, _ z: Float = 0) {
        // Store Unity-style values
        Position = Vector3(x, y, z)

        // Convert viewport -> centered local space
        let localX = (x - 0.5) * ScaleWidth
        let localY = (0.5 - y) * ScaleHeight
        let localZ = z

        (Controller ?? ThisObject).transform.localPosition = Vector3(localX, localY, localZ)
    }*/

    /*
    // Without border
    private func updatePlaneMeshWithPivot() {
        guard let model = ThisObject.children
            .compactMap({ $0 as? ModelEntity })
            .first else { return }

        let fullW = ScaleWidth  * Scale.x
        let fullH = ScaleHeight * Scale.y

        // Pivot: 0..1（左上 = 0,0）
        let left   = -Pivot.x * fullW
        let right  = left + fullW
        let top    =  Pivot.y * fullH
        let bottom = top - fullH

        let vertices: [SIMD3<Float>] = [
            SIMD3(left,  bottom, 0),
            SIMD3(right, bottom, 0),
            SIMD3(right, top,    0),
            SIMD3(left,  top,    0)
        ]

        let indices: [UInt32] = [0, 1, 2, 0, 2, 3]

        var desc = MeshDescriptor()
        desc.positions = MeshBuffer(vertices)
        desc.primitives = .triangles(indices)

        model.model?.mesh = try! MeshResource.generate(from: [desc])

        // RectTransform 相当
        ThisObject.localSize = Vector2(fullW, fullH)
    }
    */
    private func updatePlaneMeshWithPivot() {

        let models = ThisObject.children.compactMap { $0 as? ModelEntity }

        let model  = models.first { $0.name.hasSuffix("_Model") }
        let border = models.first { $0.name.hasSuffix("_Border") }

        guard let model else { return }

        /*
        let fullW = ScaleWidth  * Scale.x
        let fullH = ScaleHeight * Scale.y

        // Pivot: 0..1（左上 = 0,0）
        let left   = -Pivot.x * fullW
        let right  = left + fullW
        let top    =  Pivot.y * fullH
        let bottom = top - fullH*/
        
        // NOTE:
        // RealityKit's effective viewport height does not match the theoretical
        // perspective frustum due to SwiftUI + RealityView layout and safe margins.
        // This value was empirically calibrated to match full visible screen height
        // across common resolutions (640x480 .. 1920x1080).
        let halfH = UIWorldUnitPerLogicalUnit
        let halfW = halfH * GE.UICamera.aspect

        let fullW = (halfW * 2) * Scale.x
        let fullH = (halfH * 2) * Scale.y

        // Pivot: 0..1（左上 = 0,0）
        let left   = -Pivot.x * fullW
        let right  = left + fullW
        let top    =  Pivot.y * fullH
        let bottom = top - fullH

        // ===== Model =====
        let modelVerts: [SIMD3<Float>] = [
            SIMD3(left,  bottom, 0),
            SIMD3(right, bottom, 0),
            SIMD3(right, top,    0),
            SIMD3(left,  top,    0)
        ]

        let indices: [UInt32] = [0, 1, 2, 0, 2, 3]

        var desc = MeshDescriptor()
        desc.positions = MeshBuffer(modelVerts)
        desc.primitives = .triangles(indices)

        model.model?.mesh = try! MeshResource.generate(from: [desc])

        // ===== Border =====
        if let border {

            let t: Float = 0.02
            let z: Float = 0.001

            let outerL = left
            let outerR = right
            let outerB = bottom
            let outerT = top

            let innerL = outerL + t
            let innerR = outerR - t
            let innerB = outerB + t
            let innerT = outerT - t

            var v: [SIMD3<Float>] = []
            var i: [UInt32] = []

            func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
                let base = UInt32(v.count)
                v.append(contentsOf: [a,b,c,d])
                i.append(contentsOf: [
                    base, base+1, base+2,
                    base, base+2, base+3
                ])
            }

            // Top
            quad(
                SIMD3(outerL, innerT, z),
                SIMD3(outerR, innerT, z),
                SIMD3(outerR, outerT, z),
                SIMD3(outerL, outerT, z)
            )
            // Bottom
            quad(
                SIMD3(outerL, outerB, z),
                SIMD3(outerR, outerB, z),
                SIMD3(outerR, innerB, z),
                SIMD3(outerL, innerB, z)
            )
            // Left
            quad(
                SIMD3(outerL, innerB, z),
                SIMD3(innerL, innerB, z),
                SIMD3(innerL, innerT, z),
                SIMD3(outerL, innerT, z)
            )
            // Right
            quad(
                SIMD3(innerR, innerB, z),
                SIMD3(outerR, innerB, z),
                SIMD3(outerR, innerT, z),
                SIMD3(innerR, innerT, z)
            )

            var bDesc = MeshDescriptor()
            bDesc.positions = MeshBuffer(v)
            bDesc.primitives = .triangles(i)

            border.model?.mesh = try! MeshResource.generate(from: [bDesc])
        }

        // RectTransform 相当
        ThisObject.localSize = Vector2(fullW, fullH)
    }
    
    /*
    public func SetScale(_ x: Float, _ y: Float, _ z: Float = 1) {
        Scale = Vector3(x, y, z)
        (Controller ?? ThisObject).transform.localScale = Vector3(x, y, z)
    }*/
    
    public func SetScale(_ x: Float, _ y: Float, _ z: Float = 1) {
        Scale = Vector3(x, y, z)

        let target = Controller ?? ThisObject
        target.transform.scale = SIMD3(1, 1, 1)

        updatePlaneMeshWithPivot()
    }

    public func SetRotation(_ x: Int, _ y: Int, _ z: Int) {
        Rotation = Vector3(Float(x), Float(y), Float(z))
        guard let controller = Controller else {
            let rx = Float(x) * .pi / 180
            let ry = Float(y) * .pi / 180
            let rz = Float(z) * .pi / 180
            let q =
                simd_quatf(angle: ry, axis: SIMD3(0,1,0)) *
                simd_quatf(angle: rx, axis: SIMD3(1,0,0)) *
                simd_quatf(angle: rz, axis: SIMD3(0,0,1))
            ThisObject.transform.localRotation = q
            return
        }

        let size = controller.localSize

        // Pivot offset (local space)
        let pivotOffset = SIMD3<Float>(
            (Pivot.x - 0.5) * size.x,
            (0.5 - Pivot.y) * size.y,
            0
        )

        // Original local position
        let originalPos = controller.transform.localPosition.simd

        // Rotation quaternion
        let rx = Float(x) * .pi / 180
        let ry = Float(y) * .pi / 180
        let rz = Float(z) * .pi / 180
        let q =
            simd_quatf(angle: ry, axis: SIMD3(0,1,0)) *
            simd_quatf(angle: rx, axis: SIMD3(1,0,0)) *
            simd_quatf(angle: rz, axis: SIMD3(0,0,1))

        // Apply rotation
        controller.transform.localRotation = q

        // Correct position shift
        let rotatedOffset = q.act(pivotOffset)
        let delta = rotatedOffset - pivotOffset

        controller.transform.localPosition = Vector3(
            originalPos.x - delta.x,
            originalPos.y - delta.y,
            originalPos.z
        )
    }
    /*
    public func SetRotation(_ x: Int, _ y: Int, _ z: Int) {
        Rotation = Vector3(Float(x), Float(y), Float(z))

        let rx = Float(x) * .pi / 180
        let ry = Float(y) * .pi / 180
        let rz = Float(z) * .pi / 180

        let qx = simd_quatf(angle: rx, axis: SIMD3(1,0,0))
        let qy = simd_quatf(angle: ry, axis: SIMD3(0,1,0))
        let qz = simd_quatf(angle: rz, axis: SIMD3(0,0,1))

        // Unity互換 ZXY
        let rotationQuat = qy * qx * qz

        (Controller ?? ThisObject).transform.localRotation = rotationQuat
    }*/
    
    public func SetPivot(_ x: Float, _ y: Float) {
        Pivot = Vector2(x, y)
        //updatePlaneMeshWithPivot()
    }

    /// Unity-like reset (local).
    public func ResetTransform() {
        let target = (Controller ?? ThisObject)
        target.transform.localPosition = Vector3(0, 0, 0)
        target.transform.SetLocalRotation(0, 0, 0)
        target.transform.localScale = Vector3(1, 1, 1)

        Pivot = Vector2(0.5, 0.5)
        Position = Vector3(0.5, 0.5, 0)
        Scale = Vector3(1, 1, 1)
        Rotation = Vector3(0, 0, 0)
    }


    /// <summary>
    /// Sets the time frame to wait until this object applies transformations during motion tween.
    /// By specifiying 0, it will apply motion tween per frame as normally according to the game's main FPS.
    /// By specifying more than 0, the motion tween will not trigger until the frame elapses - so for example:
    /// If you have 60 FPS, and you set the frames to 2, the motion tween will be applied after 2 frames step, which results in this object being applied motion tweens as if it is running in 30 FPS
    /// </summary>
    /// <param name="frames">Number of frames to wait</param>
    public func SetMotionTweenWaitCount(_ frames: Int) {
        motionTweenWaitCount = frames
        currentMotionTweenWaitCount = frames
    }

    /// <summary>Sets the motion path bezier of this object</summary>
    /// <param name="targetProperty">The target property ID: [0] = PositionXYZ, [1] = RotateXYZ, [2] = ScaleXYZ</param>
    /// <param name="totalFrames">The number of frames (moving forward in the timeline) to apply the motion path bezier</param>
    /// <param name="targetX">The destination target position/rotation/scale X-axis value when the object reaches the "totalFrames"</param>
    /// <param name="targetY">The destination target position/rotation/scale Y-axis value when the object reaches the "totalFrames"</param>
    /// <param name="targetZ">The destination target position/rotation/scale Z-axis value when the object reaches the "totalFrames"</param>
    /// <param name="targetPivotX">The destination target pivot X-axis value when the object reaches the "totalFrames"</param>
    /// <param name="targetPivotY">The destination target pivot Y-axis value when the object reaches the "totalFrames"</param>
    /// <param name="P0X">The bezier P0 point X-axis</param>
    /// <param name="P0Y">The bezier P0 point Y-axis</param>
    /// <param name="P1X">The bezier P1 point X-axis</param>
    /// <param name="P1Y">The bezier P1 point Y-axis</param>
    /// <param name="P2X">The bezier P2 point X-axis</param>
    /// <param name="P2Y">The bezier P2 point Y-axis</param>
    /// <param name="P3X">The bezier P3 point X-axis</param>
    /// <param name="P3Y">The bezier P3 point Y-axis</param>
    public func SetMotionPathBezier(
        _ targetProperty: Int,
        _ totalFrames: Int,
        _ targetX: Float,
        _ targetY: Float,
        _ targetZ: Float,
        _ targetPivotX: Float,
        _ targetPivotY: Float,
        _ P0X: Float,
        _ P0Y: Float,
        _ P1X: Float,
        _ P1Y: Float,
        _ P2X: Float,
        _ P2Y: Float,
        _ P3X: Float,
        _ P3Y: Float
    ) {
        motionTotalFrames = totalFrames
        motionDistanceFromPrevFrame = 0

        var currentTransformVector3 = Vector3(0, 0, 0)
        if targetProperty == 0 {
            currentTransformVector3 = Position
        } else if targetProperty == 1 {
            currentTransformVector3 = Rotation
        } else if targetProperty == 2 {
            currentTransformVector3 = Scale
        }

        motionTweenData[targetProperty] = MotionTweenData(
            Vector3(targetX, targetY, targetZ),
            Vector2(targetPivotX, targetPivotY),
            [
                Vector3(P0X, P0Y, 0),
                Vector3(P1X, P1Y, 0),
                Vector3(P2X, P2Y, 0),
                Vector3(P3X, P3Y, 0)
            ],
            Vector3(currentTransformVector3.x, currentTransformVector3.y, currentTransformVector3.z),
            Vector2(Pivot.x, Pivot.y)
        )
    }

    /// <summary>
    /// Gets a point in a Cubic Bezier Curve
    /// (You can visualize the points better by using bezier curve simulators: https://www.desmos.com/calculator/d1ofwre0fr?lang=en)
    /// </summary>
    /// <param name="t">Time from range 0.0 to 1.0</param>
    /// <param name="p0">Point 0</param>
    /// <param name="p1">Point 1</param>
    /// <param name="p2">Point 2</param>
    /// <param name="p3">Point 3</param>
    /// <returns>Point on the bezier curve at a specified time</returns>
    private func BezierPoint(
        _ t: Float,
        _ p0: Vector3,
        _ p1: Vector3,
        _ p2: Vector3,
        _ p3: Vector3
    ) -> Vector3 {
        let u: Float = 1 - t
        let tt: Float = t * t
        let uu: Float = u * u
        let uuu: Float = uu * u
        let ttt: Float = tt * t

        let x =
            p0.x * uuu +
            p1.x * (3 * uu * t) +
            p2.x * (3 * u * tt) +
            p3.x * ttt

        let y =
            p0.y * uuu +
            p1.y * (3 * uu * t) +
            p2.y * (3 * u * tt) +
            p3.y * ttt

        let z =
            p0.z * uuu +
            p1.z * (3 * uu * t) +
            p2.z * (3 * u * tt) +
            p3.z * ttt

        return Vector3(x, y, z)
    }
    
    public func SetName(_ name: String) {
        let go = Controller ?? ThisObject
        go.name = name
    }

    public func GetName() -> String {
        let go = Controller ?? ThisObject
        return go.name
    }

    /// <summary>
    /// Unity-compatible destroy.
    /// Detaches and releases RealityKit entities.
    /// </summary>
    open func Destroy() {
        // Destroy child first (Unity-style safety)
        if let controller = Controller {
            controller.transform.SetParent(nil)
            controller.Destroy()
            Controller = nil
        }

        ThisObject.transform.SetParent(nil)
        ThisObject.Destroy()
        // Note: RealityKit entities are released automatically when no longer referenced
    }
    
    /// <summary>
    /// Unity-compatible UI plane factory (RealityKit implementation).
    /// </summary>
    open func CreateUIPlane(
        _ objectName: String,
        _ bgColor: Vector4? = Vector4.one
    ) -> GameObject {
        let go = GameObject(objectName)

        // --- Create a rectangular plane mesh (Unity-style UI layer) ---
        /*
        let fovRad = GE.UICamera.fieldOfView * .pi / 180.0
        let z: Float = 1.2 // 640x480 -->   , 960x540 --> 1.495 //abs(Position.z)
        let vHalfH = z * tan(fovRad / 2)
        let vHalfW = vHalfH * GE.UICamera.aspect
        let width  = vHalfW
        let height = vHalfH
        */
        
        // NOTE:
        // RealityKit's effective viewport height does not match the theoretical
        // perspective frustum due to SwiftUI + RealityView layout and safe margins.
        // This value was empirically calibrated to match full visible screen height
        // across common resolutions (640x480 .. 1920x1080).
        let height = UIWorldUnitPerLogicalUnit
        let width  = height * GE.UICamera.aspect
        
        let vertices: [SIMD3<Float>] = [
            SIMD3(-width, -height, 0),
            SIMD3( width, -height, 0),
            SIMD3( width,  height, 0),
            SIMD3(-width,  height, 0)
        ]

        let indices: [UInt32] = [
            0, 1, 2,
            0, 2, 3
        ]

        var meshDesc = MeshDescriptor()
        meshDesc.positions = MeshBuffer(vertices)
        meshDesc.primitives = .triangles(indices)

        let mesh = try! MeshResource.generate(from: [meshDesc])
        
        // --- Material (simple unlit color, Unity placeholder equivalent) ---
        var material = UnlitMaterial()
        if let c = bgColor {
            material.color = .init(tint: .init(red: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1.0))
        }

        let model = ModelEntity(mesh: mesh, materials: [material])
        model.name = "\(objectName)_Model"
        
        // Apply alpha if set
        model.components.set(OpacityComponent(opacity: Float(bgColor?.w ?? 1.0)))

        // Attach model under GameObject’s entity
        model.transform = .identity
        go.addChild(model)

        // --- Debug outline (UI frame) ---
        
        // lineStrip は RealityKit の MeshDescriptor では使えないので、4本の細い板ポリで枠を作る
        let borderZ: Float = 0.001
        let thickness: Float = 0.02  // 好きに調整。大きすぎるとUIに被る

        let halfW = width
        let halfH = height
        let t = thickness

        // 外側矩形 (outer) と 内側矩形 (inner)
        let outerL = -halfW
        let outerR =  halfW
        let outerB = -halfH
        let outerT =  halfH

        let innerL = outerL + t
        let innerR = outerR - t
        let innerB = outerB + t
        let innerT = outerT - t

        // 4本の枠ポリ: Top, Bottom, Left, Right をそれぞれ quad (2 triangles) で作る
        // 各quadは (a,b,c,d) の4頂点で、trianglesは (0,1,2) (0,2,3)
        func addQuad(_ verts: inout [SIMD3<Float>],
                     _ indices: inout [UInt32],
                     _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            let base = UInt32(verts.count)
            verts.append(contentsOf: [a,b,c,d])
            indices.append(contentsOf: [
                base + 0, base + 1, base + 2,
                base + 0, base + 2, base + 3
            ])
        }

        var borderVerts: [SIMD3<Float>] = []
        var borderIndices: [UInt32] = []

        // Top strip
        addQuad(&borderVerts, &borderIndices,
                SIMD3(outerL, innerT, borderZ),
                SIMD3(outerR, innerT, borderZ),
                SIMD3(outerR, outerT, borderZ),
                SIMD3(outerL, outerT, borderZ))

        // Bottom strip
        addQuad(&borderVerts, &borderIndices,
                SIMD3(outerL, outerB, borderZ),
                SIMD3(outerR, outerB, borderZ),
                SIMD3(outerR, innerB, borderZ),
                SIMD3(outerL, innerB, borderZ))

        // Left strip
        addQuad(&borderVerts, &borderIndices,
                SIMD3(outerL, innerB, borderZ),
                SIMD3(innerL, innerB, borderZ),
                SIMD3(innerL, innerT, borderZ),
                SIMD3(outerL, innerT, borderZ))

        // Right strip
        addQuad(&borderVerts, &borderIndices,
                SIMD3(innerR, innerB, borderZ),
                SIMD3(outerR, innerB, borderZ),
                SIMD3(outerR, innerT, borderZ),
                SIMD3(innerR, innerT, borderZ))

        var borderDesc = MeshDescriptor()
        borderDesc.positions = MeshBuffer(borderVerts)
        borderDesc.primitives = .triangles(borderIndices)

        let borderMesh = try! MeshResource.generate(from: [borderDesc])

        var borderMaterial = UnlitMaterial()
        borderMaterial.color = .init(tint: .white)

        let borderEntity = ModelEntity(mesh: borderMesh, materials: [borderMaterial])
        borderEntity.name = "\(objectName)_Border"
         go.addChild(borderEntity)
        // ----- Debug end -----

        

        // Unity RectTransform equivalent defaults
        go.localSize = Vector2(width * 2, height * 2)

        return go
    }
    
    public func Transform(baseScale: Vector3 = .one, position: Vector3 = .zero, scale: Vector3 = .one, rotation: Vector3 = .zero, positionPivot: Vector2 = Vector2(0.5, 0.5), scalePivot: Vector2 = Vector2(0.5, 0.5), rotationPivot: Vector2 = Vector2(0.5, 0.5)) {
        
        // Reset all transformations first
        ResetTransform()
        
        Position = position
        Scale = scale
        Rotation = rotation
        
        let aspectRatioY: Float = UIWorldUnitPerLogicalUnit;
        let aspectRatioX: Float = UIWorldUnitPerLogicalUnit * GE.UICamera.aspect
        
        // Scale to the actual size first (at its center)
        let baseScaleX = baseScale.x //Image.Width / screenWidth;
        let baseScaleY = baseScale.y //Image.Height / screenHeight;
        let baseScaleZ = baseScale.z
        ThisObject.scale = SIMD3(baseScaleX, baseScaleY, baseScaleZ)
        

        // Then, whilst at its center position, move to the desired position
        let offsetX: Float = (position.x * (aspectRatioX * 2) - aspectRatioX) + (aspectRatioX - positionPivot.x * (aspectRatioX * 2)) * baseScaleX;
        let offsetY: Float = (aspectRatioY - position.y * (aspectRatioY * 2)) + (positionPivot.y * (aspectRatioY * 2) - aspectRatioY) * baseScaleY;
        let offsetZ: Float = position.z * baseScaleZ;
        
        ThisObject.position = SIMD3(offsetX, offsetY, offsetZ)

        // Store offset positions
        let offsetOrgX = offsetX;
        let offsetOrgY = offsetY;
        let offsetOrgZ = offsetZ;
        
        // baseScale 後の「実サイズ（ワールド単位）」
        let baseW = aspectRatioX * baseScale.x * 2
        let baseH = aspectRatioY * baseScale.y * 2

        let deltaW = baseW * (scale.x - 1)
        let deltaH = baseH * (scale.y - 1)

        // pivot 0..1（左上 = 0,0）
        let pivotOffsetX = -deltaW * (scalePivot.x - 0.5)
        let pivotOffsetY =  deltaH * (scalePivot.y - 0.5)

        // スケール
        ThisObject.scale *= SIMD3(scale.x, scale.y, scale.z)

        // 位置補正（ここが今ズレてた）
        ThisObject.position += SIMD3(
            pivotOffsetX,
            pivotOffsetY,
            0
        )
        
        // Rotation
        // Calculate final size (after scale)
        let finalW = baseW * scale.x
        let finalH = baseH * scale.y
        // Create rotation pivot inside local space
        let pivotLocal = SIMD3<Float>(
            (rotationPivot.x - 0.5) * finalW,
            (0.5 - rotationPivot.y) * finalH,
            0
        )
        // Create quaternion
        let rx = rotation.x * .pi / 180
        let ry = rotation.y * .pi / 180
        let rz = rotation.z * .pi / 180
        let q =
            simd_quatf(angle: ry, axis: SIMD3(0,1,0)) *
            simd_quatf(angle: rx, axis: SIMD3(1,0,0)) *
            simd_quatf(angle: rz, axis: SIMD3(0,0,1))
        // Fix difference amount after rotation
        let rotatedPivot = q.act(pivotLocal)
        let delta = rotatedPivot - pivotLocal
        // Apply rotation
        ThisObject.transform.rotation = q
        ThisObject.position -= delta
        /*
        let moveOffsetXAfterScale = ((baseScaleX * aspectRatioX) - (baseScaleX * scale.x * aspectRatioX))
        * (1 - scalePivot.x)

        // Now, scale to the desired size from its center
        ThisObject.scale *= SIMD3(scale.x, scale.y, scale.z)
        
        ThisObject.position = SIMD3(
            offsetX - moveOffsetXAfterScale,
            offsetY,
            offsetZ
        )*/
        /*
        // Offset: Move to the scale pivot location (from the current scaled object's center)
        let halfWidth = offsetOrgX + (aspectRatioX * ThisObject.scale.x)
        let halfHeight = (aspectRatioY * ThisObject.scale.y)
        ThisObject.position = SIMD3(
            offsetX + halfWidth * (scalePivot.x - 0.5),
            offsetY - halfHeight * (scalePivot.y - 0.5),
            offsetZ
        )
      */
        /*
        let rx = Float(rotation.x) * .pi / 180
        let ry = Float(rotation.y) * .pi / 180
        let rz = Float(rotation.z) * .pi / 180

        let qx = simd_quatf(angle: rx, axis: SIMD3(1,0,0))
        let qy = simd_quatf(angle: ry, axis: SIMD3(0,1,0))
        let qz = simd_quatf(angle: rz, axis: SIMD3(0,0,1))

        // Unity互換 ZXY
        let rotationQuat = qy * qx * qz

        Controller?.transform.localRotation = rotationQuat
         */
        /*
        // Calculate the center of rotation taking into consideration the rotation pivot
        let rotateCenterX = offsetOrgX + offsetX - ((aspectRatioX * 2 * baseScaleX * dImg.Scale.X) * (1 - dImg.RotationPivot.X * 2)) / 2;
        let rotateCenterY = offsetOrgY + offsetY - ((aspectRatioY * 2 * baseScaleY * dImg.Scale.Y) * (dImg.RotationPivot.Y * 2 - 1)) / 2;
        let rotateCenterZ = 0.0f; // RotationPivotZ;*/
    }
    /*
    public func Translate(_ x: Float, _ y: Float, _ z: Float, _ baseScaleX: Float = 1.0, _ baseScaleY: Float = 1.0, _ baseScaleZ: Float = 1.0) {
        Position = Vector3(x, y, z)
        
        let aspectRatioY: Float = UIWorldUnitPerLogicalUnit;
        let aspectRatioX: Float = UIWorldUnitPerLogicalUnit * GE.UICamera.aspect
        
        // Then, whilst at its center position, move to the desired position
        let offsetX: Float = (x * (aspectRatioX * 2) - aspectRatioX) + (aspectRatioX - Pivot.x * (aspectRatioX * 2)) * baseScaleX;
        let offsetY: Float = (aspectRatioY - y * (aspectRatioY * 2)) + (Pivot.y * (aspectRatioY * 2) - aspectRatioY) * baseScaleY;
        let offsetZ: Float = z * baseScaleZ;

        let target = Controller ?? ThisObject
        target.position = SIMD3(offsetX, offsetY, offsetZ)
        
        // Store offset positions
        let offsetOrgX = offsetX;
        let offsetOrgY = offsetY;
        let offsetOrgZ = offsetZ;
    }
    
    public func Scale(_ x: Float, _ y: Float, _ z:Float, _ baseScaleX: Float = 1.0, _ baseScaleY: Float = 1.0, _ baseScaleZ: Float = 1.0) {
        Scale = Vector3(x, y, z)

        let aspectRatioY: Float = UIWorldUnitPerLogicalUnit;
        let aspectRatioX: Float = UIWorldUnitPerLogicalUnit * GE.UICamera.aspect
        
        let target = Controller ?? ThisObject
        target.transform.scale = SIMD3(x, y, z)
        /*
        // Move back to where it was before scaling, taking into consideration the pivot point
        let distanceDifferenceX = ((baseScaleX * x) * aspectRatioX) - (baseScaleX * aspectRatioX);
        let distanceDifferenceY = ((baseScaleY * y) * aspectRatioY) - (baseScaleY * aspectRatioY);
        let offsetX = distanceDifferenceX * (1 - Pivot.x * 2);
        let offsetY = distanceDifferenceY * (Pivot.y * 2 - 1);
        let offsetZ = translationOffsetOrgZ;
        
        target.position = SIMD3(offsetX, offsetY, offsetZ)*/
    }
    */
    /*
    public Transform3DGroup CalculateTransform3D(ORCA_DesignerComponentItem dImg) {
            int screenWidth = Editor.ScreenWidth;
            int screenHeight = Editor.ScreenHeight;

            // Texture vertex point positions should have the same aspect ratio as the game screen (default ratio is 1:1)
            double aspectRatioY = (double)screenHeight / (double)screenWidth;
            // Seems like there's a slight offset when compared with the under-lying canvas..
            double aspectRatioX = 1.00d;

            Transform3DGroup transform3DGroup = new Transform3DGroup();

            // Scale to the actual size first (at its center)
            double baseScaleX = dImg.Image.Width / (double)screenWidth;
            double baseScaleY = dImg.Image.Height / (double)screenHeight;
            double baseScaleZ = dImg.Scale.Z;
            double scaleCenterX = 0;
            double scaleCenterY = 0;
            double scaleCenterZ = 0;
            transform3DGroup.Children.Add(new ScaleTransform3D(baseScaleX, baseScaleY, baseScaleZ, scaleCenterX, scaleCenterY, scaleCenterZ));

            // Then, whilst at its center position, move to the desired position
            double offsetX = (dImg.Position.X * (aspectRatioX * 2) - aspectRatioX) + (aspectRatioX - dImg.PositionPivot.X * (aspectRatioX * 2)) * baseScaleX;
            double offsetY = (aspectRatioY - dImg.Position.Y * (aspectRatioY * 2)) + (dImg.PositionPivot.Y * (aspectRatioY * 2) - aspectRatioY) * baseScaleY;
            double offsetZ = dImg.Position.Z;
            transform3DGroup.Children.Add(new TranslateTransform3D(offsetX, offsetY, offsetZ));

            double offsetOrgX = offsetX;
            double offsetOrgY = offsetY;

            // Now, scale to the desired size
            transform3DGroup.Children.Add(new ScaleTransform3D(dImg.Scale.X, dImg.Scale.Y, dImg.Scale.Z, offsetX, offsetY, offsetZ));

            // Move back to where it was before scaling, taking into consideration the pivot point
            double distanceDifferenceX = ((baseScaleX * dImg.Scale.X) * aspectRatioX) - (baseScaleX * aspectRatioX);
            double distanceDifferenceY = ((baseScaleY * dImg.Scale.Y) * aspectRatioY) - (baseScaleY * aspectRatioY);
            offsetX = distanceDifferenceX * (1 - dImg.ScalePivot.X * 2);
            offsetY = distanceDifferenceY * (dImg.ScalePivot.Y * 2 - 1);
            offsetZ = dImg.Position.Z;
            transform3DGroup.Children.Add(new TranslateTransform3D(offsetX, offsetY, dImg.Position.Z));

            // Calculate the center of rotation taking into consideration the rotation pivot
            //double rotateCenterX = offsetOrgX + offsetX - ((aspectRatioX * 2 * baseScaleX * dImg.Scale.X) * (1 - dImg.RotationPivot.X * (aspectRatioX * 2))) / 2;
            //double rotateCenterY = offsetOrgY + offsetY - ((aspectRatioY * 2 * baseScaleY * dImg.Scale.Y) * (dImg.RotationPivot.Y * (aspectRatioY * 2) - 1)) / 2;
            double rotateCenterX = offsetOrgX + offsetX - ((aspectRatioX * 2 * baseScaleX * dImg.Scale.X) * (1 - dImg.RotationPivot.X * 2)) / 2;
            double rotateCenterY = offsetOrgY + offsetY - ((aspectRatioY * 2 * baseScaleY * dImg.Scale.Y) * (dImg.RotationPivot.Y * 2 - 1)) / 2;
            double rotateCenterZ = 0.0f; // RotationPivotZ;
                                                                         // Rotate
            Point3D p3D = new Point3D() {
                    X = rotateCenterX,
                    Y = rotateCenterY,
                    Z = rotateCenterZ
            };
            transform3DGroup.Children.Add(new RotateTransform3D(new AxisAngleRotation3D(new Vector3D(0, 0, 1), dImg.Rotation.Z), p3D));
            transform3DGroup.Children.Add(new RotateTransform3D(new AxisAngleRotation3D(new Vector3D(1, 0, 0), -dImg.Rotation.X), p3D));
            transform3DGroup.Children.Add(new RotateTransform3D(new AxisAngleRotation3D(new Vector3D(0, 1, 0), -dImg.Rotation.Y), p3D));
            
            
            dImg.Transform = transform3DGroup;

            return transform3DGroup;
    }
     */
}
