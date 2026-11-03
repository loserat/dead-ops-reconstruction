import Foundation
import SceneKit
import SpriteKit
import simd

extension ArcadeGame {
    func arenaExitModel(_ portal:ArenaExit)->SCNNode {
        let root=SCNNode();root.name=portal.teleporter ? "arena-teleporter":"arena-path"
        let color=portal.bonus==nil ? 0x8de0f0:0xffcf73
        let mat=combatEffectMaterial(color)
        let torus=SCNTorus(ringRadius:portal.teleporter ? 0.72:0.52,pipeRadius:0.035);torus.ringSegmentCount=40;torus.pipeSegmentCount=6;torus.materials=[mat]
        let ring=SCNNode(geometry:torus);ring.name="exit-energy-ring";ring.position.y=0.12;ring.renderingOrder=22;ring.castsShadow=false;root.addChildNode(ring)
        if portal.teleporter {
            let pad=cylinder(0.68,0.16,0x68796d);pad.position.y=0.02;root.addChildNode(pad)
            for i in 0..<6 {
                let a=Double(i)*Double.pi/3,post=box(0.07,0.12,0.07,color);post.geometry?.materials=[mat];post.position=SCNVector3(cos(a)*0.60,0.19,sin(a)*0.60);post.castsShadow=false;root.addChildNode(post)
            }
        }else {
            let arrow=mesh([SCNVector3(-0.24,0.14,0.08),SCNVector3(0.24,0.14,0.08),SCNVector3(0,0.14,-0.36)],[0,1,2],normals:Array(repeating:SCNVector3(0,1,0),count:3),mat:mat)
            arrow.renderingOrder=22;arrow.castsShadow=false;root.addChildNode(arrow)
            let yaw:Double=portal.side == .east ? -Double.pi/2:portal.side == .west ? Double.pi/2:portal.side == .south ? Double.pi:0
            root.eulerAngles.y=NodeFloat(yaw)
        }
        return root
    }
    func syncArenaExitArt(viewSize:CGSize) {
        sync(&arenaExitNodes,ids:Set(core.arenaExits.map(\.id)))
        let phase=core.arenaTransit?.fromPhase ?? core.phase
        let visible=(phase == .cleared || phase == .bonusRoom) && core.sideRoom?.kind != .fate
        for portal in core.arenaExits {
            let node=arenaExitNodes[portal.id] ?? arenaExitModel(portal)
            if arenaExitNodes[portal.id]==nil {arenaExitNodes[portal.id]=node;actors.addChildNode(node)}
            let age=core.exitClock-portal.opensAt
            node.isHidden = !visible || (portal.teleporter ? core.exitClock<=0:age<0)
            let rise=portal.teleporter ? max(0,1-core.exitClock/3):0
            node.position=SCNVector3(portal.p.x,portal.height-rise*0.65,portal.p.y)
            node.opacity=CGFloat(portal.teleporter && age<0 ? 0.45:0.78+0.16*sin(core.elapsed*4))
            if portal.teleporter {node.childNode(withName:"exit-energy-ring",recursively:false)?.eulerAngles.y=NodeFloat(core.elapsed*1.5)}
        }
        if transitCurtain.parent==nil {transitCurtain.name="arena-transition-black";transitCurtain.position=CGPoint(x:640,y:360);transitCurtain.zPosition=4;hudCanvas.addChild(transitCurtain)}
        let scale=max(0.001,hudCanvas.xScale)
        transitCurtain.size=CGSize(width:max(1280,viewSize.width/scale),height:max(720,viewSize.height/scale))
        transitCurtain.alpha=CGFloat(core.arenaTransit?.darkness ?? 0)
        transitCurtain.isHidden=core.arenaTransit==nil
    }
    func applyArenaCameraTween() {
        guard let transit=core.arenaTransit else{transitCameraOrigin=nil;transitCameraID=nil;return}
        if transitCameraID != transit.id {transitCameraID=transit.id;transitCameraOrigin=camera.worldTransform}
        guard transit.committed,transit.cameraProgress<1,let origin=transitCameraOrigin else{return}
        let target=camera.simdTransform,from=SCNNode();from.transform=origin
        let t=Float(transit.cameraProgress)
        camera.simdPosition=from.simdPosition*(1-t)+camera.simdPosition*t
        camera.simdOrientation=simd_slerp(from.simdOrientation,simd_quatf(target),t)
    }
}
