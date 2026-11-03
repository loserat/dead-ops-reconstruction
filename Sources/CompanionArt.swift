import Foundation
import SceneKit

extension ArcadeGame {
    func flyingChickenModel()->SCNNode {
        let root=SCNNode(),feathers=artMaterial("feathers",0xe6dfc8)
        let body=ball(0.16,0xe6dfc8);body.geometry?.materials=[feathers];body.scale=SCNVector3(0.9,0.8,1.25);root.addChildNode(body)
        let head=ball(0.085,0xe8e1c7);head.position=SCNVector3(0,0.14,-0.14);root.addChildNode(head)
        let comb=box(0.03,0.08,0.11,0x9d4236);comb.position=SCNVector3(0,0.23,-0.14);root.addChildNode(comb)
        let beak=box(0.07,0.04,0.09,0xd8ac4b);beak.position=SCNVector3(0,0.14,-0.24);root.addChildNode(beak)
        for side in [-1.0,1] {
            let wing=SCNNode();wing.name=side<0 ? "leftWing":"rightWing";wing.position.x=NodeFloat(side*0.12)
            let feathersNode=ball(0.16,0xdad8bf);feathersNode.geometry?.materials=[feathers]
            feathersNode.scale=SCNVector3(1.3,0.20,0.8);feathersNode.position.x=NodeFloat(side*0.13);wing.addChildNode(feathersNode);root.addChildNode(wing)
            let foot=box(0.035,0.10,0.07,0xb89a4b);foot.position=SCNVector3(side*0.065,-0.17,0.03);root.addChildNode(foot)
        }
        let tail=box(0.14,0.05,0.18,0xd8d6be);tail.position=SCNVector3(0,0.06,0.23);tail.eulerAngles.x = -0.5;root.addChildNode(tail)
        let gun=beam(SCNVector3(0.09,-0.08,-0.03),SCNVector3(0.09,-0.08,-0.43),radius:0.032,mat:artMaterial("gunmetal",0x363c37));root.addChildNode(gun)
        let flash=ball(0.075,0xffd28b,glow:true);flash.name="muzzle";flash.position=SCNVector3(0.09,-0.08,-0.46);flash.scale=SCNVector3(0.6,0.6,1.4);root.addChildNode(flash)
        return root
    }
    func orbModel()->SCNNode {
        let root=ball(0.105,0xb6c5ff,glow:true);root.geometry?.firstMaterial?.lightingModel = .constant
        let ring=SCNTorus(ringRadius:0.14,pipeRadius:0.012);ring.materials=[material(0x91abeb,glow:true)]
        let n=SCNNode(geometry:ring);n.eulerAngles.x=0.8;root.addChildNode(n);return root
    }
    func electricArcModel(_ arc:ElectricArc)->SCNNode {
        let root=SCNNode(),delta=arc.b-arc.a,perp=V2(x:-delta.y,y:delta.x).unit
        if arc.travelDuration>0 {
            let mat=material(0xb1c0ff,glow:true);mat.lightingModel = .constant
            let spark=ball(0.095,0xc6ddff,glow:true);spark.castsShadow=false;root.addChildNode(spark)
            let direction=delta.unit
            var last=SCNVector3(0,0,0)
            for i in 1...4 {
                let t=Double(i)/4,p=direction*(-0.42*t)+perp*(sin(Double(i*17+arc.id))*0.055)
                let next=SCNVector3(p.x,sin(Double(i*11))*0.045,p.y)
                let trail=beam(last,next,radius:0.016*(1-t*0.45),mat:mat);trail.castsShadow=false;root.addChildNode(trail);last=next
            }
            return root.flattenedClone()
        }
        if delta.length<0.02 {
            let spark=ball(0.13,0xb1c0ff,glow:true);spark.position=SCNVector3(arc.a.x,arc.aHeight,arc.a.y);return spark
        }
        let mat=material(0xb1c0ff,glow:true);mat.lightingModel = .constant
        var last=SCNVector3(arc.a.x,arc.aHeight,arc.a.y)
        for i in 1...7 {
            let t=Double(i)/7,jitter=sin(t*Double.pi)*sin(Double(i*17+arc.id))*0.14
            let p=arc.a+delta*t+perp*jitter,next=SCNVector3(p.x,arc.aHeight+(arc.bHeight-arc.aHeight)*t+sin(t*Double.pi)*0.08,p.y)
            let beamNode=beam(last,next,radius:0.019,mat:mat);beamNode.castsShadow=false;root.addChildNode(beamNode);last=next
        }
        return root.flattenedClone()
    }
    func syncCompanionArt() {
        sync(&chickenNodes,ids:Set(core.chickens.map(\.id)))
        for chicken in core.chickens {
            let n=chickenNodes[chicken.id] ?? flyingChickenModel()
            if chickenNodes[chicken.id]==nil {chickenNodes[chicken.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(chicken.p.x,chicken.elevation+1.1+sin(core.elapsed*6+Double(chicken.id))*0.05,chicken.p.y)
            n.eulerAngles.y=NodeFloat(atan2(-chicken.facing.x,-chicken.facing.y))
            n.childNode(withName:"leftWing",recursively:false)?.eulerAngles.z=NodeFloat(sin(core.elapsed*22+Double(chicken.id))*0.8)
            n.childNode(withName:"rightWing",recursively:false)?.eulerAngles.z=NodeFloat(-sin(core.elapsed*22+Double(chicken.id))*0.8)
            n.childNode(withName:"muzzle",recursively:false)?.isHidden=chicken.flash<=0 || core.phase != .playing
            n.opacity=CGFloat(min(1,chicken.ttl/0.5))
        }
        let activeOrbIDs=Set(core.orbShields.map(\.id))
        for orb in core.flyingOrbs where !activeOrbIDs.contains(orb.id) {
            if let existing=orbNodes.removeValue(forKey:orb.id) {flyingOrbNodes[orb.id]=existing}
        }
        sync(&orbNodes,ids:activeOrbIDs)
        for orb in core.orbShields {
            let n=orbNodes[orb.id] ?? orbModel()
            if orbNodes[orb.id]==nil {orbNodes[orb.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(orb.p.x,core.heroElevation+TeslaRules.orbitHeight,orb.p.y)
        }
        sync(&flyingOrbNodes,ids:Set(core.flyingOrbs.map(\.id)))
        for orb in core.flyingOrbs {
            let n=flyingOrbNodes[orb.id] ?? orbModel()
            if flyingOrbNodes[orb.id]==nil {flyingOrbNodes[orb.id]=n;actors.addChildNode(n)}
            n.position=SCNVector3(orb.p.x,orb.height,orb.p.y);n.opacity=1
        }
        sync(&arcNodes,ids:Set(core.electricArcs.map(\.id)))
        for arc in core.electricArcs {
            let n=arcNodes[arc.id] ?? electricArcModel(arc)
            if arcNodes[arc.id]==nil {arcNodes[arc.id]=n;actors.addChildNode(n)}
            if arc.travelDuration>0 {
                let t=arc.progress,p=arc.a+(arc.b-arc.a)*t
                n.position=SCNVector3(p.x,arc.aHeight+(arc.bHeight-arc.aHeight)*t,p.y)
            }
            n.opacity=CGFloat(min(1,arc.ttl/0.08))
        }
        var labels:[String]=[]
        if !core.orbShields.isEmpty {
            let wait=core.playerRoster.current.tesla.gateRemaining
            let charging=wait>0 ? " · lädt "+String(format:"%.1f",wait)+"s":""
            labels.append("ELEKTRO \(core.orbShields.count) · \(Int(ceil(core.orb)))s"+charging)
        }
        if !core.chickens.isEmpty {
            let permanent=core.chickens.contains{$0.permanent}
            labels.append("HÜHNER \(core.chickens.count) · \(permanent ? "∞":String(Int(ceil(core.chicken)))+"s")")
        }
        var support:[String]=[]
        if core.teddyRemaining>0 {support.append("TEDDY \(Int(ceil(core.teddyRemaining)))s")}
        if !core.shieldBarrels.isEmpty {support.append("FÄSSER 2 · \(Int(ceil(core.shieldBarrelRemaining)))s")}
        if !core.monkeys.isEmpty {support.append("AFFEN \(core.monkeys.count)"+(core.monkeys.allSatisfy{$0.stowed} ? " BEREIT":""))}
        if !core.sentries.isEmpty {support.append("ANLAGEN \(core.sentries.count)"+(core.sentries.allSatisfy{$0.stowed} ? " BEREIT":""))}
        supportLabel.text=[labels.joined(separator:"     "),support.joined(separator:"     ")].filter{!$0.isEmpty}.joined(separator:"\n")
    }
}
