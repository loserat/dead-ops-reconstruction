import Foundation
import SceneKit

extension ArcadeGame {
    func vehicleExitPulseModel()->SCNNode {
        let root=SCNNode();root.name="vehicle-exit-pulse"
        let mat=material(0xa8e6ee,glow:true);mat.lightingModel = .constant
        for radius in [0.72,1.0] {
            let ring=SCNTorus(ringRadius:CGFloat(radius),pipeRadius:0.018);ring.ringSegmentCount=48;ring.pipeSegmentCount=6;ring.materials=[mat]
            let n=SCNNode(geometry:ring);n.castsShadow=false;root.addChildNode(n)
        }
        return root.flattenedClone()
    }

    func tankModel(marked:Bool=false)->SCNNode {
        let root=SCNNode();root.name="tank"
        let green=artMaterial("tank-armor",0x768465),steel=artMaterial("tank-steel",0x39483f)
        for side in [-1.0,1] {
            let track=box(0.38,0.44,2.05,0x303c36);track.position=SCNVector3(side*0.65,0.24,0);root.addChildNode(track)
            for i in 0..<6 {
                let wheel=cylinder(0.18,0.05,0x596b55);wheel.eulerAngles.z=NodeFloat.pi/2;wheel.position=SCNVector3(side*0.86,0.25,Double(i)*0.31-0.78);root.addChildNode(wheel)
            }
            for i in 0..<12 {
                let tread=box(0.40,0.035,0.08,0x697568);tread.name="tread-\(i)";tread.position=SCNVector3(side*0.65,0.47,Double(i)*0.17-0.93);root.addChildNode(tread)
            }
        }
        let hull=box(1.28,0.44,1.83,0x768465);hull.geometry?.materials=[green];hull.position.y=0.56;root.addChildNode(hull)
        let front=box(1.28,0.27,0.55,0x7f8e70);front.position=SCNVector3(0,0.65,-0.78);front.eulerAngles.x = -0.24;root.addChildNode(front)
        for x in [-0.38,0.38] {let tank=cylinder(0.13,0.56,0x637353);tank.eulerAngles.x=NodeFloat.pi/2;tank.position=SCNVector3(x,0.67,0.93);root.addChildNode(tank)}
        let turret=SCNNode();turret.name="vehicle-turret";turret.position.y=0.93
        let dome=ball(0.48,0x85936c);dome.scale=SCNVector3(1,0.48,1.08);turret.addChildNode(dome)
        let hatch=cylinder(0.20,0.055,0x4f614b);hatch.position=SCNVector3(0,0.25,0.08);turret.addChildNode(hatch)
        turret.addChildNode(beam(SCNVector3(0,0.02,-0.20),SCNVector3(0,0.02,-1.55),radius:0.057,mat:steel))
        let flash=ball(0.15,0xffd281,glow:true);flash.name="vehicle-muzzle";flash.position=SCNVector3(0,0.02,-1.60);flash.scale=SCNVector3(0.7,0.7,1.8);flash.isHidden=true;turret.addChildNode(flash)
        root.addChildNode(turret)
        if marked {root.addChildNode(vehicleOwnerBadge(at:SCNVector3(0,1.22,0.08),length:0.28))}
        return root
    }
    func helicopterModel(marked:Bool=false)->SCNNode {
        let root=SCNNode();root.name="helicopter"
        let body=ball(0.55,0x70816d);body.scale=SCNVector3(0.85,0.78,1.85);body.position.y=0.22;root.addChildNode(body)
        let cockpit=ball(0.37,0x82a9b2);cockpit.scale=SCNVector3(0.85,0.9,1.18);cockpit.position=SCNVector3(0,0.20,-0.70);root.addChildNode(cockpit)
        let frame=artMaterial("helicopter-frame",0x4e6256)
        root.addChildNode(beam(SCNVector3(0,0.2,0.5),SCNVector3(0,0.42,2.05),radius:0.13,mat:frame))
        let fin=box(0.08,0.73,0.46,0x677b63);fin.position=SCNVector3(0,0.65,1.89);root.addChildNode(fin)
        let rotor=SCNNode();rotor.name="main-rotor";rotor.position=SCNVector3(0,0.9,0.05)
        let hub=cylinder(0.09,0.25,0x384d42);hub.position.y = -0.1;rotor.addChildNode(hub)
        for angle in [0.0,Double.pi/2] {let blade=box(3.7,0.035,0.12,0x34463c);blade.eulerAngles.y=NodeFloat(angle);blade.castsShadow=false;rotor.addChildNode(blade)}
        root.addChildNode(rotor)
        let tail=SCNNode();tail.name="tail-rotor";tail.position=SCNVector3(0.12,0.54,2.0)
        for angle in [0.0,Double.pi/2] {let blade=box(0.035,0.67,0.08,0x384b40);blade.eulerAngles.x=NodeFloat(angle);tail.addChildNode(blade)}
        root.addChildNode(tail)
        for side in [-1.0,1] {
            let wing=box(0.72,0.06,0.35,0x72846b);wing.position=SCNVector3(side*0.65,0.02,0.17);root.addChildNode(wing)
            let pod=cylinder(0.15,0.58,0x526b51);pod.eulerAngles.x=NodeFloat.pi/2;pod.position=SCNVector3(side*0.72,-0.08,0.08);root.addChildNode(pod)
            let rocket=ball(0.13,0xffbd70,glow:true);rocket.name="missile-flash";rocket.position=SCNVector3(side*0.72,-0.08,-0.27);rocket.isHidden=true;root.addChildNode(rocket)
            let wheel=ball(0.12,0x293d32);wheel.position=SCNVector3(side*0.33,-0.34,0.27);root.addChildNode(wheel)
        }
        let turret=ball(0.12,0x3f5548);turret.position=SCNVector3(0,-0.22,-0.86);root.addChildNode(turret)
        let flash=ball(0.10,0xffd281,glow:true);flash.name="vehicle-muzzle";flash.position=SCNVector3(0,-0.22,-1.08);flash.isHidden=true;root.addChildNode(flash)
        if marked {root.addChildNode(vehicleOwnerBadge(at:SCNVector3(0,0.66,-0.15),length:0.60))}
        return root
    }
    func vehicleOwnerBadge(at position:SCNVector3,length:CGFloat)->SCNNode {
        let n=box(0.30,0.016,length,selectedPlayerColor.tint);n.name="vehicle-owner-badge";n.position=position;n.castsShadow=false
        let mat=artMaterial("player-vehicle-badge",selectedPlayerColor.tint);mat.diffuse.contents=rgb(selectedPlayerColor.tint);mat.lightingModel = .constant;mat.diffuse.intensity=0.55;n.geometry?.materials=[mat];return n
    }
    func syncVehicleArt() {
        if core.loopReturn != nil {
            hero.childNodes.first?.isHidden=false;vehicleNode?.isHidden=true;vehicleShadow?.isHidden=true;vehicleLabel.isHidden=true;return
        }
        vehicleNode?.isHidden=false;vehicleShadow?.isHidden=false
        hero.childNodes.first?.isHidden=core.vehicle != nil
        vehicleLabel.isHidden=core.vehicle==nil
        guard let v=core.vehicle else {vehicleNode?.removeFromParentNode();vehicleNode=nil;vehicleShadow?.removeFromParentNode();vehicleShadow=nil;return}
        let expected=v.kind == .tank ? "tank":"helicopter"
        if vehicleNode?.name != expected {vehicleNode?.removeFromParentNode();vehicleNode=v.kind == .tank ? tankModel(marked:true):helicopterModel(marked:true);actors.addChildNode(vehicleNode!)}
        if vehicleShadow==nil {
            let shadow=SCNNode();shadow.name="vehicle-ground-shadow"
            for i in 0..<3 {
                let plane=SCNPlane(width:1.12+Double(i)*0.18,height:1.92+Double(i)*0.18);plane.cornerRadius=plane.width/2
                let mat=SCNMaterial();mat.lightingModel = .constant;mat.diffuse.contents=rgb(0x101b15,0.075);mat.writesToDepthBuffer=false;mat.isDoubleSided=true
                plane.materials=[mat];let layer=SCNNode(geometry:plane);layer.eulerAngles.x = -NodeFloat.pi/2;layer.position.y=NodeFloat(Double(i)*0.003);layer.castsShadow=false;shadow.addChildNode(layer)
            }
            actors.addChildNode(shadow);vehicleShadow=shadow
        }
        vehicleShadow!.position=SCNVector3(core.hero.x,core.layout.height(core.hero)+0.035,core.hero.y)
        vehicleShadow!.eulerAngles.y=NodeFloat(atan2(-v.heading.x,-v.heading.y))
        let n=vehicleNode!;n.position=SCNVector3(core.hero.x,core.heroElevation+0.06,core.hero.y)
        let yaw=atan2(-v.heading.x,-v.heading.y);n.eulerAngles.y=NodeFloat(yaw)
        n.childNode(withName:"vehicle-turret",recursively:false)?.eulerAngles.y=NodeFloat(atan2(-core.facing.x,-core.facing.y)-yaw)
        n.childNode(withName:"vehicle-muzzle",recursively:true)?.isHidden=v.flash<=0
        for flash in n.childNodes where flash.name=="missile-flash" {flash.isHidden=v.missileFlash<=0}
        n.childNode(withName:"main-rotor",recursively:false)?.eulerAngles.y=NodeFloat(core.elapsed*48)
        n.childNode(withName:"tail-rotor",recursively:false)?.eulerAngles.x=NodeFloat(core.elapsed*72)
        if v.kind == .helicopter {n.eulerAngles.z=NodeFloat(-v.velocity.x*0.012);n.eulerAngles.x=NodeFloat(v.velocity.y*0.012)}
        vehicleLabel.text=v.landingTarget==nil ? "\(v.kind.title) · \(Int(ceil(v.remaining)))s":"HIND · LANDUNG"
        if v.kind == .tank {for tread in n.childNodes where tread.name?.hasPrefix("tread-")==true {tread.position.y=NodeFloat(0.47+sin(v.travel*40)*0.008)}}
    }
}
