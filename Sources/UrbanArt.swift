import Foundation
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ArcadeGame {
    func buildUrban() {
        let concrete=material(0x858779)
        if let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/urban-concrete-v10.png") {
            #if os(macOS)
            concrete.diffuse.contents=NSImage(contentsOf:url) ?? rgb(0x858779)
            #else
            concrete.diffuse.contents=UIImage(contentsOfFile:url.path) ?? rgb(0x858779)
            #endif
        }else {concrete.diffuse.contents=detailTexture(kind:"plaster-city-floor",base:0x858779)}
        concrete.diffuse.wrapS = .repeat;concrete.diffuse.wrapT = .repeat;concrete.diffuse.contentsTransform=SCNMatrix4MakeScale(5,4,1)
        let floor=box(40,0.3,30,0x6a7061);floor.position.y = -0.18;floor.geometry?.materials=[concrete];decor.addChildNode(floor)
        let structure=SCNNode()
        let roofConcrete=concrete.copy() as! SCNMaterial;roofConcrete.diffuse.contentsTransform=SCNMatrix4MakeScale(2,2,1);roofConcrete.multiply.contents=rgb(0xbfc7b9)
        let platform=box(9.8,1.8,10.1,0x75796c);platform.geometry?.materials=[roofConcrete];platform.position=SCNVector3(-6.7,0.9,-2.55);structure.addChildNode(platform)
        // Each step's visible top follows the same linear incline used by the simulation.
        for i in 0..<12 {
            let h=Double(12-i)*1.8/12,step=stoneBlock(0.25,h,2.6,0x9a9c8b)
            step.geometry?.materials=[material(0x8b9388)];step.position=SCNVector3(-1.8+(Double(i)+0.5)*0.25,h/2,0);structure.addChildNode(step)
            let edge=box(0.035,0.025,2.6,0x454f49);edge.position=SCNVector3(-1.8+Double(i+1)*0.25,h+0.014,0);structure.addChildNode(edge)
            let back=stoneBlock(1.8,h,0.25,0x9a9c8b);back.geometry?.materials=[material(0x8b9388)];back.position=SCNVector3(-10,h/2,2.5+(Double(i)+0.5)*0.25);structure.addChildNode(back)
        }
        // Low parapets show the height edge; the broad yellow opening marks a one-way drop.
        for (z,length) in [(-5.6,1.65),(-3.7,1.65),(1.9,1.1)] {
            let wall=stoneBlock(0.20,0.55,length,0xa1a18e);wall.position=SCNVector3(-1.8,2.07,z);structure.addChildNode(wall)
        }
        for x in [-8.0,-2.7] {
            let wall=stoneBlock(x < -7 ? 2.0:1.8,0.45,0.20,0x9b9e8e);wall.position=SCNVector3(x,2.02,2.5);structure.addChildNode(wall)
        }
        for x in stride(from:-6.05,through:-3.95,by:0.30) {
            let mark=box(0.18,0.025,0.42,0xd4c379);mark.position=SCNVector3(x,1.83,2.3);structure.addChildNode(mark)
        }
        for side in [-1.0,1] {
            let rear=stoneBlock(10.4,3.0,0.8,0x7c8273);rear.position=SCNVector3(side*6.9,1.3,-8.1);structure.addChildNode(rear)
            let front=stoneBlock(10.4,0.45,0.5,0x7c8273);front.position=SCNVector3(side*6.9,0.15,8.0);structure.addChildNode(front)
            let opening=core.layout.entryCrossOffset(side:side<0 ? .west:.east)
            structure.addChildNode(sideFacadeWithOpening(x:side*13.2,center:-0.8,span:13,width:2.2,height:4.2,base:-0.2,openingCenter:opening,color:side<0 ? 0x5f6d61:0x7a6955))
            for z in stride(from:-6.0,through:5.0,by:2.1) where abs(z-opening)>1.8 {
                let shutter=box(0.07,1.4,1.25,0x424f49);shutter.position=SCNVector3(side*12.05,2.8,z);structure.addChildNode(shutter)
                let frame=box(0.12,0.1,1.45,0xada68e);frame.position=SCNVector3(side*12.0,3.55,z);structure.addChildNode(frame)
            }
        }
        let rooftop=box(8.8,0.15,1.8,0x657269);rooftop.position=SCNVector3(-6.6,1.75,-6.5);structure.addChildNode(rooftop)
        for x in stride(from:-10.8,through:-2.4,by:0.35) {
            let rib=box(0.04,0.07,1.85,0x84918a);rib.position=SCNVector3(x,1.86,-6.5);structure.addChildNode(rib)
        }
        for obstacle in UrbanLayout.obstacles.dropFirst(4) {
            let crate=marketCrate();crate.scale=SCNVector3(1.0,0.7,0.7);crate.position=SCNVector3(obstacle.p.x,obstacle.elevation,obstacle.p.y);structure.addChildNode(crate)
        }
        decor.addChildNode(structure.flattenedClone())
        let wires=SCNNode(),wire=material(0x303d38)
        for side in [-1.0,1] {
            var last=SCNVector3(side*11.5,4.4,-7.5)
            for i in 1...26 {
                let t=Double(i)/26,p=SCNVector3(side*(11.5-22*t),4.4-sin(t*Double.pi)*0.8,-7.5+15*t)
                wires.addChildNode(beam(last,p,radius:0.016,mat:wire));last=p
            }
        }
        // Looping cable clutter belongs to the roof surface and has no hidden collision.
        for i in 0..<8 {
            let g=SCNTorus(ringRadius:CGFloat(0.34+Double(i%3)*0.1),pipeRadius:0.014);g.materials=[wire]
            let n=SCNNode(geometry:g);n.position=SCNVector3(-7+Double(i%4)*0.55,1.83,-1.8+Double(i/4)*2.6);wires.addChildNode(n)
        }
        decor.addChildNode(wires.flattenedClone())
        let neon=SCNNode();neon.name="urban-neon"
        let sign=box(0.16,1.8,5.8,0x6a3e33);sign.position=SCNVector3(11.8,3.5,-1.3);neon.addChildNode(sign)
        for z in [-3.1,-1.2,0.7] {
            let g=SCNTorus(ringRadius:0.55,pipeRadius:0.028);g.materials=[material(0xd3805d,glow:true)]
            let n=SCNNode(geometry:g);n.eulerAngles.z = NodeFloat.pi/2;n.position=SCNVector3(11.65,3.6,z);neon.addChildNode(n)
        }
        let light=SCNNode();light.light=SCNLight();light.light?.type = .omni;light.light?.color=rgb(0xe38962);light.light?.intensity=180;light.light?.attenuationEndDistance=10;light.position=SCNVector3(10,2.8,0);neon.addChildNode(light);decor.addChildNode(neon)
        var rng=ArtRandom(seed:213312)
        let litter=SCNNode()
        for _ in 0..<160 {
            let p=V2(x:rng.range(-11,11),y:rng.range(-7,7)),n=box(CGFloat(rng.range(0.05,0.18)),0.01,CGFloat(rng.range(0.08,0.24)),0xb6b5a1)
            n.position=SCNVector3(p.x,core.layout.height(p)+0.015,p.y);n.eulerAngles.y=NodeFloat(rng.range(0,6));litter.addChildNode(n)
        }
        decor.addChildNode(litter.flattenedClone())
    }
    func engineerModel()->SCNNode {
        let root=detailedCharacter(player:false,prisoner:true);root.scale=SCNVector3(0.95,0.95,0.95)
        let hardhat=ball(0.17,0xaa9b65);hardhat.scale=SCNVector3(1.1,0.65,1.05);hardhat.position=SCNVector3(0,1.47,0.01);(root.childNode(withName:"human-spine",recursively:false) ?? root).addChildNode(hardhat)
        let brim=cylinder(0.19,0.035,0x9d8e58);brim.position=SCNVector3(0,1.43,0.01);(root.childNode(withName:"human-spine",recursively:false) ?? root).addChildNode(brim)
        let tool=SCNNode();tool.name="engineer-wrench";let metal=material(0x939b91)
        tool.addChildNode(beam(SCNVector3(0.25,0.8,-0.3),SCNVector3(0.26,0.28,-0.37),radius:0.04,mat:metal))
        for side in [-1.0,1] {let jaw=box(0.05,0.17,0.08,0xa3aba1);jaw.position=SCNVector3(0.26+side*0.075,0.2,-0.37);tool.addChildNode(jaw)}
        let bridge=box(0.20,0.055,0.08,0xa3aba1);bridge.position=SCNVector3(0.26,0.29,-0.37);tool.addChildNode(bridge);(root.childNode(withName:"human-spine",recursively:false) ?? root).addChildNode(tool)
        return root
    }
}
