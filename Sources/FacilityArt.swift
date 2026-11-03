import Foundation
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ArcadeGame {
    func snowMaterial()->SCNMaterial {
        let mat=material(0xb4bdb4)
        if let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/snow-yard-v12.png") {
            #if os(macOS)
            mat.diffuse.contents=NSImage(contentsOf:url)
            #else
            mat.diffuse.contents=UIImage(contentsOfFile:url.path)
            #endif
        }
        mat.diffuse.wrapS = .repeat;mat.diffuse.wrapT = .repeat;mat.diffuse.contentsTransform=SCNMatrix4MakeScale(5,4,1)
        mat.specular.contents=rgb(0x1b2223);mat.shininess=10;return mat
    }
    func buildFacility() {
        let floor=box(45,0.3,34,0xa6b0a4);floor.position.y = -0.18;floor.geometry?.materials=[snowMaterial()];decor.addChildNode(floor)
        for p in FacilityLayout.tanks {let n=facilityTank();n.position=SCNVector3(p.x,0,p.y);decor.addChildNode(n)}
        let borders=SCNNode()
        for side in [-1.0,1] {
            for z in [-4.7,4.7] {
                let wall=stoneBlock(0.55,2.5,5.7,0x6c786c);wall.position=SCNVector3(side*12,1.05,z);borders.addChildNode(wall)
                let cap=box(0.67,0.10,5.8,0xc7d0c7);cap.position=SCNVector3(side*12,2.35,z);borders.addChildNode(cap)
            }
            for z in [-8.1,8.1] {
                let wall=stoneBlock(9.5,z<0 ? 2.2:0.45,0.55,0x7f8b7d);wall.position=SCNVector3(side*6.8,z<0 ? 0.95:0.13,z);borders.addChildNode(wall)
                let snow=box(9.6,0.08,0.65,0xcbd3ca);snow.position=SCNVector3(side*6.8,z<0 ? 2.1:0.4,z);borders.addChildNode(snow)
            }
            let bunk=stoneBlock(3.1,3.0,3.5,0x788576);bunk.position=SCNVector3(side*13.5,1.3,-7);borders.addChildNode(bunk)
            let shutter=box(0.06,1.8,1.45,0x3a4b42);shutter.position=SCNVector3(side*11.92,1.25,-6.7);borders.addChildNode(shutter)
            let roof=box(3.5,0.20,3.8,0xbec9be);roof.position=SCNVector3(side*13.5,2.9,-7);borders.addChildNode(roof)
        }
        let metal=material(0x708277)
        for x in [-11.5,11.5] {for z in [-3.0,3.0] {
            let pole=cylinder(0.10,4.6,0x5e7064);pole.position=SCNVector3(x,2.3,z);borders.addChildNode(pole)
            let arm=beam(SCNVector3(x,4.4,z),SCNVector3(x+(x<0 ? 0.8:-0.8),4.8,z),radius:0.065,mat:metal);borders.addChildNode(arm)
            let hood=box(0.55,0.16,0.27,0xaab6a4);hood.position=SCNVector3(x+(x<0 ? 0.8:-0.8),4.8,z);borders.addChildNode(hood)
        }}
        decor.addChildNode(borders.flattenedClone())
        let details=SCNNode();var rng=ArtRandom(seed:291320)
        for i in 0..<90 {
            let x=rng.range(-11,11),z=rng.range(-7,7)
            let pebble=box(CGFloat(rng.range(0.04,0.13)),0.045,CGFloat(rng.range(0.04,0.12)),i%3==0 ? 0x657368:0xa9b2a6);pebble.position=SCNVector3(x,0,z);details.addChildNode(pebble)
        }
        for x in [-10.4,-9.5] {for z in [-5.2,5.2] {
            let drum=cylinder(0.28,0.65,0x657a65);drum.position=SCNVector3(x,0.33,z);details.addChildNode(drum)
            let snow=cylinder(0.29,0.035,0xc8d3c7);snow.position=SCNVector3(x,0.675,z);details.addChildNode(snow)
        }}
        decor.addChildNode(details.flattenedClone())
    }
    func facilityTank()->SCNNode {
        let root=SCNNode(),shell=material(0xb7c4bd);shell.specular.contents=rgb(0x65716b);shell.shininess=35
        let g=SCNCapsule(capRadius:1.15,height:5.5);g.radialSegmentCount=32;g.heightSegmentCount=8;g.materials=[shell]
        let body=SCNNode(geometry:g);body.eulerAngles.x=NodeFloat.pi/2;body.position.y=1.20;root.addChildNode(body)
        let snow=SCNSphere(radius:1);snow.segmentCount=24;snow.materials=[material(0xd1dbd1)]
        let dust=SCNNode(geometry:snow);dust.scale=SCNVector3(1.02,0.15,2.18);dust.position=SCNVector3(0,2.22,0);root.addChildNode(dust)
        for z in [-1.4,1.4] {
            let leg=box(1.9,0.28,0.45,0x5b6f61);leg.position=SCNVector3(0,0.14,z);root.addChildNode(leg)
            let ring=SCNTorus(ringRadius:1.16,pipeRadius:0.035);ring.materials=[material(0x879b8f)];let n=SCNNode(geometry:ring);n.eulerAngles.x=NodeFloat.pi/2;n.position=SCNVector3(0,1.2,z);root.addChildNode(n)
        }
        let port=cylinder(0.33,0.16,0x7d9585);port.position=SCNVector3(0,2.37,1.1);root.addChildNode(port)
        let lid=cylinder(0.39,0.07,0xc1d0c1);lid.position=SCNVector3(0,2.49,1.1);root.addChildNode(lid)
        let pipeMat=material(0x768e7f);root.addChildNode(beam(SCNVector3(0,0.9,-2.5),SCNVector3(0,0.9,-3.1),radius:0.12,mat:pipeMat))
        let model=root.flattenedClone();model.name="facility-tank";return model
    }
    func sasquatchModel(explosive:Bool)->SCNNode {
        let root=SCNNode(),fur=artMaterial(explosive ? "cloth-martyr":"cloth-sasquatch",explosive ? 0x6e7053:0x79664e)
        let torso=ball(0.45,0x6e7053);torso.geometry?.materials=[fur];torso.scale=SCNVector3(1.0,1.30,0.75);torso.position.y=1.05;root.addChildNode(torso)
        let shoulders=ball(0.43,0x6e7053);shoulders.geometry?.materials=[fur];shoulders.scale=SCNVector3(1.42,0.72,0.85);shoulders.position.y=1.42;root.addChildNode(shoulders)
        let head=ball(0.24,0x746d57);head.position=SCNVector3(0,1.70,-0.14);root.addChildNode(head)
        let muzzle=box(0.25,0.16,0.16,0x4e5140);muzzle.position=SCNVector3(0,1.62,-0.35);root.addChildNode(muzzle)
        for side in [-1.0,1] {
            let leg=SCNNode();leg.name=side<0 ? "leftLeg":"rightLeg";leg.position=SCNVector3(side*0.20,0.72,0)
            leg.addChildNode(beam(SCNVector3Zero,SCNVector3(side*0.03,-0.58,-0.05),radius:0.15,mat:fur));let foot=box(0.27,0.16,0.42,0x414b39);foot.position=SCNVector3(side*0.03,-0.61,-0.16);leg.addChildNode(foot);root.addChildNode(leg)
            root.addChildNode(beam(SCNVector3(side*0.45,1.35,0),SCNVector3(side*0.55,0.58,-0.30),radius:0.16,mat:fur))
            let eye=ball(0.035,explosive ? 0xec6844:0x8a7656,glow:explosive);eye.position=SCNVector3(side*0.09,1.76,-0.34);root.addChildNode(eye)
        }
        if explosive {
            let pack=box(0.48,0.52,0.26,0x3b4637);pack.position=SCNVector3(0,1.0,0.39);root.addChildNode(pack)
            for i in 0..<3 {let charge=cylinder(0.085,0.36,0xb97449);charge.position=SCNVector3(Double(i-1)*0.13,1,0.57);root.addChildNode(charge)}
            let g=SCNTorus(ringRadius:0.64,pipeRadius:0.018);g.materials=[material(0xe86e49,glow:true)];let ring=SCNNode(geometry:g);ring.name="martyr-glow";ring.position.y=0.04;ring.opacity=0.45;root.addChildNode(ring)
        }
        return root
    }
}
