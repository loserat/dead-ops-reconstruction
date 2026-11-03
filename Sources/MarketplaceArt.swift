import Foundation
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ArcadeGame {
    func buildMarketplace() {
        var rng=ArtRandom(seed:174914)
        let floor=box(48,0.3,38,0x61553c);floor.position.y = -0.18
        let dirt=material(0x9b8967)
        if let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/market-dirt-v09.png") {
            #if os(macOS)
            dirt.diffuse.contents=NSImage(contentsOf:url) ?? rgb(0x9b8967)
            #else
            dirt.diffuse.contents=UIImage(contentsOfFile:url.path) ?? rgb(0x9b8967)
            #endif
        }
        dirt.diffuse.wrapS = .repeat;dirt.diffuse.wrapT = .repeat;dirt.diffuse.contentsTransform=SCNMatrix4MakeScale(6,5,1)
        floor.geometry?.materials=[dirt];decor.addChildNode(floor)
        let groundDetails=SCNNode()
        for i in 0..<450 {
            let x=rng.range(-12.1,12.1),z=rng.range(-8.1,8.1)
            let pebble=box(CGFloat(rng.range(0.025,0.10)),0.025,CGFloat(rng.range(0.02,0.12)),i%3==0 ? 0x6c6452:0xb2a58a)
            pebble.position=SCNVector3(x,0,z);pebble.eulerAngles.y=NodeFloat(rng.range(0,6));groundDetails.addChildNode(pebble)
        }
        let rut=material(0x6d6048);rut.transparency=0.32
        for direction in [-0.42,0.31] {for offset in [-0.6,0.6] {
            var last=SCNVector3(-12,0.01,-12*direction+offset)
            for i in 1...45 {
                let x=Double(i)*24/45-12,p=SCNVector3(x,0.01,x*direction+offset+sin(x*0.6)*0.12)
                let line=beam(last,p,radius:0.025,mat:rut);line.scale.y=0.5;groundDetails.addChildNode(line);last=p
            }
        }}
        decor.addChildNode(groundDetails.flattenedClone())
        for side in [-1.0,1] {for z in [-5.4,5.4] {
            let stall=marketStall(seed:UInt64(120+Int(z+6)),cloth:side<0 ? 0x77816a:0x8b7556)
            stall.position=SCNVector3(side*13.4,0,z);stall.eulerAngles.y=side<0 ? NodeFloat.pi/2:-NodeFloat.pi/2;decor.addChildNode(stall)
        }}
        for x in [-8.5,-4.5,4.5,8.5] {
            let stall=marketStall(seed:UInt64(200+Int(x+10)),cloth:x<0 ? 0x82785b:0x69786a)
            stall.position=SCNVector3(x,0,-9.5);decor.addChildNode(stall)
        }
        let perimeter=SCNNode()
        for side in [-1.0,1] {
            for z in [-4.8,4.8] {
                let facade=stoneBlock(1.2,2.5,5.8,0x9a8c6f);facade.position=SCNVector3(side*15.3,1.1,z);perimeter.addChildNode(facade)
                for i in 0..<3 {
                    let shutter=box(0.08,0.95,0.7,0x555a45);shutter.position=SCNVector3(side*14.64,1.5,z+Double(i-1)*1.4);perimeter.addChildNode(shutter)
                }
            }
            // Leave all four lane mouths open for the crossing herds.
            for z in [-8.4,8.4] {
                let fence=box(9.4,z<0 ? 1.4:0.45,0.17,0x665f49);fence.geometry?.materials=[artMaterial("wood",0x74664e)]
                fence.position=SCNVector3(side*7.4,z<0 ? 0.65:0.18,z);perimeter.addChildNode(fence)
            }
        }
        for (i,p) in MarketplaceLayout.crates.enumerated() {
            let crate=marketCrate();crate.position=SCNVector3(p.x,0,p.y);perimeter.addChildNode(crate)
            if i%2==0 {let bag=ball(0.35,0x9f9474);bag.scale=SCNVector3(0.8,0.65,1);bag.position=SCNVector3(p.x,1,p.y);perimeter.addChildNode(bag)}
        }
        decor.addChildNode(perimeter.flattenedClone())
        let wireMat=material(0x363c32)
        for z in [-3.0,3.0] {
            for side in [-1.0,1] {let pole=cylinder(0.09,4.4,0x514c3a);pole.position=SCNVector3(side*12.7,2.2,z);decor.addChildNode(pole)}
            var last=SCNVector3(-12.7,4.3,z)
            for i in 1...24 {
                let x=Double(i)*25.4/24-12.7,p=SCNVector3(x,3.7+0.6*pow(x/12.7,2),z)
                let wire=beam(last,p,radius:0.018,mat:wireMat);wire.castsShadow=true;decor.addChildNode(wire);last=p
            }
        }
    }
    func marketCrate()->SCNNode {
        let root=SCNNode(),wood=artMaterial("wood",0x74664e)
        let body=box(1.2,0.9,1.3,0x86785a);body.geometry?.materials=[wood];body.position.y=0.45;root.addChildNode(body)
        for side in [-1.0,1] {
            for h in [0.1,0.78] {let band=box(1.24,0.09,0.055,0xaca084);band.position=SCNVector3(0,h,side*0.67);root.addChildNode(band)}
            let cross=beam(SCNVector3(-0.5,0.14,side*0.68),SCNVector3(0.5,0.74,side*0.68),radius:0.055,mat:wood);root.addChildNode(cross)
        }
        return root.flattenedClone()
    }
    func marketStall(seed:UInt64,cloth:Int)->SCNNode {
        let root=SCNNode(),wood=artMaterial("wood",0x74664e)
        for x in [-1.35,1.35] {for z in [-0.85,0.85] {
            root.addChildNode(beam(SCNVector3(x,0,z),SCNVector3(x,2.5,z),radius:0.06,mat:wood))
        }}
        let counter=box(2.9,0.16,1.7,0x7c7257);counter.geometry?.materials=[wood];counter.position.y=0.95;root.addChildNode(counter)
        let roof=box(3.25,0.08,2.15,cloth);roof.geometry?.materials=[artMaterial("cloth-market-\(cloth)",cloth)];roof.position=SCNVector3(0,2.4,0);roof.eulerAngles.x=0.10;root.addChildNode(roof)
        for i in 0..<10 {let rib=box(0.04,0.03,2.17,0x4d5448);rib.position=SCNVector3(Double(i)*0.31-1.4,2.46,0);rib.eulerAngles.x=0.10;root.addChildNode(rib)}
        var rng=ArtRandom(seed:seed)
        for i in 0..<12 {
            let produce=ball(CGFloat(rng.range(0.10,0.16)),i%3==0 ? 0x687341:0xa48852);produce.position=SCNVector3(rng.range(-1.15,1.15),1.13,rng.range(-0.65,0.65));root.addChildNode(produce)
        }
        return root.flattenedClone()
    }
    func bullModel(golden:Bool)->SCNNode {
        let root=SCNNode(),skin=artMaterial(golden ? "cloth-gold-bull":"cloth-ox",golden ? 0xb6a365:0x8c9286)
        let body=ball(0.52,0x8c9286);body.geometry?.materials=[skin];body.scale=SCNVector3(0.82,0.85,1.65);body.position.y=0.85;root.addChildNode(body)
        let shoulder=ball(0.40,0x8c9286);shoulder.geometry?.materials=[skin];shoulder.position=SCNVector3(0,1.02,-0.35);root.addChildNode(shoulder)
        let head=box(0.50,0.48,0.56,golden ? 0xc4b273:0x7c8477);head.position=SCNVector3(0,0.92,-0.82);root.addChildNode(head)
        let nose=box(0.43,0.21,0.22,0x4a5046);nose.position=SCNVector3(0,0.76,-1.13);root.addChildNode(nose)
        let hornMat=material(0xd4cab0)
        for side in [-1.0,1] {
            root.addChildNode(beam(SCNVector3(side*0.20,1.11,-0.82),SCNVector3(side*0.57,1.17,-0.80),radius:0.065,mat:hornMat))
            root.addChildNode(beam(SCNVector3(side*0.57,1.17,-0.80),SCNVector3(side*0.64,1.39,-0.88),radius:0.035,mat:hornMat))
            let eye=ball(0.04,0x252a22);eye.position=SCNVector3(side*0.255,1.01,-1.02);root.addChildNode(eye)
        }
        for i in 0..<4 {
            let leg=SCNNode();leg.name="bull-leg-\(i)";leg.position=SCNVector3(i%2==0 ? -0.29:0.29,0.70,i<2 ? -0.43:0.45)
            leg.addChildNode(beam(SCNVector3Zero,SCNVector3(0,-0.54,0.06),radius:0.09,mat:skin))
            let hoof=box(0.19,0.14,0.26,0x3b4137);hoof.position=SCNVector3(0,-0.59,0.02);leg.addChildNode(hoof);root.addChildNode(leg)
        }
        root.addChildNode(beam(SCNVector3(0,0.95,0.73),SCNVector3(0,0.45,1.15),radius:0.035,mat:skin))
        let dustMat=material(golden ? 0xf4d775:0xc2b68b);dustMat.lightingModel = .constant;dustMat.transparency=0.20
        let dust=SCNNode();dust.name="bull-dust"
        for i in 0..<5 {let n=ball(CGFloat(0.15+Double(i)*0.07),0xc2b68b);n.geometry?.materials=[dustMat];n.position=SCNVector3(Double(i%2)*0.3-0.15,0.12,0.9+Double(i)*0.4);n.scale.y=0.5;n.castsShadow=false;dust.addChildNode(n)}
        root.addChildNode(dust)
        if golden {
            let aura=SCNTorus(ringRadius:0.68,pipeRadius:0.025);aura.materials=[material(0xf4d875,glow:true)]
            let n=SCNNode(geometry:aura);n.position.y=0.12;root.addChildNode(n)
        }
        return root
    }
    func syncBullArt() {
        sync(&bullNodes,ids:Set(core.bulls.map(\.id)))
        for bull in core.bulls {
            let n=bullNodes[bull.id] ?? bullModel(golden:bull.golden)
            if bullNodes[bull.id]==nil {bullNodes[bull.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(bull.p.x,0.03,bull.p.y);n.eulerAngles.y=NodeFloat(atan2(-bull.direction.x,-bull.direction.y))
            for i in 0..<4 {n.childNode(withName:"bull-leg-\(i)",recursively:false)?.eulerAngles.x=NodeFloat(sin(bull.gait+Double(i%2)*Double.pi+(i<2 ? 0:Double.pi*0.5))*0.55)}
            n.childNode(withName:"bull-dust",recursively:false)?.opacity=CGFloat(0.65+sin(core.elapsed*12+Double(bull.id))*0.25)
        }
    }
}
