import Foundation
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ArcadeGame {
    func buildForest() {
        let floor=box(46,0.3,36,0xadb7ab);floor.position.y = -0.18;floor.geometry?.materials=[snowMaterial()];decor.addChildNode(floor)
        let edge=SCNNode();var rng=ArtRandom(seed:331914)
        for side in [-1.0,1] {
            for i in 0..<11 where abs(Double(i)*1.6-8)>1.8 {
                let tree=winterTree(seed:UInt64(i+50),height:rng.range(4.0,6.3));tree.position=SCNVector3(side*rng.range(12.2,13.6),0,Double(i)*1.6-8);edge.addChildNode(tree)
            }
            for i in 0..<13 {
                let x=Double(i)*2.15-12.9
                if abs(x)<1.5 {continue}
                let tree=winterTree(seed:UInt64(i+90),height:rng.range(4,6));tree.position=SCNVector3(x,0,side*9.2);edge.addChildNode(tree)
            }
        }
        edge.name="forest-tree-line";decor.addChildNode(edge)
        for (i,p) in ForestLayout.rocks.enumerated() {
            let stone=jaggedRock(seed:UInt64(3300+i),radius:0.55);stone.position=SCNVector3(p.x,0.30,p.y);decor.addChildNode(stone)
            let snow=ball(0.48,0xb9c6b9);snow.scale=SCNVector3(1,0.12,0.7);snow.position=SCNVector3(p.x,0.68,p.y);decor.addChildNode(snow)
        }
        decor.addChildNode(forestStatue())
        let flakes=material(0xd5e0dd);flakes.lightingModel = .constant;flakes.transparency=0.55
        for _ in 0..<130 {let n=ball(0.022,0xd5e0dd);n.geometry?.materials=[flakes];n.position=SCNVector3(rng.range(-13,13),rng.range(0,9),rng.range(-9,9));n.castsShadow=false;forestSnowNodes.append(n);decor.addChildNode(n)}
    }
    func winterTree(seed:UInt64,height:Double)->SCNNode {
        let root=SCNNode(),wood=artMaterial("bark",0x596050);var rng=ArtRandom(seed:seed)
        root.addChildNode(beam(SCNVector3Zero,SCNVector3(0.1,height*0.7,0),radius:0.13,mat:wood))
        if let crown=texturedWinterCrown(height:height) {
            crown.eulerAngles.y=NodeFloat(rng.range(0,Double.pi*2));root.addChildNode(crown)
            let model=root.flattenedClone();model.name="winter-tree";return model
        }
        for i in 0..<5 {
            let h=height*(0.23+Double(i)*0.135),radius=height*(0.27-Double(i)*0.036)
            let g=SCNCone(topRadius:0,bottomRadius:CGFloat(radius),height:CGFloat(height*0.38));g.radialSegmentCount=11;g.materials=[artMaterial("fir-\(i%2)",i%2==0 ? 0x4f6656:0x5c715e)]
            let n=SCNNode(geometry:g);n.position=SCNVector3(rng.range(-0.12,0.12),h,0);n.eulerAngles.y=NodeFloat(rng.range(0,6));root.addChildNode(n)
            let cap=SCNCone(topRadius:0,bottomRadius:CGFloat(radius*0.87),height:CGFloat(height*0.31));cap.radialSegmentCount=11;cap.materials=[artMaterial("fir-snow",0xc7d4c7)]
            let snow=SCNNode(geometry:cap);snow.position=SCNVector3(Double(n.position.x),h+height*0.055,0);snow.eulerAngles.y=n.eulerAngles.y;root.addChildNode(snow)
        }
        let model=root.flattenedClone();model.name="winter-tree";return model
    }
    func texturedWinterCrown(height:Double)->SCNNode? {
        guard let texture=foliageImage("winter-crown-v15.png") else{return nil}
        let key="textured-winter-crown",mat:SCNMaterial
        if let cached=artMaterials[key] {mat=cached}else{
            mat=SCNMaterial();mat.diffuse.contents=texture;mat.transparent.contents=texture
            mat.isDoubleSided=true;mat.lightingModel = .lambert;mat.transparencyMode = .aOne;mat.writesToDepthBuffer=true
            mat.diffuse.minificationFilter = .linear;mat.diffuse.magnificationFilter = .linear;mat.diffuse.mipFilter = .linear;mat.diffuse.maxAnisotropy=4;mat.name="foliage-cutout";mat.blendMode = .replace
            configureFoliageCutout(mat,image:texture);artMaterials[key]=mat
        }
        let count=12,size=height*0.85
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        for row in 0...count {for col in 0...count {
            let u=Double(col)/Double(count),v=Double(row)/Double(count),x=(u-0.5)*size,z=(v-0.5)*size
            let radius=min(1,(x*x+z*z)/(size*size*0.25)),y=height*(0.88-radius*0.28)
            vertices.append(SCNVector3(x,y,z));normals.append(SCNVector3(x*0.09,1,z*0.09));uv.append(CGPoint(x:u,y:v))
        }}
        for row in 0..<count {for col in 0..<count {let a=Int32(row*(count+1)+col),b=a+Int32(count+1);indices += [a,b,a+1,a+1,b,b+1]}}
        let node=mesh(vertices,indices,uv:uv,normals:normals,mat:mat);node.castsShadow=false;return node
    }
    func forestStatue()->SCNNode {
        let root=SCNNode(),stone=artMaterial("stone-forest-statue",0x7e826c)
        let base=cylinder(1,0.25,0x747c65);base.position.y=0.12;root.addChildNode(base)
        let plinth=box(1.15,0.48,1.15,0x7b826a);plinth.geometry?.materials=[stone];plinth.position.y=0.48;root.addChildNode(plinth)
        for side in [-1.0,1] {
            root.addChildNode(beam(SCNVector3(side*0.19,0.65,0),SCNVector3(side*0.15,1.7,0),radius:0.15,mat:stone))
            root.addChildNode(beam(SCNVector3(side*0.28,2.1,0),SCNVector3(side*0.69,1.67,-0.18),radius:0.11,mat:stone))
            let cup=cylinder(0.23,0.20,0x8a8e75);cup.position=SCNVector3(side*0.69,1.77,-0.18);root.addChildNode(cup)
        }
        let torso=box(0.65,0.82,0.44,0x85896f);torso.geometry?.materials=[stone];torso.position.y=1.87;root.addChildNode(torso)
        let head=ball(0.25,0x85896f);head.geometry?.materials=[stone];head.position.y=2.58;root.addChildNode(head)
        let hat=cylinder(0.29,0.22,0x7c8269);hat.position.y=2.85;root.addChildNode(hat)
        let model=root.flattenedClone();model.name="forest-statue";return model
    }
    func houndModel()->SCNNode {
        let root=SCNNode(),fur=artMaterial("cloth-hound",0x4b493b)
        let body=ball(0.25,0x4b493b);body.geometry?.materials=[fur];body.scale=SCNVector3(0.7,0.8,1.7);body.position.y=0.45;root.addChildNode(body)
        let neck=ball(0.20,0x514e40);neck.scale=SCNVector3(0.8,1.15,1);neck.position=SCNVector3(0,0.55,-0.30);root.addChildNode(neck)
        let head=ball(0.17,0x514e40);head.scale=SCNVector3(0.8,0.9,1.2);head.position=SCNVector3(0,0.62,-0.49);root.addChildNode(head)
        let muzzle=box(0.15,0.11,0.22,0x353d32);muzzle.position=SCNVector3(0,0.57,-0.69);root.addChildNode(muzzle)
        for side in [-1.0,1] {
            let g=SCNCone(topRadius:0,bottomRadius:0.065,height:0.20);g.radialSegmentCount=5;g.materials=[fur];let ear=SCNNode(geometry:g);ear.position=SCNVector3(side*0.11,0.81,-0.45);ear.eulerAngles.z=NodeFloat(side*0.25);root.addChildNode(ear)
            let eye=ball(0.018,0xa59b62);eye.position=SCNVector3(side*0.13,0.65,-0.57);root.addChildNode(eye)
        }
        for i in 0..<4 {
            let leg=SCNNode();leg.name="hound-leg-\(i)";leg.position=SCNVector3(i%2==0 ? -0.13:0.13,0.43,i<2 ? -0.26:0.27)
            leg.addChildNode(beam(SCNVector3Zero,SCNVector3(0,-0.33,0.07),radius:0.045,mat:fur));let foot=box(0.08,0.07,0.15,0x343d30);foot.position=SCNVector3(0,-0.34,0.02);leg.addChildNode(foot);root.addChildNode(leg)
        }
        root.addChildNode(beam(SCNVector3(0,0.53,0.35),SCNVector3(0,0.77,0.77),radius:0.045,mat:fur));return root
    }
    func animateHound(_ n:SCNNode,foe:Foe) {
        for i in 0..<4 {n.childNode(withName:"hound-leg-\(i)",recursively:false)?.eulerAngles.x=NodeFloat(sin(foe.gait+Double(i%2)*Double.pi+(i<2 ? 0:1.5))*0.65)}
    }
}
