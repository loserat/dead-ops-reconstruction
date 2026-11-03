import Foundation
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ArcadeGame {
    func buildStreet() {
        let concrete=material(0x979989)
        if let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/urban-concrete-v10.png") {
            #if os(macOS)
            concrete.diffuse.contents=NSImage(contentsOf:url)
            #else
            concrete.diffuse.contents=UIImage(contentsOfFile:url.path)
            #endif
        }
        concrete.diffuse.wrapS = .repeat;concrete.diffuse.wrapT = .repeat;concrete.diffuse.contentsTransform=SCNMatrix4MakeScale(5,4,1)
        let floor=box(45,0.3,34,0x7a7f70);floor.position.y = -0.18;floor.geometry?.materials=[concrete];decor.addChildNode(floor)
        let slabs=SCNNode(),joint=material(0x51594e);joint.transparency=0.32
        for x in stride(from:-11.5,through:11.5,by:1.15) {
            let line=box(0.018,0.012,15.2,0x51594e);line.geometry?.materials=[joint];line.position=SCNVector3(x,0.008,0);slabs.addChildNode(line)
        }
        for z in stride(from:-7.5,through:7.5,by:1.15) {
            let line=box(23.2,0.012,0.018,0x51594e);line.geometry?.materials=[joint];line.position=SCNVector3(0,0.008,z);slabs.addChildNode(line)
        }
        let platform=box(3.6,1.4,4,0x8a8f80);platform.geometry?.materials=[concrete];platform.position=SCNVector3(9.8,0.7,0);slabs.addChildNode(platform)
        for side in [-1.0,1] {for i in 0..<12 {
            let h=1.4*Double(12-i)/12,step=box(3.6,CGFloat(h),0.25,0x858d81)
            step.position=SCNVector3(9.8,h/2,side*(2+(Double(i)+0.5)*0.25));slabs.addChildNode(step)
            let strip=box(3.6,0.02,0.035,0xb6baaa);strip.position=SCNVector3(9.8,h+0.013,side*(2+Double(i+1)*0.25));slabs.addChildNode(strip)
        }}
        for z in [-0.95,0.95] {
            let rail=box(0.12,0.48,1.6,0x7a8174);rail.position=SCNVector3(8,1.64,z);slabs.addChildNode(rail)
        }
        let borders=SCNNode()
        for side in [-1.0,1] {
            let opening=core.layout.entryCrossOffset(side:side<0 ? .west:.east)
            borders.addChildNode(sideFacadeWithOpening(x:side*13.25,span:14.8,width:2.8,height:4.4,base:-0.2,openingCenter:opening,color:0x707d6e))
            borders.addChildNode(sideFacadeWithOpening(x:side*13,span:14.9,width:3.3,height:0.12,base:4.24,openingCenter:opening,color:0x727d73))
            for z in stride(from:-7.1,through:7.1,by:0.32) where abs(z-opening)>1.8 {
                let rib=box(3.35,0.065,0.045,0xa4aa98);rib.position=SCNVector3(side*13.0,4.4,z);borders.addChildNode(rib)
            }
            for z in [-5.8,-1.9,1.9,5.8] where abs(z-opening)>1.8 {
                let door=box(0.06,1.7,1.0,0x454f44);door.position=SCNVector3(side*11.8,1.2,z);borders.addChildNode(door)
                let lintel=box(0.12,0.09,1.3,0xb1b09a);lintel.position=SCNVector3(side*11.75,2.1,z);borders.addChildNode(lintel)
            }
        }
        for side in [-1.0,1] {for z in [-8.1,8.1] {
            let wall=stoneBlock(9.5,z<0 ? 2.6:0.5,0.65,0x93927a);wall.position=SCNVector3(side*6.9,z<0 ? 1.1:0.15,z);borders.addChildNode(wall)
            for i in 0..<7 {let pot=cylinder(0.21,0.4,i%2==0 ? 0x9d7860:0x647a52);pot.position=SCNVector3(side*(3+Double(i)*1.2),z<0 ? 2.6:0.6,z);borders.addChildNode(pot)}
        }}
        let crate=marketCrate();crate.position=SCNVector3(-10,0,0);borders.addChildNode(crate)
        decor.addChildNode(slabs.flattenedClone());decor.addChildNode(borders.flattenedClone())
        let clutter=SCNNode();var rng=ArtRandom(seed:251318)
        for _ in 0..<160 {
            let p=V2(x:rng.range(-11,11),y:rng.range(-7,7)),n=box(CGFloat(rng.range(0.04,0.16)),0.012,CGFloat(rng.range(0.08,0.24)),0xb8baa7)
            n.position=SCNVector3(p.x,core.layout.height(p)+0.02,p.y);n.eulerAngles.y=NodeFloat(rng.range(0,6));clutter.addChildNode(n)
        }
        decor.addChildNode(clutter.flattenedClone())
        let cable=material(0x38463a)
        for x in [-4.0,4] {
            var last=SCNVector3(x,4.8,-8.3)
            for i in 1...24 {let z=Double(i)*16.6/24-8.3,p=SCNVector3(x,4.1+0.7*pow(z/8.3,2),z);decor.addChildNode(beam(last,p,radius:0.015,mat:cable));last=p}
        }
    }
    func flamingBarrelModel()->SCNNode {
        let root=SCNNode(),body=SCNNode();body.name="barrel-body"
        let drum=cylinder(0.34,0.76,0x68523f);drum.eulerAngles.z=NodeFloat.pi/2;body.addChildNode(drum)
        for x in [-0.27,0.27] {
            let g=SCNTorus(ringRadius:0.345,pipeRadius:0.027);g.materials=[material(0x92927b)]
            let n=SCNNode(geometry:g);n.eulerAngles.z=NodeFloat.pi/2;n.position.x=NodeFloat(x);body.addChildNode(n)
        }
        root.addChildNode(body)
        let flames=SCNNode();flames.name="barrel-flames"
        for i in 0..<5 {let n=ball(CGFloat(0.11+Double(i%2)*0.03),i%2==0 ? 0xf7ba55:0xd46b34,glow:true);n.position=SCNVector3(Double(i%3)*0.17-0.17,0.3+Double(i%2)*0.12,Double(i/3)*0.18-0.1);n.scale=SCNVector3(0.7,2.2,0.7);n.castsShadow=false;flames.addChildNode(n)}
        root.addChildNode(flames)
        let light=SCNNode();light.light=SCNLight();light.light?.type = .omni;light.light?.color=rgb(0xe9a05a);light.light?.intensity=90;light.light?.attenuationStartDistance=0.4;light.light?.attenuationEndDistance=3.5;light.position.y=0.4;root.addChildNode(light)
        return root
    }
    func syncBarrelArt() {
        sync(&barrelNodes,ids:Set(core.barrels.map(\.id)))
        for barrel in core.barrels {
            let n=barrelNodes[barrel.id] ?? flamingBarrelModel()
            if barrelNodes[barrel.id]==nil {barrelNodes[barrel.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(barrel.p.x,barrel.elevation+0.35,barrel.p.y);n.eulerAngles.y=NodeFloat(atan2(barrel.v.x,barrel.v.y))
            n.childNode(withName:"barrel-body",recursively:false)?.eulerAngles.x=NodeFloat(barrel.spin)
            n.childNode(withName:"barrel-flames",recursively:false)?.scale.y=NodeFloat(0.9+0.17*sin(core.elapsed*18+Double(barrel.id)))
        }
    }
}
