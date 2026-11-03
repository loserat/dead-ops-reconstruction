import Foundation
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ArcadeGame {
    func buildPrison() {
        let gravel=material(0x60635a);gravel.diffuse.contents=detailTexture(kind:"rock",base:0x60635a)
        if let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/prison-gravel-v07.png") {
            #if os(macOS)
            gravel.diffuse.contents=NSImage(contentsOf:url) ?? rgb(0x60635a)
            #else
            gravel.diffuse.contents=UIImage(contentsOfFile:url.path) ?? rgb(0x60635a)
            #endif
        }
        gravel.diffuse.wrapS = .repeat;gravel.diffuse.wrapT = .repeat;gravel.diffuse.contentsTransform=SCNMatrix4MakeScale(10,8,1)
        let ground=box(55,0.3,45,0x60635a);ground.position.y = -0.15;ground.geometry?.materials=[gravel];decor.addChildNode(ground)
        let rust=artMaterial("prison-metal",0x686957);rust.roughness.contents=0.65
        let frame=artMaterial("prison-frame",0x414d46)
        var rng=ArtRandom(seed:99312)
        let debris=SCNNode()
        for _ in 0..<450 {
            let x=rng.range(-8.8,8.8),z=rng.range(-5.3,5.3)
            if PrisonLayout.height(V2(x:x,y:z))>0.02 {continue}
            let chip=box(CGFloat(rng.range(0.035,0.12)),0.035,CGFloat(rng.range(0.04,0.12)),rng.next()<0.5 ? 0x7b7e70:0x464e43)
            chip.position=SCNVector3(x,0.018,z);chip.eulerAngles.y=NodeFloat(rng.range(0,6));debris.addChildNode(chip)
        }
        decor.addChildNode(debris.flattenedClone())
        func grate(_ x:Double,_ z:Double,_ w:Double,_ d:Double) {
            let root=SCNNode()
            for xx in stride(from:-w/2,through:w/2,by:0.24) {
                let bar=box(0.032,0.055,CGFloat(d),0x686957);bar.geometry?.materials=[rust];bar.position=SCNVector3(xx,PrisonLayout.deck-0.025,0);root.addChildNode(bar)
            }
            for zz in stride(from:-d/2,through:d/2,by:0.24) {
                let bar=box(CGFloat(w),0.055,0.032,0x686957);bar.geometry?.materials=[rust];bar.position=SCNVector3(0,PrisonLayout.deck-0.025,zz);root.addChildNode(bar)
            }
            for xx in [-w/2,w/2] {
                let bar=box(0.13,0.15,CGFloat(d),0x414d46);bar.geometry?.materials=[frame];bar.position=SCNVector3(xx,PrisonLayout.deck-0.08,0);root.addChildNode(bar)
            }
            root.position=SCNVector3(x,0,z);let model=root.flattenedClone();model.name="raised-catwalk";decor.addChildNode(model)
        }
        grate(-10.3,0,2.6,15.2);grate(10.3,0,2.6,15.2)
        grate(0,-6.55,18,2.1);grate(0,6.55,18,2.1)
        let structure=SCNNode()
        for side in [-1.0,1] {
            for z in [-6.0,-2,2,6] {
                structure.addChildNode(beam(SCNVector3(side*10.3,0,z),SCNVector3(side*10.3,1.52,z),radius:0.07,mat:frame))
            }
            for z in stride(from:-5.5,through:5.5,by:1.4) {
                structure.addChildNode(beam(SCNVector3(side*9,1.6,z),SCNVector3(side*9,2.35,z),radius:0.035,mat:rust))
            }
            for h in [1.92,2.35] {structure.addChildNode(beam(SCNVector3(side*9,h,-5.5),SCNVector3(side*9,h,5.5),radius:0.029,mat:rust))}
        }
        for z in [-5.5,5.5] {
            let gap=z<0 ? 1.35:1.7
            for side in [-1.0,1] {
                for h in [1.92,2.35] {structure.addChildNode(beam(SCNVector3(side*gap,h,z),SCNVector3(side*9,h,z),radius:0.029,mat:rust))}
                for x in stride(from:gap,through:9,by:1.3) {structure.addChildNode(beam(SCNVector3(side*x,1.6,z),SCNVector3(side*x,2.35,z),radius:0.035,mat:rust))}
            }
        }
        // Ten visible treads sit over the continuous walking slope used by the core.
        for i in 0..<10 {
            let h=Double(i+1)*0.16,z=PrisonLayout.stairFoot+(Double(i)+0.5)*0.26
            let tread=box(2.7,CGFloat(h),0.26,0x757b6d);tread.geometry?.materials=[rust];tread.position=SCNVector3(0,h/2,z);structure.addChildNode(tread)
            let nosing=box(2.7,0.025,0.045,0xb5b19a);nosing.position=SCNVector3(0,h+0.014,z-0.1);structure.addChildNode(nosing)
        }
        for p in PrisonLayout.railPosts {
            // Rail-post coordinates use the adjacent stair surface, rather than the floor beside it.
            let stairHeight=PrisonLayout.railHeight(p)
            structure.addChildNode(beam(SCNVector3(p.x,stairHeight,p.y),SCNVector3(p.x,stairHeight+0.75,p.y),radius:0.035,mat:rust))
        }
        for side in [-1.0,1] {structure.addChildNode(beam(SCNVector3(side*1.48,0.75,2.9),SCNVector3(side*1.48,2.35,5.5),radius:0.035,mat:rust))}
        decor.addChildNode(structure.flattenedClone())
        let fence=SCNNode(),wire=artMaterial("prison-wire",0x5e695f)
        for side in [-1.0,1] {
            for z in stride(from:-7.8,through:7.8,by:1.9) {fence.addChildNode(beam(SCNVector3(side*11.85,1.6,z),SCNVector3(side*11.85,3.7,z),radius:0.045,mat:frame))}
            for z in stride(from:-7.8,through:7.8,by:0.28) {fence.addChildNode(beam(SCNVector3(side*11.85,1.7,z),SCNVector3(side*11.85,3.45,z),radius:0.008,mat:wire))}
            for h in stride(from:1.7,through:3.45,by:0.28) {fence.addChildNode(beam(SCNVector3(side*11.85,h,-7.8),SCNVector3(side*11.85,h,7.8),radius:0.008,mat:wire))}
        }
        for x in stride(from:-11.8,through:11.8,by:1.9) {fence.addChildNode(beam(SCNVector3(x,1.6,-7.85),SCNVector3(x,3.7,-7.85),radius:0.045,mat:frame))}
        for h in [1.8,2.6,3.4] {fence.addChildNode(beam(SCNVector3(-11.8,h,-7.85),SCNVector3(11.8,h,-7.85),radius:0.016,mat:wire))}
        decor.addChildNode(fence.flattenedClone())
        for (i,p) in [V2(x:-7,y:3.5),V2(x:7,y:-3.5)].enumerated() {
            let r=jaggedRock(seed:UInt64(400+i),radius:i==0 ? 0.75:0.65);r.position=SCNVector3(p.x,0.25,p.y);decor.addChildNode(r)
        }
        let arrow=SCNNode(),gold=material(0xb8ad67)
        arrow.addChildNode(beam(SCNVector3(-0.35,1.65,-5.95),SCNVector3(0,1.65,-5.55),radius:0.04,mat:gold))
        arrow.addChildNode(beam(SCNVector3(0.35,1.65,-5.95),SCNVector3(0,1.65,-5.55),radius:0.04,mat:gold));decor.addChildNode(arrow)
    }
}
