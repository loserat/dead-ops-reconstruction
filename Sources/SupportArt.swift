import Foundation
import SceneKit

extension ArcadeGame {
    func supportBlastModel(dust:Bool)->SCNNode {
        let root=SCNNode();root.name=dust ? "landing-dust":"weapon-blast"
        for i in 0..<12 {
            let a=Double(i)*2.399,r=0.16+Double(i%4)*0.085
            let puff=ball(CGFloat(0.12+Double(i%3)*0.025),dust ? 0xb9ad8d:i<6 ? 0xffb762:0x5b6255,glow:!dust && i<6)
            let mat=puff.geometry!.firstMaterial!;mat.blendMode = .alpha;mat.writesToDepthBuffer=false;mat.transparency=dust ? 0.18:i<6 ? 0.27:0.17
            puff.position=SCNVector3(cos(a)*r,Double(i%3)*0.065,sin(a)*r);puff.scale=SCNVector3(1,0.6,1);puff.castsShadow=false;root.addChildNode(puff)
        }
        let ring=SCNTorus(ringRadius:0.46,pipeRadius:0.011);let mat=material(dust ? 0xc4b899:0xffcc82,glow:!dust);mat.transparency=0.25;mat.blendMode = .alpha;mat.writesToDepthBuffer=false;ring.materials=[mat]
        let n=SCNNode(geometry:ring);n.castsShadow=false;root.addChildNode(n)
        return root
    }
    func teddyModel()->SCNNode {
        let root=SCNNode();root.name="teddy-model"
        let body=ball(0.25,0xaa7c4c);body.scale=SCNVector3(0.85,1.15,0.75);body.position.y=0.30;root.addChildNode(body)
        let belly=ball(0.16,0xd7b57e);belly.scale=SCNVector3(1,1.1,0.28);belly.position=SCNVector3(0,0.29,-0.16);root.addChildNode(belly)
        let head=ball(0.22,0xbb8f5b);head.position.y=0.65;root.addChildNode(head)
        for side in [-1.0,1] {
            let ear=ball(0.085,0x987047);ear.position=SCNVector3(side*0.16,0.82,0);root.addChildNode(ear)
            let eye=ball(0.026,0x282d24);eye.position=SCNVector3(side*0.075,0.69,-0.19);root.addChildNode(eye)
            let arm=ball(0.10,0xaa7c4c);arm.scale=SCNVector3(1,1.5,1);arm.position=SCNVector3(side*0.25,0.36,0);root.addChildNode(arm)
            let foot=ball(0.12,0x9f7548);foot.position=SCNVector3(side*0.14,0.09,-0.08);root.addChildNode(foot)
        }
        let snout=ball(0.087,0xe0c08b);snout.scale=SCNVector3(1,0.8,0.8);snout.position=SCNVector3(0,0.61,-0.21);root.addChildNode(snout)
        let nose=ball(0.032,0x463d2c);nose.position=SCNVector3(0,0.63,-0.285);root.addChildNode(nose)
        let bow=box(0.23,0.07,0.07,0xb45c46);bow.position=SCNVector3(0,0.48,-0.18);root.addChildNode(bow)
        return root
    }
    func monkeyModel()->SCNNode {
        let root=SCNNode();root.name="monkey-model"
        let body=ball(0.26,0x895e42);body.scale=SCNVector3(0.9,0.7,1.2);body.position.y=0.21;root.addChildNode(body)
        let vest=box(0.38,0.12,0.32,0xa34c43);vest.position=SCNVector3(0,0.30,0.06);root.addChildNode(vest)
        let head=ball(0.21,0xb18c61);head.position=SCNVector3(0,0.27,-0.32);root.addChildNode(head)
        let face=ball(0.15,0xe5cda0);face.scale=SCNVector3(1,0.3,1);face.position=SCNVector3(0,0.42,-0.35);root.addChildNode(face)
        for side in [-1.0,1] {
            let ear=ball(0.095,0xb38b60);ear.position=SCNVector3(side*0.22,0.29,-0.32);root.addChildNode(ear)
            let eye=ball(0.027,0x302e24);eye.position=SCNVector3(side*0.065,0.46,-0.39);root.addChildNode(eye)
            let arm=SCNNode();arm.name=side<0 ? "left-arm":"right-arm";arm.position=SCNVector3(side*0.18,0.25,-0.02)
            let limb=box(0.21,0.07,0.10,0x956c4d);limb.position.x=NodeFloat(side*0.12);arm.addChildNode(limb)
            let cymbal=cylinder(0.17,0.025,0xe0bc64);cymbal.position=SCNVector3(side*0.21,0.10,-0.05);arm.addChildNode(cymbal);root.addChildNode(arm)
            let foot=ball(0.10,0x684f3c);foot.position=SCNVector3(side*0.15,0.15,0.37);root.addChildNode(foot)
        }
        let fuse=ball(0.055,0xffb86c,glow:true);fuse.name="monkey-fuse";fuse.position=SCNVector3(0,0.35,0.28);root.addChildNode(fuse)
        return root
    }
    func shieldBarrelModel()->SCNNode {
        let root=SCNNode();root.name="shield-barrel-model"
        let drum=cylinder(0.28,0.64,0xab7b4b);drum.position.y=0.32;root.addChildNode(drum)
        for y in [0.10,0.54] {let band=cylinder(0.291,0.055,0x505b50);band.position.y=NodeFloat(y);root.addChildNode(band)}
        let top=cylinder(0.267,0.025,0xd1a265);top.position.y=0.65;root.addChildNode(top)
        let plug=cylinder(0.055,0.035,0x555e4e);plug.position=SCNVector3(0.12,0.67,0);root.addChildNode(plug)
        return root
    }
    func sentryModel()->SCNNode {
        let root=SCNNode();root.name="sentry-model"
        let steel=artMaterial("sentry-steel",0x617664)
        for i in 0..<3 {
            let a=Double(i)*Double.pi*2/3,p=SCNVector3(cos(a)*0.49,0.04,sin(a)*0.49)
            root.addChildNode(beam(p,SCNVector3(0,0.49,0),radius:0.045,mat:steel))
            let pad=box(0.19,0.065,0.20,0x455b4a);pad.position=p;root.addChildNode(pad)
        }
        let base=cylinder(0.21,0.13,0x84947a);base.position.y=0.49;root.addChildNode(base)
        let turret=SCNNode();turret.name="sentry-head";turret.position.y=0.70
        let body=box(0.50,0.28,0.49,0x8e9c79);turret.addChildNode(body)
        let barrel=beam(SCNVector3(0,0,-0.15),SCNVector3(0,0,-0.83),radius:0.052,mat:steel);turret.addChildNode(barrel)
        let ammo=box(0.22,0.26,0.32,0xb7a370);ammo.position.x=0.35;turret.addChildNode(ammo)
        let flash=ball(0.11,0xffd78c,glow:true);flash.name="sentry-muzzle";flash.position=SCNVector3(0,0,-0.88);flash.scale=SCNVector3(0.65,0.65,1.8);flash.isHidden=true;turret.addChildNode(flash)
        root.addChildNode(turret)
        let lift=ball(0.14,0x9bbde6,glow:true);lift.name="sentry-lift";lift.position.y=0.08;lift.scale=SCNVector3(1,2,1);lift.isHidden=true;root.addChildNode(lift)
        return root
    }
    func syncSupportArt() {
        if core.teddyRemaining>0 {
            if teddyNode==nil {
                let root=SCNNode(),model=teddyModel();model.position=SCNVector3(-0.60,0.7,0.35);root.addChildNode(model)
                for radius in [3.70,3.80] {
                    let torus=SCNTorus(ringRadius:CGFloat(radius),pipeRadius:0.014);torus.materials=[material(0xebc987,glow:true)]
                    let ring=SCNNode(geometry:torus);ring.name="teddy-field";ring.opacity=0.25;ring.castsShadow=false;root.addChildNode(ring)
                }
                actors.addChildNode(root);teddyNode=root
            }
            teddyNode!.position=SCNVector3(core.hero.x,core.heroElevation+0.12,core.hero.y)
            teddyNode!.childNode(withName:"teddy-model",recursively:false)?.eulerAngles.y=NodeFloat(core.elapsed*0.8)
            teddyNode!.opacity=core.teddyRemaining<2 ? CGFloat(0.5+0.5*sin(core.elapsed*12)):1
        }else{teddyNode?.removeFromParentNode();teddyNode=nil}
        sync(&shieldBarrelNodes,ids:Set(core.shieldBarrels.map(\.id)))
        for b in core.shieldBarrels {
            let n=shieldBarrelNodes[b.id] ?? shieldBarrelModel()
            if shieldBarrelNodes[b.id]==nil {shieldBarrelNodes[b.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(b.p.x,core.heroElevation+0.11,b.p.y);n.eulerAngles.y=NodeFloat(b.angle*2)
        }
        sync(&departingShieldNodes,ids:Set(core.departingShieldBarrels.map(\.id)))
        for b in core.departingShieldBarrels {
            let n=departingShieldNodes[b.id] ?? shieldBarrelModel()
            if departingShieldNodes[b.id]==nil {departingShieldNodes[b.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(b.p.x,b.height-0.3,b.p.y);n.eulerAngles.z=NodeFloat(core.elapsed*12);n.opacity=CGFloat(min(1,b.ttl/0.3))
        }
        sync(&monkeyNodes,ids:Set(core.monkeys.map(\.id)))
        for m in core.monkeys {
            let n=monkeyNodes[m.id] ?? monkeyModel()
            if monkeyNodes[m.id]==nil {monkeyNodes[m.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(m.p.x,m.elevation+0.08,m.p.y);n.opacity=m.stowed ? 0.55:1
            n.childNode(withName:"left-arm",recursively:false)?.eulerAngles.z=NodeFloat(sin(core.elapsed*14)*0.5)
            n.childNode(withName:"right-arm",recursively:false)?.eulerAngles.z=NodeFloat(-sin(core.elapsed*14)*0.5)
            n.childNode(withName:"monkey-fuse",recursively:false)?.isHidden=m.stowed || Int(core.elapsed*(m.remaining<2 ? 16:5))%2==0
        }
        sync(&sentryNodes,ids:Set(core.sentries.map(\.id)))
        for t in core.sentries {
            let n=sentryNodes[t.id] ?? sentryModel()
            if sentryNodes[t.id]==nil {sentryNodes[t.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(t.p.x,t.stowed ? core.layout.height(t.p)+0.1:t.elevation+0.08,t.p.y);n.opacity=t.stowed ? 0.55:1
            n.childNode(withName:"sentry-head",recursively:false)?.eulerAngles.y=NodeFloat(atan2(-t.heading.x,-t.heading.y))
            n.childNode(withName:"sentry-muzzle",recursively:true)?.isHidden=t.flash<=0 || t.motion != .active
            n.childNode(withName:"sentry-lift",recursively:false)?.isHidden=t.motion != .leaving
        }
    }
}
