import Foundation
import SceneKit

/// Own lightweight meshes: no opaque energy sphere hiding the body and no texture/particle allocation per frame.
extension ArcadeGame {
    func combatEffectMaterial(_ color:Int)->SCNMaterial {
        let mat=material(color,glow:true);mat.lightingModel = .constant
        mat.blendMode = .alpha;mat.writesToDepthBuffer=false;mat.isDoubleSided=true
        return mat
    }
    func bodyShieldModel()->SCNNode {
        let root=SCNNode();root.name="body-contact-shield"
        let mat=combatEffectMaterial(0x8eeaf4)
        for (height,radius) in [(0.09,0.66),(0.64,0.56)] {
            let torus=SCNTorus(ringRadius:CGFloat(radius),pipeRadius:0.012)
            torus.ringSegmentCount=40;torus.pipeSegmentCount=4;torus.materials=[mat]
            let ring=SCNNode(geometry:torus);ring.position.y=NodeFloat(height);ring.castsShadow=false;ring.renderingOrder=22;root.addChildNode(ring)
        }
        // Four separated meridians leave the torso, hands and weapon unobstructed.
        for quarter in 0..<4 {
            let a=Double(quarter)*Double.pi/2
            for i in 0..<6 {
                let t=Double(i)/5*Double.pi/2,r=0.64*cos(t),h=0.13+sin(t)*1.20
                let dot=ball(0.016,0x8eeaf4,glow:true);dot.geometry?.materials=[mat]
                dot.position=SCNVector3(cos(a)*r,h,sin(a)*r);dot.castsShadow=false;dot.renderingOrder=22;root.addChildNode(dot)
            }
        }
        return root
    }
    func boostTrailModel()->SCNNode {
        let root=SCNNode();root.name="boost-motion-trail"
        let mat=combatEffectMaterial(0x9aebff)
        // Travel is local -Z. The streak is behind the moving actor, clear of the aim marker.
        for i in 0..<4 {
            let z=0.4+Double(i)*0.43,width=0.30+Double(i)*0.10
            let points=[SCNVector3(-width,0.09,z+0.16),SCNVector3(0,0.09,z),SCNVector3(-width,0.09,z+0.21),SCNVector3(0,0.09,z+0.05),SCNVector3(width,0.09,z+0.16),SCNVector3(width,0.09,z+0.21)]
            let node=mesh(points,[0,1,2,2,1,3,1,4,3,3,4,5],normals:Array(repeating:SCNVector3(0,1,0),count:6),mat:mat)
            node.opacity=CGFloat(0.72-Double(i)*0.13);node.castsShadow=false;node.renderingOrder=22;root.addChildNode(node)
        }
        return root
    }
    func syncCombatEffects() {
        let art=activeArt,p=core.playerRoster.current
        if let shield=p.bodyShield,core.isPlayerActive,core.vehicle==nil {
            if art.bodyShieldNode==nil {art.bodyShieldNode=bodyShieldModel();actors.addChildNode(art.bodyShieldNode!)}
            let node=art.bodyShieldNode!,color=shield.fading ? 0xffca7c:0x8eeaf4
            if node.parent !== actors {actors.addChildNode(node)}
            node.isHidden=false;node.position=SCNVector3(p.hero.x,p.heroElevation+0.04,p.hero.y)
            node.opacity=CGFloat(shield.fading ? 0.40+0.18*sin(core.elapsed*14):0.58+0.08*sin(core.elapsed*7))
            if art.bodyShieldFading != shield.fading {
                for child in node.childNodes {child.geometry?.firstMaterial?.diffuse.contents=rgb(color);child.geometry?.firstMaterial?.emission.contents=rgb(color)}
                art.bodyShieldFading=shield.fading
            }
        }else{art.bodyShieldNode?.isHidden=true}
        if p.dashTime>0,core.isPlayerActive,core.vehicle==nil {
            if art.boostTrailNode==nil {art.boostTrailNode=boostTrailModel();actors.addChildNode(art.boostTrailNode!)}
            let node=art.boostTrailNode!;node.isHidden=false
            if node.parent !== actors {actors.addChildNode(node)}
            node.position=SCNVector3(p.hero.x,p.heroElevation,p.hero.y)
            node.eulerAngles.y=NodeFloat(atan2(-p.boostDirection.x,-p.boostDirection.y))
            node.opacity=CGFloat(min(1,p.dashTime/0.08))
        }else{art.boostTrailNode?.isHidden=true}
    }
}
