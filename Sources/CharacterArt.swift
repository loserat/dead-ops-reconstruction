import Foundation
import SceneKit
import simd

private let humanTorsoProfile:[(w:Double,y:Double,d:Double)]=[(0.29,0.65,0.19),(0.31,0.73,0.205),(0.34,0.85,0.22),(0.405,1.0,0.235),(0.44,1.08,0.23),(0.405,1.13,0.215),(0.31,1.17,0.18)]

extension ArcadeGame {
    /// Own articulated geometry; static garment pieces merge before entering the scene.
    func humanCharacter(player:Bool,variant:Int,prisoner:Bool)->SCNNode {
        let root=SCNNode();root.name=player ? "human-player":"human-zombie"
        let cloth=artMaterial(player ? "cloth-player":prisoner ? "cloth-prisoner":"cloth-zombie-\(variant%3)",player ? 0xc5c5c5:prisoner ? 0x778a96:[0x8d826b,0x887062,0x738581][variant%3])
        let skin=artMaterial(player ? "skin-player":"skin-zombie-\(variant%3)",player ? 0xc9a580:[0xa0a58c,0x969c89,0xaaa28a][variant%3])
        let rig=artMaterial(player ? "rig-player":"rig-zombie",player ? 0x4b5040:0x474338)
        let leather=artMaterial("character-leather",0x34382f),metal=artMaterial("character-buckles",0x676b60)
        cloth.emission.contents=rgb(player ? 0x151b12:0x0c1010);skin.emission.contents=rgb(0x13150e)
        func part(_ w:Double,_ h:Double,_ d:Double,_ mat:SCNMaterial,corner:Double=0.015)->SCNNode {
            let shape=SCNBox(width:w,height:h,length:d,chamferRadius:corner);shape.chamferSegmentCount=1;shape.materials=[mat];return SCNNode(geometry:shape)
        }
        func rounded(_ radius:Double,_ height:Double,_ mat:SCNMaterial)->SCNNode {
            let shape=SCNCapsule(capRadius:radius,height:height);shape.radialSegmentCount=10;shape.heightSegmentCount=1;shape.capSegmentCount=3;shape.materials=[mat];return SCNNode(geometry:shape)
        }
        let spine=SCNNode();spine.name="human-spine";root.addChildNode(spine)
        let garment=SCNNode()
        // A fitted smooth profile preserves waist/shoulder landmarks without octagonal flat-shaded faces.
        garment.addChildNode(humanTorsoMesh(cloth))
        let belt=part(0.32,0.065,0.225,leather);belt.position.y=0.68;garment.addChildNode(belt)
        let buckle=part(0.065,0.04,0.022,metal,corner:0.004);buckle.position=SCNVector3(0,0.68,-0.125);garment.addChildNode(buckle)
        let neck=rounded(0.065,0.14,skin);neck.position.y=1.19;garment.addChildNode(neck)
        if player {
            // A fitted canvas webbing vest keeps the shoulder colour visible from overhead.
            let rear=part(0.275,0.27,0.085,rig,corner:0.025);rear.position=SCNVector3(0,0.97,0.15);garment.addChildNode(rear)
            let backSeam=part(0.018,0.23,0.012,leather,corner:0.002);backSeam.position=SCNVector3(0,0.97,0.197);garment.addChildNode(backSeam)
            let chest=part(0.20,0.22,0.035,rig,corner:0.018);chest.position=SCNVector3(0,1.035,-0.132);garment.addChildNode(chest)
            for y in [0.99,1.045] {
                let webbing=part(0.205,0.019,0.014,leather,corner:0.003);webbing.position=SCNVector3(0,y,-0.155);garment.addChildNode(webbing)
            }
            for side in [-1.0,1] {
                let strap=part(0.052,0.36,0.035,rig,corner:0.007);strap.position=SCNVector3(side*0.12,1.0,-0.127);strap.eulerAngles.z=NodeFloat(-side*0.10);garment.addChildNode(strap)
                let pouch=part(0.105,0.145,0.073,rig);pouch.position=SCNVector3(side*0.1,0.83,-0.157);garment.addChildNode(pouch)
                let flap=part(0.108,0.027,0.08,leather,corner:0.005);flap.position=SCNVector3(side*0.1,0.88,-0.16);garment.addChildNode(flap)
            }
        }else{
            if !prisoner {
                // The dark folded edge and smaller exposed center follow the fitted garment surface.
                let center=V2(x:0.069,y:0.936),outline=[V2(x:0.025,y:0.909),V2(x:0.04,y:0.967),V2(x:0.065,y:0.952),V2(x:0.09,y:0.976),V2(x:0.114,y:0.945),V2(x:0.104,y:0.905),V2(x:0.066,y:0.918)]
                for (scale,offset,mat) in [(1.0,0.006,leather),(0.72,0.009,skin)] {
                    let points=[center]+outline.map{center+($0-center)*scale}
                    let vertices=points.map{humanTorsoPoint($0,offset:offset)}
                    var indices=[Int32]()
                    for i in outline.indices {indices += [0,Int32(i+1),Int32((i+1)%outline.count+1)]}
                    let tear=mesh(vertices,indices,normals:Array(repeating:SCNVector3(0,0,-1),count:vertices.count),mat:mat)
                    garment.addChildNode(tear)
                }
            }
            if prisoner {
                let stripe=artMaterial("cloth-prisoner-bands",0xb4bbaa)
                for y in [0.80,0.96,1.08] {garment.addChildNode(humanTorsoBand(center:y,height:0.037,mat:stripe))}
            }else{
                let seam=part(0.018,0.31,0.021,rig,corner:0.002);seam.position=SCNVector3(0,0.95,-0.128);garment.addChildNode(seam)
            }
        }
        spine.addChildNode(garment.flattenedClone())
        let headParts=SCNNode(),head=ball(0.125,0);head.geometry?.materials=[skin];(head.geometry as? SCNSphere)?.segmentCount=16;head.scale=SCNVector3(0.88,1.02,0.90);head.position=SCNVector3(0,1.35,-0.005);headParts.addChildNode(head)
        let jaw=part(0.165,0.14,0.155,skin,corner:0.045);(jaw.geometry as? SCNBox)?.chamferSegmentCount=3;jaw.position=SCNVector3(0,1.29,-0.018);headParts.addChildNode(jaw)
        let nose=part(0.037,0.055,0.06,skin,corner:0.012);nose.position=SCNVector3(0,1.35,-0.119);headParts.addChildNode(nose)
        for side in [-1.0,1] {
            let eye=ball(0.012,0x383b30);eye.position=SCNVector3(side*0.038,1.37,-0.115);eye.scale.z=0.45;headParts.addChildNode(eye)
            headParts.addChildNode(beam(SCNVector3(side*0.065,1.391,-0.114),SCNVector3(side*0.015,1.385,-0.121),radius:0.006,mat:rig))
        }
        spine.addChildNode(headParts.flattenedClone())
        if player {
            let helmet=soldierHelmet();helmet.name="player-helmet";helmet.position=SCNVector3(0,1.425,0.012);spine.addChildNode(helmet)
            let band=cylinder(0.151,0.018,0x3c4434);band.scale.z=1.10;band.position=SCNVector3(0,1.414,0.012);spine.addChildNode(band)
            let chin=beam(SCNVector3(-0.102,1.425,-0.035),SCNVector3(-0.077,1.265,-0.068),radius:0.009,mat:leather);spine.addChildNode(chin)
            let chinRight=beam(SCNVector3(0.102,1.425,-0.035),SCNVector3(0.077,1.265,-0.068),radius:0.009,mat:leather);spine.addChildNode(chinRight)
        }
        for side in [-1.0,1] {
            let leg=SCNNode();leg.name=side<0 ? "leftLeg":"rightLeg";leg.position=SCNVector3(side*0.094,0.67,0)
            let thigh=rounded(0.084,0.36,cloth);thigh.position.y = -0.14;leg.addChildNode(thigh)
            let knee=SCNNode();knee.name="human-knee";knee.position=SCNVector3(0,-0.31,0);leg.addChildNode(knee)
            let lower=SCNNode(),shin=rounded(0.067,0.30,cloth);shin.position=SCNVector3(0,-0.13,0.015);lower.addChildNode(shin)
            let boot=part(0.13,0.13,0.235,leather,corner:0.018);boot.position=SCNVector3(0,-0.29,-0.045);lower.addChildNode(boot)
            if player {
                let pad=part(0.10,0.105,0.035,rig,corner:0.02);pad.position=SCNVector3(0,-0.015,-0.064);lower.addChildNode(pad)
                let sole=part(0.135,0.025,0.24,leather,corner:0.007);sole.position=SCNVector3(0,-0.347,-0.045);lower.addChildNode(sole)
            }
            knee.addChildNode(lower.flattenedClone());root.addChildNode(leg)
            let arm=SCNNode();arm.name=side<0 ? "player-arm-left":"player-arm-right";arm.position=SCNVector3(side*0.23,1.09,0)
            let limb=SCNNode(),elbow=SCNVector3(side*0.045,player ? -0.23:-0.17,-0.12),hand=SCNVector3(player ? (side<0 ? 0.23:-0.10):side*0.04,player ? -0.27:-0.12,player ? (side<0 ? -0.61:-0.24):-0.35)
            let sleeve=beam(SCNVector3Zero,elbow,radius:0.076,mat:cloth);limb.addChildNode(sleeve)
            limb.addChildNode(beam(elbow,hand,radius:0.051,mat:skin))
            if player {
                let cuff=rounded(0.078,0.09,cloth);cuff.position=SCNVector3(elbow.x*0.73,elbow.y*0.73,elbow.z*0.73);cuff.eulerAngles.x=0.45;limb.addChildNode(cuff)
            }
            let glove=rounded(0.051,0.12,player ? leather:skin);glove.position=hand;glove.eulerAngles.x = -0.9;limb.addChildNode(glove)
            arm.addChildNode(limb.flattenedClone());spine.addChildNode(arm)
        }
        if player {
            for (kind,name) in [(PickupKind?.none,"standard-gun"),(.deathMachine,"death-machine")] {
                let gun=weaponModel(kind);gun.name=name;gun.position=SCNVector3(0.11,0.81,-0.37);gun.isHidden=kind != nil;root.addChildNode(gun)
            }
            let flash=ball(0.10,0xffd797,glow:true);flash.name="muzzle";flash.position=SCNVector3(0.11,0.81,-0.95);flash.scale=SCNVector3(0.7,0.7,1.8);flash.isHidden=true;root.addChildNode(flash)
            for (radius,thickness,color,name) in [(0.38,0.018,0xeff6df,"player-rim"),(0.34,0.025,0xc5ee89,"player-marker")] {
                let torus=SCNTorus(ringRadius:radius,pipeRadius:thickness);torus.ringSegmentCount=32;torus.pipeSegmentCount=6;torus.materials=[material(color,glow:true)]
                let node=SCNNode(geometry:torus);node.name=name;node.position.y=0.04;node.castsShadow=false;root.addChildNode(node)
            }
            let pointer=mesh([SCNVector3(-0.10,0.045,-0.40),SCNVector3(0.10,0.045,-0.40),SCNVector3(0,0.045,-0.61)],[0,1,2],normals:Array(repeating:SCNVector3(0,1,0),count:3),mat:material(0xc5ee89,glow:true));pointer.name="player-direction";pointer.geometry?.firstMaterial?.isDoubleSided=true;pointer.castsShadow=false;root.addChildNode(pointer)
        }
        let size=player ? 0.96:0.90;root.scale=SCNVector3(size,size,size)
        animateHumanCharacter(root,phase:0,amount:0,player:player)
        return root
    }
    /// Smooth elliptical garment rings with analytic normals; geometry is built once, never per frame.
    func humanTorsoMesh(_ cloth:SCNMaterial)->SCNNode {
        let rings=humanTorsoProfile
        let sectors=16
        var vertices=[SCNVector3](),normals=[SCNVector3](),uv=[CGPoint](),indices=[Int32]()
        for j in rings.indices {
            let r=rings[j],rx=r.w/2,rz=r.d/2
            for i in 0...sectors {
                let t=Double(i)/Double(sectors),a=t*2*Double.pi,c=cos(a),s=sin(a)
                vertices.append(SCNVector3(rx*c,r.y,rz*s))
                normals.append(humanTorsoNormal(y:r.y,angle:a));uv.append(CGPoint(x:t,y:(r.y-0.65)/0.52))
            }
        }
        for j in 0..<(rings.count-1) {for i in 0..<sectors {
            let a=Int32(j*(sectors+1)+i),b=a+Int32(sectors+1)
            indices += [a,b,a+1,a+1,b,b+1]
        }}
        for upper in [false,true] {
            let r=upper ? rings.last!:rings.first!,base=Int32(vertices.count)
            vertices.append(SCNVector3(0,r.y,0));normals.append(SCNVector3(0,upper ? 1:-1,0));uv.append(CGPoint(x:0.5,y:0.5))
            for i in 0...sectors {
                let a=Double(i)*2*Double.pi/Double(sectors)
                vertices.append(SCNVector3(r.w/2*cos(a),r.y,r.d/2*sin(a)));normals.append(SCNVector3(0,upper ? 1:-1,0));uv.append(CGPoint(x:cos(a)*0.5+0.5,y:sin(a)*0.5+0.5))
            }
            for i in 0..<sectors {let x=base+Int32(i)+1;indices += upper ? [base,x+1,x]:[base,x,x+1]}
        }
        let node=mesh(vertices,indices,uv:uv,normals:normals,mat:cloth);node.name="human-torso";return node
    }
    private func humanTorsoSection(_ y:Double)->(w:Double,y:Double,d:Double) {
        let rings=humanTorsoProfile
        let j=(0..<(rings.count-1)).first{y<=rings[$0+1].y} ?? rings.count-2
        let a=rings[j],b=rings[j+1],t=max(0,min(1,(y-a.y)/(b.y-a.y)))
        return (a.w+(b.w-a.w)*t,y,a.d+(b.d-a.d)*t)
    }
    private func humanTorsoNormal(y:Double,angle:Double)->SCNVector3 {
        let rings=humanTorsoProfile,c=cos(angle),s=sin(angle)
        func normal(_ i:Int)->SIMD3<Float> {
            let r=rings[i],a=rings[max(0,i-1)],b=rings[min(rings.count-1,i+1)]
            let rx=r.w/2,rz=r.d/2,dx=(b.w-a.w)/(2*(b.y-a.y)),dz=(b.d-a.d)/(2*(b.y-a.y))
            return simd_normalize(SIMD3<Float>(Float(c/rx),Float(-dx/rx*c*c-dz/rz*s*s),Float(s/rz)))
        }
        let j=(0..<(rings.count-1)).first{y<=rings[$0+1].y} ?? rings.count-2
        let t=Float(max(0,min(1,(y-rings[j].y)/(rings[j+1].y-rings[j].y))))
        let n=simd_normalize(normal(j)*(1-t)+normal(j+1)*t)
        return SCNVector3(n.x,n.y,n.z)
    }
    private func humanTorsoPoint(_ p:V2,offset:Double)->SCNVector3 {
        let r=humanTorsoSection(p.y),rx=r.w/2,rz=r.d/2
        return SCNVector3(p.x,p.y,-rz*sqrt(max(0,1-pow(p.x/rx,2)))-offset)
    }
    /// Fitted textile stripes sample the same sections/sectors as the actual body, 4mm above it.
    func humanTorsoBand(center:Double,height:Double,mat:SCNMaterial)->SCNNode {
        let low=center-height/2,high=center+height/2,sectors=16,offset=0.004
        let levels=[low]+humanTorsoProfile.filter{$0.y>low && $0.y<high}.map(\.y)+[high]
        var vertices=[SCNVector3](),normals=[SCNVector3](),uv=[CGPoint](),indices=[Int32]()
        for y in levels {
            let r=humanTorsoSection(y)
            for i in 0...sectors {
                let t=Double(i)/Double(sectors),a=t*2*Double.pi
                vertices.append(SCNVector3((r.w/2+offset)*cos(a),y,(r.d/2+offset)*sin(a)))
                normals.append(humanTorsoNormal(y:y,angle:a));uv.append(CGPoint(x:t,y:(y-0.65)/0.52))
            }
        }
        for j in 0..<(levels.count-1) {for i in 0..<sectors {let a=Int32(j*(sectors+1)+i),b=a+Int32(sectors+1);indices += [a,b,a+1,a+1,b,b+1]}}
        let node=mesh(vertices,indices,uv:uv,normals:normals,mat:mat);node.name="prisoner-fitted-stripe";return node
    }
    /// Elliptical steel shell and rolled lip. Smooth normals preserve volume at the game camera angle.
    func soldierHelmet()->SCNNode {
        let sectors=24,levels=6,rx=0.158,ry=0.15,rz=0.18
        var points=[SCNVector3](),normals=[SCNVector3](),triangles=[Int32]()
        for j in 0...levels {
            let latitude=Double(j)/Double(levels)*Double.pi/2
            for i in 0...sectors {
                let angle=Double(i)/Double(sectors)*Double.pi*2,c=cos(latitude)
                points.append(SCNVector3(rx*c*cos(angle),ry*sin(latitude),rz*c*sin(angle)))
                let n=simd_normalize(SIMD3<Float>(Float(c*cos(angle)/rx),Float(sin(latitude)/ry),Float(c*sin(angle)/rz)))
                normals.append(SCNVector3(n.x,n.y,n.z))
            }
        }
        for j in 0..<levels {for i in 0..<sectors {
            let a=Int32(j*(sectors+1)+i),b=a+Int32(sectors+1)
            triangles += [a,b,a+1,a+1,b,b+1]
        }}
        // The brim is part of the same independently tinted material, above the dark liner.
        for i in 0..<sectors {
            let a=Double(i)/Double(sectors)*Double.pi*2,b=Double(i+1)/Double(sectors)*Double.pi*2,start=Int32(points.count)
            for (angle,scale) in [(a,1.0),(a,1.10),(b,1.10),(b,1.0)] {points.append(SCNVector3(rx*cos(angle)*scale,0,rz*sin(angle)*scale));normals.append(SCNVector3(0,1,0))}
            triangles += [start,start+2,start+1,start,start+3,start+2]
        }
        let mat=material(0x99b67b);mat.lightingModel = .blinn;mat.shininess=12;mat.specular.contents=rgb(0x273329)
        return mesh(points,triangles,normals:normals,mat:mat)
    }
    func animateHumanCharacter(_ model:SCNNode,phase:Double,amount:Double,player:Bool,direction:V2=V2(x:0,y:-1)){
        guard let spine=model.childNode(withName:"human-spine",recursively:false) else{return}
        let stride=max(0,min(1,amount)),swing=sin(phase)*0.36*stride
        for (name,sign) in [("leftLeg",1.0),("rightLeg",-1.0)] {
            let leg=model.childNode(withName:name,recursively:false)
            if player {
                let pose=CharacterLegPose.plan(phase:phase,amount:stride,direction:direction,left:name=="leftLeg")
                leg?.eulerAngles=SCNVector3(pose.pitch,pose.yaw,pose.roll)
                leg?.childNode(withName:"human-knee",recursively:false)?.eulerAngles.x=NodeFloat(pose.knee)
            }else{
                leg?.eulerAngles.x=NodeFloat(swing*sign)
                leg?.childNode(withName:"human-knee",recursively:false)?.eulerAngles.x=NodeFloat(max(0,-sin(phase)*sign)*0.32*stride)
            }
        }
        spine.position.y=NodeFloat(abs(sin(phase*2))*0.018*stride)
        spine.eulerAngles.x=NodeFloat(player ? -0.025*stride:-0.14-0.035*sin(phase)*stride)
        spine.eulerAngles.z=NodeFloat(sin(phase)*(player ? 0.018:0.035)*stride)
        if !player {
            spine.childNode(withName:"player-arm-left",recursively:false)?.eulerAngles.x=NodeFloat(-0.08+0.10*sin(phase+0.9)*stride)
            spine.childNode(withName:"player-arm-right",recursively:false)?.eulerAngles.x=NodeFloat(0.02-0.12*sin(phase)*stride)
        }
    }
}
