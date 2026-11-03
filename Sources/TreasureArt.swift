import Foundation
import SceneKit
import SpriteKit

extension ArcadeGame {
    func treasureModel(_ appearance:LootAppearance,gemUnits:Int?=nil)->SCNNode {
        let root=SCNNode();root.name="loot-model"
        switch appearance {
        case .metal(let metal,let form):
            let color=metal == .gold ? 0xe2c16b:0xc2d1d1
            let mat=artMaterial("treasure-\(metal.rawValue)",color);mat.shininess=65;mat.specular.contents=rgb(0x8a8b7a)
            func bar(_ x:Double,_ y:Double,_ z:Double) {let n=box(0.28,0.09,0.16,color);n.geometry?.materials=[mat];n.position=SCNVector3(x,y,z);root.addChildNode(n)}
            switch form {
            case .bar:bar(0,0,0)
            case .stack:bar(-0.10,0,-0.07);bar(0.10,0,0.07);bar(0,0.09,0)
            case .coin,.medallion:
                let coin=cylinder(form == .coin ? 0.16:0.22,form == .coin ? 0.04:0.055,color);coin.geometry?.materials=[mat];root.addChildNode(coin)
                let seal=cylinder(0.075,0.017,metal == .gold ? 0xb18d36:0x7d969b);seal.position.y=0.034;root.addChildNode(seal)
                if form == .medallion {let ring=SCNTorus(ringRadius:0.17,pipeRadius:0.016);ring.materials=[mat];let n=SCNNode(geometry:ring);n.position.y=0.04;root.addChildNode(n)}
            case .insignia:
                for z in [-0.13,0.13] {let n=box(0.37,0.07,0.08,color);n.geometry?.materials=[mat];n.position.z=NodeFloat(z);root.addChildNode(n)}
                let n=box(0.37,0.07,0.075,color);n.geometry?.materials=[mat];n.eulerAngles.y = -0.70;root.addChildNode(n)
            }
        case .gem(let color,let size):
            let width=gemUnits.map{0.28*TreasureRules.gemScale($0)} ?? size.width,top=width*0.72,bottom = -width*0.36
            let mat=material(color.tint);mat.lightingModel = .blinn;mat.shininess=90;mat.specular.contents=rgb(0xffffff);mat.emission.contents=rgb(color.tint,0.16)
            for i in 0..<6 {
                let a=Double(i)*Double.pi/3,b=Double(i+1)*Double.pi/3
                let p=SCNVector3(cos(a)*width/2,0,sin(a)*width/2),q=SCNVector3(cos(b)*width/2,0,sin(b)*width/2)
                let upper=mesh([SCNVector3(0,top,0),q,p],[0,1,2],mat:mat)
                let lower=mesh([SCNVector3(0,bottom,0),p,q],[0,1,2],mat:mat)
                root.addChildNode(upper);root.addChildNode(lower)
            }
            root.name="gem-\(color.rawValue)-\(size.rawValue)"
        }
        return root
    }
    func syncPlayerColor() {
        guard appliedPlayerColor != selectedPlayerColor,let model=hero.childNodes.first else{return}
        appliedPlayerColor=selectedPlayerColor
        artMaterials[ownerMaterialKey("player-vehicle-badge")]?.diffuse.contents=rgb(selectedPlayerColor.tint)
        if let uniform=artMaterials[ownerMaterialKey("cloth-player")] {uniform.multiply.contents=rgb(selectedPlayerColor.tint);uniform.emission.contents=rgb(selectedPlayerColor.tint);uniform.emission.intensity=0.10}
        for name in ["player-helmet","player-marker","player-direction"] {
            if let mat=model.childNode(withName:name,recursively:true)?.geometry?.firstMaterial {mat.diffuse.contents=rgb(selectedPlayerColor.tint);mat.emission.contents=rgb(selectedPlayerColor.tint);mat.emission.intensity=0.18}
        }
    }
    func syncTreasureHUD() {
        let fraction=core.multiplierFill
        multiplierFill.path=CGPath(rect:CGRect(x:0,y:0,width:270*fraction,height:4),transform:nil)
        multiplierFill.fillColor=rgb(core.multiplier>=9 ? 0xffd77e:0xb9de83)
        nextLifeLabel.text=core.canGainDisplayedLife ? "NÄCHSTES LEBEN: \(core.pointsUntilLife.formatted(.number.locale(Locale(identifier:"de_DE")))) P":"LEBEN VOLL · 9"
    }
}
