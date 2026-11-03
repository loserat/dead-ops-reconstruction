import Foundation
import SceneKit

extension ArcadeGame {
    /// Shared own model: the same silhouette is used in the player's hands and on the ground.
    /// Local muzzle points toward -Z; attachment/thumbnail transforms are applied by callers.
    func weaponModel(_ kind:PickupKind?)->SCNNode {
        let root=SCNNode();root.name="weapon-model-\(kind?.rawValue ?? -1)"
        let steel=artMaterial("weapon-steel63",0x83969e),dark=artMaterial("weapon-dark63",0x293631),wood=artMaterial("wood-weapon-stock63",0x8a684e)
        let brass=artMaterial("weapon-brass63",0xc6a65d)
        steel.shininess=42;steel.specular.contents=rgb(0x71848b)
        steel.emission.contents=rgb(0x19222a);dark.emission.contents=rgb(0x101813);wood.emission.contents=rgb(0x251c13)
        func part(_ name:String,_ w:Double,_ h:Double,_ l:Double,_ p:SCNVector3,_ mat:SCNMaterial){let n=box(CGFloat(w),CGFloat(h),CGFloat(l),0x738078);n.name=name;n.geometry?.materials=[mat];n.position=p;root.addChildNode(n)}
        func tube(_ name:String,_ radius:CGFloat,_ from:SCNVector3,_ to:SCNVector3,_ mat:SCNMaterial){let n=beam(from,to,radius:radius,mat:mat);n.name=name;root.addChildNode(n)}
        switch kind {
        case .rocket:
            let olive=material(0x78925a)
            tube("rpg-launcher-tube",0.075,SCNVector3(0,0,0.38),SCNVector3(0,0,-0.60),olive)
            let cone=SCNCone(topRadius:0,bottomRadius:0.13,height:0.30);cone.radialSegmentCount=10;cone.materials=[material(0xc2c383)]
            let tip=SCNNode(geometry:cone);tip.name="rpg-warhead";tip.eulerAngles.x = -NodeFloat.pi/2;tip.position=SCNVector3(0,0,-0.73);root.addChildNode(tip)
            let collar=SCNTorus(ringRadius:0.105,pipeRadius:0.018);collar.ringSegmentCount=16;collar.pipeSegmentCount=6;collar.materials=[steel]
            let rear=SCNNode(geometry:collar);rear.name="rpg-rear-bell";rear.eulerAngles.x=NodeFloat.pi/2;rear.position.z=0.40;root.addChildNode(rear)
            part("rpg-grip",0.08,0.20,0.10,SCNVector3(0,-0.12,0.04),wood)
            tube("rpg-front-handguard",0.091,SCNVector3(0,0,0.17),SCNVector3(0,0,-0.15),wood)
            part("rpg-folding-sight",0.035,0.17,0.055,SCNVector3(0,0.14,-0.31),dark)
            part("rpg-sight-crossbar",0.13,0.025,0.035,SCNVector3(0,0.215,-0.31),steel)
            tube("rpg-warhead-neck",0.069,SCNVector3(0,0,-0.53),SCNVector3(0,0,-0.62),brass)
            for z in [0.11,-0.02,-0.13] {part("rpg-handguard-band",0.19,0.025,0.017,SCNVector3(0,0.078,z),dark)}
        case .ray:
            let copper=material(0xb36c55),body=ball(0.14,0xb36c55);body.name="ray-copper-body";body.geometry?.materials=[copper];body.scale=SCNVector3(0.8,0.8,1.7);root.addChildNode(body)
            tube("ray-barrel",0.045,SCNVector3(0,0,-0.15),SCNVector3(0,0,-0.52),steel)
            for z in [-0.25,-0.37,-0.49] {let ring=SCNTorus(ringRadius:0.080,pipeRadius:0.018);ring.ringSegmentCount=16;ring.pipeSegmentCount=6;ring.materials=[material(0x9ce98a,glow:true)];let n=SCNNode(geometry:ring);n.name="ray-energy-ring";n.eulerAngles.x=NodeFloat.pi/2;n.position.z=NodeFloat(z);root.addChildNode(n)}
            part("ray-grip",0.085,0.21,0.09,SCNVector3(0,-0.14,0.06),wood)
            part("ray-upper-fin",0.035,0.11,0.22,SCNVector3(0,0.12,0.04),copper)
            tube("ray-side-chamber",0.05,SCNVector3(0.14,0.015,0.11),SCNVector3(0.14,0.015,-0.10),steel)
            part("ray-top-sight",0.06,0.04,0.10,SCNVector3(0,0.19,-0.06),brass)
            for x in [-0.105,0.105] {part("ray-body-trim",0.022,0.04,0.22,SCNVector3(x,0.08,0),brass)}
        case .deathMachine:
            part("death-machine-housing",0.27,0.23,0.35,SCNVector3(0,0,0.03),steel)
            part("death-machine-ammo",0.22,0.19,0.28,SCNVector3(-0.20,-0.06,0.13),dark)
            let rotor=SCNNode();rotor.name="barrel-rotor";rotor.position.z = -0.16
            for i in 0..<6 {let a=Double(i)*Double.pi/3,x=cos(a)*0.067,y=sin(a)*0.067;let n=beam(SCNVector3(x,y,0),SCNVector3(x,y,-0.57),radius:0.019,mat:steel);n.name="death-machine-barrel";rotor.addChildNode(n)}
            root.addChildNode(rotor)
            for z in [-0.30,-0.62] {let band=SCNTorus(ringRadius:0.085,pipeRadius:0.024);band.ringSegmentCount=16;band.pipeSegmentCount=6;band.materials=[dark];let n=SCNNode(geometry:band);n.eulerAngles.x=NodeFloat.pi/2;n.position.z=NodeFloat(z);root.addChildNode(n)}
            part("death-machine-grip",0.10,0.14,0.12,SCNVector3(0,-0.17,0.14),wood)
            for x in [-0.10,0.10] {tube("death-machine-handle-support",0.025,SCNVector3(x,0.10,0.04),SCNVector3(x,0.22,0.04),dark)}
            tube("death-machine-carry-handle",0.035,SCNVector3(-0.10,0.22,0.04),SCNVector3(0.10,0.22,0.04),dark)
            for x in [-0.13,-0.18,-0.23,-0.28] {tube("death-machine-feed-round",0.014,SCNVector3(x,0.07,-0.02),SCNVector3(x,0.07,0.10),brass)}
            part("death-machine-top-plate",0.20,0.022,0.20,SCNVector3(0,0.127,-0.015),dark)
        case .flamethrower:
            let pack=SCNNode();pack.name="flame-fuel-pack";pack.position=SCNVector3(-0.11,0.03,0.62)
            for x in [-0.13,0.13] {
                let n=cylinder(0.085,0.43,0xb9a666);n.name="flame-fuel-cylinder";n.position.x=NodeFloat(x);pack.addChildNode(n)
                let cap=cylinder(0.043,0.045,0x6b7151);cap.name="flame-fuel-valve";cap.position=SCNVector3(x,0.245,0);pack.addChildNode(cap)
                for y in [-0.12,0.12] {let strap=SCNTorus(ringRadius:0.087,pipeRadius:0.012);strap.ringSegmentCount=12;strap.pipeSegmentCount=4;strap.materials=[dark];let s=SCNNode(geometry:strap);s.position=SCNVector3(x,y,0);pack.addChildNode(s)}
            }
            root.addChildNode(pack)
            tube("flame-lance",0.035,SCNVector3(0,0,0.08),SCNVector3(0,0,-0.62),steel)
            let nozzle=cylinder(0.065,0.12,0xd7a25a);nozzle.name="flame-nozzle";nozzle.eulerAngles.x=NodeFloat.pi/2;nozzle.position.z = -0.62;root.addChildNode(nozzle)
            let hose=material(0x414a3d);var last=SCNVector3(0.02,-0.10,0.62)
            for i in 1...7 {let t=Double(i)/7,p=SCNVector3(0.02+sin(t*Double.pi)*0.18,-0.10-sin(t*Double.pi)*0.18,0.62*(1-t));tube("flame-hose",0.023,last,p,hose);last=p}
            part("flame-grip",0.08,0.14,0.09,SCNVector3(0,-0.11,-0.04),wood)
        case .grenade:
            part("china-lake-receiver",0.17,0.17,0.33,SCNVector3(0,0,0),steel)
            tube("china-lake-wide-barrel",0.067,SCNVector3(0,0,-0.12),SCNVector3(0,0,-0.62),dark)
            part("china-lake-pump",0.15,0.12,0.24,SCNVector3(0,-0.09,-0.29),wood)
            part("china-lake-stock",0.11,0.16,0.31,SCNVector3(0,-0.02,0.29),wood)
            part("china-lake-grip",0.09,0.16,0.11,SCNVector3(0,-0.13,0.13),wood)
            part("china-lake-front-sight",0.035,0.09,0.04,SCNVector3(0,0.10,-0.55),steel)
            part("china-lake-buttplate",0.14,0.19,0.035,SCNVector3(0,-0.02,0.46),dark)
            for z in [-0.22,-0.27,-0.32,-0.37] {part("china-lake-pump-groove",0.16,0.018,0.017,SCNVector3(0,-0.022,z),dark)}
            part("china-lake-ejection-port",0.085,0.012,0.11,SCNVector3(0,0.092,-0.015),dark)
        case .spread:
            part("spas-receiver",0.14,0.13,0.30,SCNVector3(0,0,0),steel)
            tube("spas-upper-barrel",0.025,SCNVector3(0,0.02,-0.12),SCNVector3(0,0.02,-0.74),steel)
            tube("spas-magazine-tube",0.030,SCNVector3(0,-0.055,-0.12),SCNVector3(0,-0.055,-0.64),dark)
            part("spas-pump",0.15,0.12,0.23,SCNVector3(0,-0.025,-0.30),dark)
            // The open rear frame is visible from above, unlike another solid rifle stock.
            for x in [-0.065,0.065] {part("spas-stock-rail",0.025,0.055,0.31,SCNVector3(x,0,0.29),dark)}
            part("spas-stock-butt",0.17,0.10,0.045,SCNVector3(0,-0.015,0.46),steel)
            part("spas-grip",0.085,0.17,0.10,SCNVector3(0,-0.13,0.12),dark)
            part("spas-heatshield",0.09,0.045,0.42,SCNVector3(0,0.065,-0.35),dark)
            for z in [-0.20,-0.29,-0.38,-0.47] {part("spas-vent",0.094,0.012,0.025,SCNVector3(0,0.092,z),steel)}
            for z in [-0.24,-0.29,-0.34] {part("spas-pump-rib",0.17,0.025,0.018,SCNVector3(0,-0.015,z),steel)}
        default:
            part("m60-receiver",0.17,0.15,0.35,SCNVector3(0,0,0),steel)
            tube("m60-barrel",0.027,SCNVector3(0,0,-0.15),SCNVector3(0,0,-0.72),steel)
            part("m60-ammo-box",0.22,0.20,0.21,SCNVector3(-0.12,-0.07,0.03),material(0x7e8a58))
            part("m60-stock",0.10,0.13,0.30,SCNVector3(0,0,0.30),dark)
            part("m60-feed-cover",0.175,0.035,0.27,SCNVector3(0,0.09,0),dark)
            part("m60-grip",0.075,0.17,0.10,SCNVector3(0,-0.14,0.13),wood)
            tube("m60-handguard",0.052,SCNVector3(0,0,-0.17),SCNVector3(0,0,-0.42),dark)
            part("m60-front-sight",0.035,0.09,0.04,SCNVector3(0,0.07,-0.61),dark)
            tube("m60-flash-suppressor",0.042,SCNVector3(0,0,-0.64),SCNVector3(0,0,-0.72),dark)
            for x in [-0.10,-0.15,-0.20,-0.25] {tube("m60-feed-belt",0.015,SCNVector3(x,0.115,-0.035),SCNVector3(x,0.115,0.075),brass)}
            for side in [-1.0,1] {tube("m60-bipod",0.015,SCNVector3(0,-0.02,-0.55),SCNVector3(side*0.13,-0.18,-0.60),dark)}
            for z in [-0.16,-0.34] {tube("m60-handle-upright",0.018,SCNVector3(0.065,0.025,z),SCNVector3(0.065,0.16,z),dark)}
            tube("m60-carry-handle",0.025,SCNVector3(0.065,0.16,-0.16),SCNVector3(0.065,0.16,-0.34),wood)
            part("m60-ejection-port",0.08,0.012,0.13,SCNVector3(0,0.115,0.02),dark)
        }
        let muzzle=SCNNode();muzzle.name="weapon-muzzle"
        let z:Double=kind == .rocket ? -0.88:kind == .ray ? -0.54:kind == .grenade || kind == .flamethrower ? -0.68:-0.75
        muzzle.position=SCNVector3(0,0,z);root.addChildNode(muzzle)
        // Merge immutable details by material. Keep the muzzle and rotating barrels independent.
        let staticParts=SCNNode()
        for child in root.childNodes where child !== muzzle && child.name != "barrel-rotor" {staticParts.addChildNode(child)}
        let bounds=staticParts.boundingBox,body=staticParts.flattenedClone();body.name="weapon-static-body";body.boundingBox=bounds;root.addChildNode(body)
        if let rotor=root.childNode(withName:"barrel-rotor",recursively:false) {
            let merged=rotor.flattenedClone();merged.name="barrel-rotor";merged.boundingBox=rotor.boundingBox
            rotor.removeFromParentNode();root.addChildNode(merged)
        }
        return root
    }
    func pickupWeaponModel(_ kind:PickupKind)->SCNNode {
        // SceneKit's freshly flattened geometry can report zero bounds until its first render.
        // Capture the hierarchy bounds first and preserve them for scaling and culling.
        let model=weaponModel(kind),b=model.boundingBox
        let n=model.flattenedClone();n.name="pickup-weapon-\(kind.rawValue)";n.boundingBox=b
        let extent=max(Double(b.max.x-b.min.x),Double(b.max.z-b.min.z)),scale=1.05/max(0.1,extent)
        n.scale=SCNVector3(scale,scale,scale);n.position=SCNVector3(-Double(b.max.x+b.min.x)*scale/2,-Double(b.min.y)*scale,-Double(b.max.z+b.min.z)*scale/2)
        return n
    }
}
