//
//  JBEntity.swift
//  JBGE_RealityKit
//
//  Created by Tomohiro Kadono on 2026/01/04.
//

import RealityKit

open class JBEntity : Entity {
    private weak var owner: JBEntity?
    
    internal init(owner: JBEntity) {
        self.owner = owner
        super.init()
    }
    required public init() {
        super.init()
        self.owner = nil
    }
    public init(_ name: String) {
        super.init()
        self.owner = nil
        self.name = name
    }
    
    public var IsEnabled: Bool = true { didSet { self.isEnabled = IsEnabled } }
    public func Destroy() { self.removeFromParent() }
    public func SetParent(_ parent: JBEntity?) {
        if let parent { parent.addChild(self) } else { self.removeFromParent() }
    }
    public func SetParent(_ parent: Entity?) {
        if let parent { parent.addChild(self) } else { self.removeFromParent() }
    }
    public func AddChild(_ child: JBEntity?) {
        if let child { self.addChild(child) }
    }
    public func AddChild(_ child: Entity?) {
        if let child { self.addChild(child) }
    }
}

