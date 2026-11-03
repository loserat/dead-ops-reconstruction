import Foundation
import SceneKit

extension ArcadeGame {
    func heldWeapon(_ kind:PickupKind)->SCNNode {
        let root=weaponModel(kind);root.name="held-\(kind.rawValue)";root.position=SCNVector3(0.11,0.81,-0.37);return root
    }
    func flameJetModel(length:Double)->SCNNode {
        let root=SCNNode()
        for i in 0..<9 {
            let t=(Double(i)+0.5)/9,r=0.07+0.56*t
            let outer=ball(CGFloat(r),i%3==0 ? 0xec632c:0xf59935,glow:true)
            outer.position=SCNVector3(sin(Double(i)*5.3)*0.22*t,sin(Double(i)*2.4)*0.10*t,-0.30-length*t)
            outer.scale=SCNVector3(1,0.72,1.65);outer.opacity=CGFloat(0.48-0.20*t);outer.castsShadow=false
            outer.geometry?.firstMaterial?.writesToDepthBuffer=false;root.addChildNode(outer)
            let core=ball(CGFloat(r*0.53),i<4 ? 0xffefad:0xffc458,glow:true)
            core.position=outer.position;core.scale=SCNVector3(0.8,0.7,1.8);core.opacity=CGFloat(0.58-0.32*t);core.castsShadow=false
            core.geometry?.firstMaterial?.writesToDepthBuffer=false;root.addChildNode(core)
        }
        return root
    }
    func syncWeaponArt() {syncHeldWeaponArt();syncWorldWeaponArt()}
    func syncHeldWeaponArt() {
        if let model=hero.childNodes.first {
            for kind in [PickupKind.spread,.ray,.rocket,.grenade,.flamethrower] {
                let name="held-\(kind.rawValue)"
                let n=model.childNode(withName:name,recursively:false) ?? heldWeapon(kind)
                if n.parent==nil {model.addChildNode(n)}
                n.isHidden=core.activeWeapon != kind
            }
            model.childNodes.filter{$0.name=="standard-gun"}.forEach{$0.isHidden=core.activeWeapon != nil}
            let activeName=core.activeWeapon.map{$0 == .deathMachine ? "death-machine":"held-\($0.rawValue)"} ?? "standard-gun"
            if let active=model.childNode(withName:activeName,recursively:false),let anchor=active.childNode(withName:"weapon-muzzle",recursively:true) {model.childNode(withName:"muzzle",recursively:false)?.position=anchor.convertPosition(SCNVector3Zero,to:model)}
        }
    }
    func syncWorldWeaponArt() {
        sync(&flameJetNodes,ids:Set(core.flameJets.map(\.id)))
        for f in core.flameJets {
            let n=flameJetNodes[f.id] ?? flameJetModel(length:f.length)
            if flameJetNodes[f.id]==nil {flameJetNodes[f.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(f.p.x,f.height,f.p.y);n.eulerAngles.y=NodeFloat(atan2(-f.direction.x,-f.direction.y));n.opacity=CGFloat(min(1,f.ttl/0.08))
        }
        for f in core.foes {
            guard let n=foeNodes[f.id] else{continue}
            if f.burning>0 {
                let fire=n.childNode(withName:"burning",recursively:false) ?? ball(0.24,0xf4a44e,glow:true)
                fire.name="burning";fire.position.y=0.65;fire.scale=SCNVector3(0.8,1.8,0.8);fire.opacity=CGFloat(0.30+0.13*sin(core.elapsed*25+Double(f.id)));fire.castsShadow=false
                if fire.parent==nil {n.addChildNode(fire)}
            }else{n.childNode(withName:"burning",recursively:false)?.removeFromParentNode()}
        }
    }
}
