import Foundation
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ArcadeGame {
    func buildJungle() {
        let dirt=material(0x62634b)
        if let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/market-dirt-v09.png") {
            #if os(macOS)
            dirt.diffuse.contents=NSImage(contentsOf:url)
            #else
            dirt.diffuse.contents=UIImage(contentsOfFile:url.path)
            #endif
        }
        dirt.multiply.contents=rgb(0x7e8b65);dirt.diffuse.wrapS = .repeat;dirt.diffuse.wrapT = .repeat;dirt.diffuse.contentsTransform=SCNMatrix4MakeScale(6,5,1)
        let floor=box(46,0.3,36,0x525e40);floor.geometry?.materials=[dirt];floor.position.y = -0.18;decor.addChildNode(floor)
        var rng=ArtRandom(seed:371914)
        for side in [-1.0,1] {
            for i in 0..<8 {
                let z=Double(i)*2.4-8.4;if abs(z)<1.8 {continue}
                let rock=jaggedRock(seed:UInt64(370+i),radius:rng.range(1.0,1.5));rock.position=SCNVector3(side*12.7,0.7,z);decor.addChildNode(rock)
                let tree=palm(seed:UInt64(500+i),height:rng.range(4.4,6.4)).flattenedClone();tree.name="jungle-palm";tree.position=SCNVector3(side*rng.range(12.6,13.9),0,z);decor.addChildNode(tree)
            }
            for i in 0..<8 {
                let x=Double(i)*3.4-11.9
                if abs(x)<1.8 {continue}
                let tree=palm(seed:UInt64(650+i),height:rng.range(4.3,5.9)).flattenedClone();tree.name="jungle-palm";tree.position=SCNVector3(x,0,side*9.8);decor.addChildNode(tree)
            }
        }
        decor.addChildNode(jungleRocket())
        let rainMat=material(0x99b8cd);rainMat.lightingModel = .constant;rainMat.transparency=0.28
        for _ in 0..<170 {let n=box(0.013,0.75,0.013,0x99b8cd);n.geometry?.materials=[rainMat];n.position=SCNVector3(rng.range(-13,13),rng.range(0,10),rng.range(-9,9));n.eulerAngles.z = -0.17;n.castsShadow=false;rainNodes.append(n);decor.addChildNode(n)}
    }
    func jungleRocket()->SCNNode {
        let root=SCNNode(),steel=material(0x9ca68e);steel.specular.contents=rgb(0x455443);steel.shininess=25
        let base=box(1.7,0.25,1.7,0x616d53);base.position.y=0.12;root.addChildNode(base)
        let body=cylinder(0.74,4.8,0xa3ab95);body.geometry?.materials=[steel];body.position.y=2.64;root.addChildNode(body)
        for y in [1.1,2.6,4.35] {
            let band=cylinder(0.76,y==4.35 ? 0.45:0.11,y==4.35 ? 0xb9ad60:0x7a8a72);band.position.y=NodeFloat(y);root.addChildNode(band)
        }
        for x in [-0.29,0.29] {for z in [-0.29,0.29] {
            let tube=cylinder(0.24,0.6,0xa36e59);tube.position=SCNVector3(x,5.22,z);root.addChildNode(tube)
            let hole=cylinder(0.18,0.025,0x4d3d34);hole.position=SCNVector3(x,5.535,z);root.addChildNode(hole)
        }}
        let mat=material(0x566b4b)
        for side in [-1.0,1] {root.addChildNode(beam(SCNVector3(side*0.65,1.2,0),SCNVector3(side*1.0,0.15,0),radius:0.08,mat:mat))}
        let model=root.flattenedClone();model.name="jungle-rocket";return model
    }
    func silverbackModel()->SCNNode {
        let root=SCNNode(),fur=artMaterial("cloth-silverback",0x626f63),silver=artMaterial("cloth-silverback-patch",0x9ca89d)
        let belly=ball(0.69,0x626f63);belly.geometry?.materials=[fur];belly.scale=SCNVector3(1.0,1.25,0.80);belly.position.y=1.45;root.addChildNode(belly)
        let shoulders=ball(0.67,0x626f63);shoulders.geometry?.materials=[fur];shoulders.scale=SCNVector3(1.45,0.82,0.85);shoulders.position.y=2.1;root.addChildNode(shoulders)
        let back=ball(0.55,0x9ca89d);back.geometry?.materials=[silver];back.scale=SCNVector3(1.25,1.05,0.25);back.position=SCNVector3(0,2.05,0.49);root.addChildNode(back)
        let head=ball(0.37,0x778577);head.position=SCNVector3(0,2.72,-0.21);root.addChildNode(head)
        let brow=box(0.58,0.13,0.16,0x3d4b3e);brow.position=SCNVector3(0,2.83,-0.52);root.addChildNode(brow)
        let muzzle=box(0.44,0.32,0.27,0x3c493b);muzzle.position=SCNVector3(0,2.55,-0.57);root.addChildNode(muzzle)
        for side in [-1.0,1] {
            let eye=ball(0.055,0xc76648,glow:true);eye.position=SCNVector3(side*0.16,2.78,-0.57);root.addChildNode(eye)
            let arm=SCNNode();arm.name=side<0 ? "boss-arm-left":"boss-arm-right";arm.position=SCNVector3(side*0.72,2.02,0)
            arm.addChildNode(beam(SCNVector3Zero,SCNVector3(side*0.24,-1.45,-0.40),radius:0.24,mat:fur));let hand=ball(0.28,0x3b4a3b);hand.scale=SCNVector3(1,0.7,1.2);hand.position=SCNVector3(side*0.24,-1.50,-0.47);arm.addChildNode(hand);root.addChildNode(arm)
            let leg=SCNNode();leg.name=side<0 ? "boss-leg-left":"boss-leg-right";leg.position=SCNVector3(side*0.34,1.04,0.17)
            leg.addChildNode(beam(SCNVector3Zero,SCNVector3(side*0.05,-0.83,-0.03),radius:0.22,mat:fur));let foot=box(0.40,0.20,0.60,0x3d4a3d);foot.position=SCNVector3(side*0.05,-0.87,-0.15);leg.addChildNode(foot);root.addChildNode(leg)
            let pack=cylinder(0.20,0.95,0x9e5b46);pack.position=SCNVector3(side*0.47,1.93,0.65);root.addChildNode(pack)
        }
        let g=SCNTorus(ringRadius:1.05,pipeRadius:0.035);g.materials=[material(0xef8a5f,glow:true)];let warning=SCNNode(geometry:g);warning.name="boss-warning";warning.position.y=0.05;warning.isHidden=true;root.addChildNode(warning)
        return root
    }
    func animateBossModel(_ n:SCNNode,_ boss:Silverback) {
        n.position=SCNVector3(boss.p.x,boss.entryElevation+0.05,boss.p.y);n.eulerAngles.y=NodeFloat(atan2(-boss.facing.x,-boss.facing.y))
        if boss.hp>0 {
            n.eulerAngles.x=0
            for (i,name) in ["boss-arm-left","boss-arm-right","boss-leg-left","boss-leg-right"].enumerated() {n.childNode(withName:name,recursively:false)?.eulerAngles.x=NodeFloat(sin(boss.gait+Double(i%2)*Double.pi)*(i<2 ? 0.25:0.4))}
            n.childNode(withName:"boss-warning",recursively:false)?.isHidden=boss.motion != .windup
            n.childNode(withName:"boss-warning",recursively:false)?.opacity=CGFloat(0.6+0.4*sin(core.elapsed*15))
        }else{n.eulerAngles.x=NodeFloat(-min(1,boss.deathClock)*Double.pi/2);n.childNode(withName:"boss-warning",recursively:false)?.isHidden=true}
    }
    func syncSilverbackArt() {
        let intro=core.bossArrivalClock,titleAlpha=intro?.introductionOpacity ?? 0,subtitleAlpha=intro?.subtitleOpacity ?? 0
        bossIntroHUD.isHidden=core.phase != .playing || max(titleAlpha,subtitleAlpha)<=0
        bossIntroTitle.alpha=CGFloat(titleAlpha);bossIntroSubtitle.alpha=CGFloat(subtitleAlpha);bossIntroBackdrop.alpha=CGFloat(max(titleAlpha,subtitleAlpha))
        bossIntroSubtitle.text=core.bossCount==1 ? "THE COSMIC SILVERBACK":"\(core.bossCount) COSMIC SILVERBACKS"
        sync(&silverbackNodes,ids:Set(core.silverbacks.map(\.id)))
        for boss in core.silverbacks {
            let n=silverbackNodes[boss.id] ?? silverbackModel()
            if silverbackNodes[boss.id]==nil {silverbackNodes[boss.id]=n;actors.addChildNode(n)}
            animateBossModel(n,boss)
        }
        let alive=core.silverbacks.filter{$0.hp>0},total=core.silverbacks.reduce(0){$0+$1.hp}
        bossHUD.isHidden=alive.isEmpty || core.phase != .playing
        let fraction=total/(Silverback.maxHP*Double(max(1,core.silverbacks.count)))
        bossLabel.text=core.silverbacks.count==1 ? "COSMIC SILVERBACK · \(Int(ceil(fraction*100)))%":"SILVERBACKS \(alive.count)/\(core.silverbacks.count) · \(Int(ceil(fraction*100)))%"
        bossHealth.xScale=CGFloat(max(0,fraction))
    }
    func syncTreasureRaiderArt() {
        guard let raider=core.treasureRaider else{raiderNode?.removeFromParentNode();raiderNode=nil;return}
        if raiderNode==nil {
            let n=silverbackModel();n.name="treasure-raider"
            if let warning=n.childNode(withName:"boss-warning",recursively:false) {warning.geometry?.materials=[material(0xff5744,glow:true)];warning.name="invincible-raider-ring";warning.isHidden=false}
            let sack=ball(0.45,0x90734b);sack.name="stolen-treasure-sack";sack.scale=SCNVector3(0.8,1,0.65);sack.position=SCNVector3(-0.90,0.75,0.25);n.addChildNode(sack)
            for i in 0..<3 {let coin=treasureModel(.metal(.gold,.coin));coin.name="raider-cargo-\(i)";coin.position=SCNVector3(-0.90+Double(i-1)*0.15,1.13,0.25);n.addChildNode(coin)}
            raiderNode=n;actors.addChildNode(n)
        }
        let n=raiderNode!;n.position=SCNVector3(raider.p.x,raider.elevation+0.05,raider.p.y);n.eulerAngles.y=NodeFloat(atan2(-raider.facing.x,-raider.facing.y))
        for (i,name) in ["boss-arm-left","boss-arm-right","boss-leg-left","boss-leg-right"].enumerated() {
            n.childNode(withName:name,recursively:false)?.eulerAngles.x=NodeFloat(raider.motion == .roaring && i<2 ? -1.2:sin(raider.gait+Double(i%2)*Double.pi)*(i<2 ? 0.25:0.4))
        }
        n.childNode(withName:"invincible-raider-ring",recursively:false)?.opacity=CGFloat(raider.hitFlash>0 ? 1:0.7+0.3*sin(core.elapsed*9))
        n.childNode(withName:"stolen-treasure-sack",recursively:false)?.isHidden=raider.stolen==0
        for i in 0..<3 {n.childNode(withName:"raider-cargo-\(i)",recursively:false)?.isHidden=raider.stolen<=i}
    }
    func syncLoopReturnArt() {
        let victory=core.bossVictory
        let opacities=[victory?.titleOpacity ?? 0,victory?.subtitleOpacity ?? 0,victory?.brotherOpacity ?? 0]
        bossVictoryHUD.isHidden=core.phase != .cleared || opacities.max()!<=0
        bossVictoryTitle.alpha=CGFloat(opacities[0]);bossVictorySubtitle.alpha=CGFloat(opacities[1]);bossVictoryBrothers.alpha=CGFloat(opacities[2]);bossVictoryBackdrop.alpha=CGFloat(opacities.max()!)
        guard let transit=core.loopReturn else{loopVisitor?.removeFromParentNode();loopVisitor=nil;return}
        if loopVisitor==nil {loopVisitor=silverbackModel();actors.addChildNode(loopVisitor!)}
        let n=loopVisitor!;n.position=SCNVector3(transit.visitor.x,core.layout.height(transit.visitor)+transit.visitorHeight,transit.visitor.y)
        let d=core.hero-transit.visitor;n.eulerAngles.y=NodeFloat(atan2(-d.x,-d.y))
        n.childNode(withName:"boss-arm-right",recursively:false)?.eulerAngles.x=NodeFloat(transit.clock>0.9 && transit.clock<1.5 ? -1.3:0)
    }
}
