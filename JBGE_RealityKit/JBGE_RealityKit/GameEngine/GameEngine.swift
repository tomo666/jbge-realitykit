//
//  GameEngine.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/03.
//

open class GameEngine {
    // RealityKit Specific: Root Scene to attach objects
    public let RootScene: RealityKitScene
    
    // For showing debug info (although this uses Unity's Canvas so currently is a placeholder)
    public var DebugDeviceInputCanvasObj: GameObject? = nil
    public var DebugPerformanceCanvasObj: GameObject? = nil

    // Main GameObject
    public var MainGameObject: GameObject
    
    // Reference to 2D Game Engine
    public var TopDownGameMain: Any? = nil

    // Manages the non-UI components
    public var SceneManager: GameObject
    // Manages the actors within the game
    public var ActorManager: GameObject
    // Manages the map within the game
    public var MapManager: GameObject
    
    // Flag to determine if DEBUG info should be shown on screen or not
    public var IsShowDebugInfo: Bool = false
    // Defines the target frame rate (defaults to 60)
    public var TargetFrameRate: Int = 60
    // Stores the average frame rate
    public var AverageFrameRate: Int = 0
    // Stores the frame count 0 to 60
    public var FrameCount: Int = 0
    // Amount of frame to wait until executing the next script
    public var WaitFrameCount: Int = 0
    // Determines if we are in wait state or not
    public var IsWaiting: Bool = false

    // Reference to the Main Camera object
    public var MainCamera: Any? = nil
    // Reference to the UICamera camera object
    public var UICamera: Any? = nil
    // Set to false if camera is in perspective mode, else true in orthographic mode
    public var IsUICameraOrthographic: Bool = false
    // If in perspective mode, the horizontal Field Of View Angle (in degrees)
    public var FOV: Float = 60.0
    // The Pixel Per Unit scale to lift up UI scaling
    public var PPUScaleUpUI: Float = 4.0
    // The Pixel Per Unit scale to lift up 2D Map scaling (Actually it's the ortho size so not affecting the actual object scales)
    public var PPUScaleUpWorld: Float = 5.0

    // Reference to the Main Camera (or virtual camera) object
    public var CinemachineVirtualCamera: Any? = nil
    // Reference to the CinemachinePositionComposer
    public var CinemachinePositionComposer: Any? = nil

    // Manages all textmeshpro text used in game
    public var TextBlockManagerList: [Any] = []
    // TextBlockManager: current list index to operate on
    public var CurrentTextBlockManagerIndex: Int = 0
    // TextBlock: current list index to operate on
    public var CurrentTextBlockIndex: Int = 0

    // TextBlockManager: current list index to operate on
    public var CurrentBMPTextManagerIndex: Int = 0
    // TextBlock: current list index to operate on
    public var CurrentBMPTextIndex: Int = 0
    
    // The one and only Base UI Layer that always sits in front of the UICamera
    public var UIBaseLayer: UIComponent? = nil
    // UI layer that manages actors (or sprites)
    public var UIBackgroundLayer: UIComponent? = nil
    
    // Stores all the UILayer(s) that is placed on the UIBaseLayer UICanvas
    public var UILayers: [Int: UIComponent] = [:]
    // Stores all the 2D textures used in this game
    public var Textures: [Int: Any] = [:]
    // Stores all the Image object used in this game
    public var Images: [Int: Any] = [:]
    // Stores all the Font object used in this game
    public var Fonts: [Int: Any] = [:]
    // Stores all the BMPText object used in this game
    public var Texts: [Int: Any] = [:]
    // Stores all the Actor2D object used in this game
    public var Actor2Ds: [Int: Any] = [:]
    // Stores all the Map2D object used in this game
    public var Map2Ds: [Int: Any] = [:]

    // ImageManager: current list index to operate on
    public var CurrentImageManagerIndex: Int = 0
    // Image: current list index to operate on
    public var CurrentImageIndex: Int = 0

    // Image direction to search in the atlas for creating animations that are made up of multiple sprites
    public enum SheetOrientation {
        case Horizontal
        case Vertical
    }
    // General horizontal alignment definitions
    public enum HorizontalAlignment {
        case Left
        case Center
        case Right
    }
    // General vertical alignment definitions
    public enum VerticalAlignment {
        case Top
        case Middle
        case Bottom
    }
    // General orientation definitions
    public enum Orientation {
        case Horizontal
        case Vertical
    }
    // General speed identifiers
    public enum MovementSpeed {
        case VerySlow
        case Slow
        case Normal
        case Fast
        case VeryFast
    }

    // User gamepad device inputs
    //public var IDGamePad: IDGamePad = IDGamePad()
    // User mouse device inputs
    //public var IDMouse: IDMouse = IDMouse()
    // User keyboard device inputs
    //public var IDKeyboard: IDKeyboard = IDKeyboard()
    // Manages all user inputs
    //public var IDUserInput: UserInput;

    // The global pixel per unit applied to non-UI 2D graphic elements
    public var GlobalPixelPerUnit = 32;
    
    public init(_ gameObject: GameObject, scene: RealityKitScene) {
        self.MainGameObject = gameObject
        self.RootScene = scene

        SceneManager = GameObject("SceneManager")
        ActorManager = GameObject("ActorManager")
        MapManager   = GameObject("MapManager")

        ActorManager.transform.SetParent(SceneManager.transform)
        MapManager.transform.SetParent(SceneManager.transform)

        // RealityKit specific
        scene.AddToScene(SceneManager)
        scene.AddToScene(ActorManager)
        scene.AddToScene(MapManager)
    }
}
