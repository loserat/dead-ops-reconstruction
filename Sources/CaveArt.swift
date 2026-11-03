import Foundation
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ArcadeGame {
    func buildCave() {
        let exterior=box(40,0.35,30,0x3b4935)
        let earth=artMaterial("ground",0x55563a).copy() as! SCNMaterial;earth.diffuse.contentsTransform=SCNMatrix4MakeScale(8,6,1);earth.multiply.contents=rgb(0x6f7c65)
        exterior.geometry?.materials=[earth];exterior.position.y = -0.22;decor.addChildNode(exterior)
        let floor=box(18.8,0.3,12.8,0x777c70),stone=material(0x777c70)
        if let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/cave-stone-v08.png") {
            #if os(macOS)
            stone.diffuse.contents=NSImage(contentsOf:url) ?? rgb(0x777c70)
            #else
            stone.diffuse.contents=UIImage(contentsOfFile:url.path) ?? rgb(0x777c70)
            #endif
        }
        stone.diffuse.wrapS = .repeat;stone.diffuse.wrapT = .repeat;stone.diffuse.contentsTransform=SCNMatrix4MakeScale(4.2,3,1)
        floor.position.y = -0.15;floor.geometry?.materials=[stone];decor.addChildNode(floor)
        let walls=SCNNode();var rng=ArtRandom(seed:88102)
        for row in 0..<5 {
            for i in -12...12 {
                let x=Double(i)*0.77+(row%2==0 ? 0:0.38)
                guard abs(x)<9.5 && abs(x)>1.45 else{continue}
                let brick=stoneBlock(0.73,0.64,0.85,[0x59604b,0x656b56,0x626554][abs(i+row)%3])
                brick.position=SCNVector3(x,Double(row)*0.66+0.3,-6.45);brick.eulerAngles.y=NodeFloat(rng.range(-0.025,0.025));walls.addChildNode(brick)
                if row==0 {
                    let front=stoneBlock(0.73,0.64,0.85,0x59604b);front.position=SCNVector3(x,0.3,6.45);walls.addChildNode(front)
                }
            }
            for side in [-1.0,1] {for j in -8...8 {
                let z=Double(j)*0.75+(row%2==0 ? 0:0.35);if abs(z)<1.7 {continue}
                let brick=stoneBlock(0.8,0.64,0.72,0x5c634e);brick.position=SCNVector3(side*9.45,Double(row)*0.66+0.3,z);walls.addChildNode(brick)
            }}
        }
        for side in [-1.0,1] {for z in [-6.65,6.65] {
            let tower=stoneBlock(1.15,3.6,1.15,0x535d46);tower.position=SCNVector3(side*9.65,1.6,z);walls.addChildNode(tower)
            for h in [0.3,2.9] {let cap=stoneBlock(1.3,0.16,1.3,0x6d745b);cap.position=SCNVector3(side*9.65,h,z);walls.addChildNode(cap)}
        }}
        decor.addChildNode(walls.flattenedClone())
        let roots=SCNNode(),rootMat=artMaterial("cave-roots",0x3c4a2e)
        for side in [-1.0,1] {for i in 0..<9 {
            let z=Double(i)*1.3-5.2
            var last=SCNVector3(side*9.0,2.9,z)
            for segment in 1...7 {
                let t=Double(segment)/7,p=SCNVector3(side*(9.0-rng.range(0,0.6)*t),2.9*(1-t),z+rng.range(-0.2,0.2))
                roots.addChildNode(beam(last,p,radius:CGFloat(0.025+(1-t)*0.035),mat:rootMat));last=p
            }
        }}
        decor.addChildNode(roots.flattenedClone())
        decor.addChildNode(caveStatue())
        for side in [-1.0,1] {for z in [-3.8,3.8] {
            let torch=SCNNode();torch.name="cave-torch";torch.position=SCNVector3(side*9.1,0,z)
            let holder=box(0.13,0.9,0.13,0x383e2c);holder.position.y=1.5;torch.addChildNode(holder)
            let flame=ball(0.15,0xf3a548,glow:true);flame.name="flame";flame.scale=SCNVector3(0.6,1.5,0.6);flame.position.y=2.02;torch.addChildNode(flame)
            let light=SCNNode();light.light=SCNLight();light.light?.type = .omni;light.light?.color=rgb(0xf1ad5f);light.light?.intensity=105
            light.light?.attenuationStartDistance=0.4;light.light?.attenuationEndDistance=5.5;light.position.y=2.0;torch.addChildNode(light);decor.addChildNode(torch)
        }}
        let rainMaterial=material(0xaec2d4);rainMaterial.lightingModel = .constant;rainMaterial.transparency=0.26
        for _ in 0..<150 {
            let n=box(0.012,0.65,0.012,0xaec2d4);n.geometry?.materials=[rainMaterial];n.castsShadow=false
            n.position=SCNVector3(rng.range(-10,10),rng.range(0,10),rng.range(-7,7));n.eulerAngles.z = -0.2;rainNodes.append(n);decor.addChildNode(n)
        }
    }
    func caveStatue()->SCNNode {
        let root=SCNNode(),stone=artMaterial("stone-cave-statue",0x5a624c)
        for (r,h,y) in [(0.88,0.18,0.1),(0.67,0.22,0.3),(0.43,1.6,1.2),(0.62,0.17,2.08)] {
            let n=cylinder(CGFloat(r),CGFloat(h),0x5a624c);n.geometry?.materials=[stone];n.position.y=NodeFloat(y);root.addChildNode(n)
        }
        for i in 0..<8 {
            let g=SCNTorus(ringRadius:0.43,pipeRadius:0.055);g.materials=[stone]
            let n=SCNNode(geometry:g);n.position.y=NodeFloat(0.55+Double(i)*0.18);root.addChildNode(n)
        }
        let head=box(0.83,0.58,0.76,0x5a624c);head.geometry?.materials=[stone];head.position.y=2.43;root.addChildNode(head)
        for side in [-1.0,1] {
            let eye=box(0.15,0.11,0.025,0x222e21);eye.position=SCNVector3(side*0.20,2.52,-0.39);root.addChildNode(eye)
            let brow=stoneBlock(0.28,0.09,0.12,0x71755e);brow.position=SCNVector3(side*0.19,2.64,-0.40);root.addChildNode(brow)
        }
        let mouth=box(0.42,0.09,0.03,0x2e3827);mouth.position=SCNVector3(0,2.29,-0.39);root.addChildNode(mouth)
        let model=root.flattenedClone();model.name="cave-statue";return model
    }
    func crawlerModel()->SCNNode {
        let root=SCNNode(),skin=artMaterial("crawler-skin",0x747b61)
        let body=ball(0.24,0x747b61);body.geometry?.materials=[skin];body.scale=SCNVector3(0.8,0.55,1.4);body.position.y=0.32;root.addChildNode(body)
        let head=ball(0.13,0x929a75);head.scale=SCNVector3(0.9,0.75,1.05);head.position=SCNVector3(0,0.31,-0.36);root.addChildNode(head)
        for i in 0..<4 {
            let side=i%2==0 ? -1.0:1.0,front=i<2
            let leg=SCNNode();leg.name="crawler-leg-\(i)";leg.position=SCNVector3(side*0.14,0.30,front ? -0.12:0.17)
            let knee=SCNVector3(side*0.23,-0.10,front ? -0.23:0.19),foot=SCNVector3(side*0.31,-0.29,front ? -0.38:0.32)
            leg.addChildNode(beam(SCNVector3Zero,knee,radius:front ? 0.055:0.07,mat:skin));leg.addChildNode(beam(knee,foot,radius:0.04,mat:skin));root.addChildNode(leg)
        }
        return root
    }
    func animateCrawler(_ n:SCNNode,foe:Foe) {
        let idle=foe.behaviorClock.truncatingRemainder(dividingBy:2.6)<0.7
        for i in 0..<4 {n.childNode(withName:"crawler-leg-\(i)",recursively:false)?.eulerAngles.y=idle ? 0:NodeFloat(sin(foe.gait+Double(i)*Double.pi/2)*0.5)}
    }
}
