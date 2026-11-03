import Foundation
import SceneKit

extension ArcadeGame {
    func buildSideRoomDetails() {
        guard let room=core.sideRoom else{return}
        if room.kind == .treasure {
            for p in core.layout.treasurePileCenters {
                let chest=treasureChest();chest.name="treasure-chest";chest.position=SCNVector3(p.x,core.layout.height(p)+0.08,p.y);decor.addChildNode(chest)
            }
        }else if room.kind == .armory {
            for side in [-1.0,1] {
                let rack=SCNNode(),metal=artMaterial("gunmetal",0x363c37)
                for z in [-1.45,1.45] {
                    let leg=box(0.10,1.4,0.10,0x4a544b);leg.geometry?.materials=[metal];leg.position=SCNVector3(0,0.7,z);rack.addChildNode(leg)
                }
                for h in [0.2,1.0] {
                    let rail=box(0.65,0.10,3.0,0x5f695c);rail.geometry?.materials=[metal];rail.position.y=NodeFloat(h);rack.addChildNode(rail)
                }
                for i in 0..<5 {
                    let gun=box(0.12,0.85,0.12,0x3a413a);gun.geometry?.materials=[metal];gun.position=SCNVector3(0.08,0.7,Double(i)*0.53-1.05);gun.eulerAngles.z=NodeFloat(side*0.22);rack.addChildNode(gun)
                }
                rack.position=SCNVector3(side*core.layout.armoryRackX,core.layout.height(V2(x:side*core.layout.armoryRackX,y:0))+0.06,0);let model=rack.flattenedClone();model.name="weapon-rack";decor.addChildNode(model)
            }
            for p in core.pickups {
                let plinth=stoneBlock(1.05,0.05,0.8,0x8c9388);plinth.position=SCNVector3(p.p.x,core.layout.height(p.p)+0.045,p.p.y);decor.addChildNode(plinth)
            }
        }
        if room.kind == .fate {buildFateSymbols()}
        // The sampled video reuses its arena for the discovered rooms, with cool illumination.
        for side in [-1.0,1] {
            let glow=SCNNode();glow.position=SCNVector3(side*6,2,0)
            glow.light=SCNLight();glow.light?.type = .omni;glow.light?.color=rgb(room.kind == .treasure ? 0xb4c8ff:0x96bce6)
            glow.light?.intensity=150;glow.light?.attenuationStartDistance=1;glow.light?.attenuationEndDistance=8
            decor.addChildNode(glow)
        }
    }
    func treasureChest()->SCNNode {
        let root=SCNNode(),wood=artMaterial("wood",0x74664e),metal=artMaterial("chest-metal",0x7b806d)
        let base=box(1.1,0.10,0.8,0x756b4e);base.geometry?.materials=[wood];base.position.y=0.05;root.addChildNode(base)
        for side in [-1.0,1] {
            let end=box(0.08,0.45,0.8,0x756b4e);end.geometry?.materials=[wood];end.position=SCNVector3(side*0.51,0.28,0);root.addChildNode(end)
            let wall=box(1.1,0.45,0.08,0x756b4e);wall.geometry?.materials=[wood];wall.position=SCNVector3(0,0.28,side*0.36);root.addChildNode(wall)
        }
        for x in [-0.34,0.34] {
            let strap=box(0.07,0.5,0.84,0x7b806d);strap.geometry?.materials=[metal];strap.position=SCNVector3(x,0.27,0);root.addChildNode(strap)
        }
        let hinge=SCNNode();hinge.position=SCNVector3(0,0.51,-0.4);hinge.eulerAngles.x = -1.02
        let lid=box(1.1,0.10,0.8,0x756b4e);lid.geometry?.materials=[wood];lid.position.z=0.4;hinge.addChildNode(lid);root.addChildNode(hinge)
        let gold=artMaterial("gold",0xd4b348)
        for i in 0..<18 {
            let coin=cylinder(0.065,0.04,0xd4b348);coin.geometry?.materials=[gold]
            coin.position=SCNVector3(Double(i%6)*0.13-0.33,0.3+Double(i%3)*0.04,Double(i/6)*0.17-0.15)
            root.addChildNode(coin)
        }
        return root.flattenedClone()
    }
    func buildSideExit() {
        let mat=material(0xe7c950,glow:true);mat.lightingModel = .constant
        for sign in [-1.0,1] {
            let n=beam(SCNVector3(-0.35,0.15,sign*0.45),SCNVector3(0.25,0.15,0),radius:0.055,mat:mat)
            n.castsShadow=false;sideExit.addChildNode(n)
        }
        scene.rootNode.addChildNode(sideExit);sideExit.isHidden=true
    }
}
