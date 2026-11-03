import Foundation
import SceneKit

extension ArcadeGame {
    /// Own solid silhouettes for the steep gameplay camera. No extra lights or animated particles.
    /// Immutable details are merged once, with their pre-merge bounds retained for SceneKit culling.
    func utilityPickupModel(_ kind:PickupKind)->SCNNode {
        let root=SCNNode()
        func finish()->SCNNode {
            let bounds=root.boundingBox,node=root.flattenedClone()
            node.name="utility-pickup-\(kind.rawValue)";node.boundingBox=bounds
            return node
        }
        func surface(_ name:String,_ color:Int,_ shine:CGFloat=22)->SCNMaterial {
            let m=artMaterial("pickup-solid63-"+name,color)
            m.shininess=shine;m.specular.contents=rgb(0x45443a)
            m.emission.contents=rgb(color);m.emission.intensity=0.075
            return m
        }
        func part(_ w:CGFloat,_ h:CGFloat,_ d:CGFloat,_ p:SCNVector3,_ m:SCNMaterial) {
            let n=box(w,h,d,0xffffff);n.geometry?.materials=[m];n.position=p;root.addChildNode(n)
        }
        func round(_ r:CGFloat,_ p:SCNVector3,_ scale:SCNVector3,_ m:SCNMaterial) {
            let n=ball(r,0xffffff);n.geometry?.materials=[m];n.position=p;n.scale=scale;root.addChildNode(n)
        }
        let gold=surface("gold",0xe2c16b,48),bronze=surface("bronze",0x9e742f)
        switch kind {
        case .life:
            let plinth=cylinder(0.22,0.065,0xffffff);plinth.geometry?.materials=[bronze];plinth.position.y = -0.035;root.addChildNode(plinth)
            part(0.31,0.035,0.25,SCNVector3(0,0.015,0),gold)
            for side in [-1.0,1] {
                part(0.067,0.20,0.075,SCNVector3(side*0.062,0.13,0.015),gold)
                part(0.075,0.048,0.13,SCNVector3(side*0.062,0.052,-0.025),bronze)
                root.addChildNode(beam(SCNVector3(side*0.11,0.34,0),SCNVector3(side*0.14,0.25,-0.08),radius:0.038,mat:gold))
                root.addChildNode(beam(SCNVector3(side*0.14,0.25,-0.08),SCNVector3(side*0.085,0.31,-0.13),radius:0.031,mat:gold))
            }
            part(0.18,0.20,0.11,SCNVector3(0,0.30,0),gold)
            part(0.19,0.035,0.12,SCNVector3(0,0.23,0),bronze)
            round(0.076,SCNVector3(0,0.445,-0.005),SCNVector3(0.88,1,0.9),gold)
            round(0.098,SCNVector3(0,0.49,0),SCNVector3(1,0.60,1),gold)
            root.addChildNode(beam(SCNVector3(-0.19,0.29,-0.13),SCNVector3(0.23,0.35,-0.13),radius:0.024,mat:bronze))
            part(0.11,0.045,0.07,SCNVector3(-0.15,0.295,-0.13),gold)
        case .bomb:
            let shell=surface("bomb-olive",0x8b9c62),fin=surface("bomb-fins",0x536442)
            round(0.13,SCNVector3(0,0,0),SCNVector3(1,1,2.35),shell)
            round(0.095,SCNVector3(0,0,-0.245),SCNVector3(1,1,0.9),gold)
            for z in [-0.18,0.16] {
                let g=SCNTorus(ringRadius:0.122,pipeRadius:0.012);g.ringSegmentCount=16;g.pipeSegmentCount=4;g.materials=[gold]
                let n=SCNNode(geometry:g);n.eulerAngles.x=NodeFloat.pi/2;n.position.z=NodeFloat(z);root.addChildNode(n)
            }
            part(0.37,0.045,0.19,SCNVector3(0,0,0.24),fin)
            part(0.045,0.30,0.19,SCNVector3(0,0,0.24),fin)
            part(0.14,0.10,0.065,SCNVector3(0,0,0.335),gold)
            root.eulerAngles.x = -0.15
        case .dash:
            // A closed, thick horizontal bolt retains an actual silhouette through a full turn.
            let outline:[(Double,Double)]=[(-0.03,0.46),(0.20,0.46),(0.02,0.20),(0.17,0.20),(-0.15,-0.16),(-0.04,0.11),(-0.18,0.11)]
            let top=outline.map{SCNVector3($0.0*1.45,0.065,-$0.1)},bottom=outline.map{SCNVector3($0.0*1.45,-0.035,-$0.1)}
            let triangles:[Int32]=[0,1,2,0,2,6,6,2,5,5,2,3,5,3,4]
            let reversed=stride(from:0,to:triangles.count,by:3).flatMap{[triangles[$0],triangles[$0+2],triangles[$0+1]]}
            root.addChildNode(mesh(top,reversed,normals:Array(repeating:SCNVector3(0,1,0),count:7),mat:gold))
            root.addChildNode(mesh(bottom,triangles,normals:Array(repeating:SCNVector3(0,-1,0),count:7),mat:bronze))
            var vertices=[SCNVector3](),normals=[SCNVector3](),indices=[Int32]()
            for i in 0..<7 {
                let j=(i+1)%7,start=Int32(vertices.count),dx=Double(top[j].x-top[i].x),dz=Double(top[j].z-top[i].z),length=max(0.001,hypot(dx,dz))
                vertices += [top[i],bottom[i],top[j],bottom[j]]
                normals += Array(repeating:SCNVector3(dz/length,0,-dx/length),count:4)
                indices += [start,start+1,start+2,start+2,start+1,start+3]
            }
            root.addChildNode(mesh(vertices,indices,normals:normals,mat:bronze))
        case .boots:
            let leather=surface("boot-leather",0x9a7550),rubber=surface("boot-rubber",0x30342d),cuff=surface("boot-cuff",0xc4a46b)
            for x in [-0.13,0.13] {
                part(0.19,0.055,0.37,SCNVector3(x,-0.07,-0.035),rubber)
                part(0.17,0.12,0.31,SCNVector3(x,0.005,-0.055),leather)
                part(0.145,0.25,0.15,SCNVector3(x,0.11,0.06),leather)
                part(0.16,0.045,0.165,SCNVector3(x,0.23,0.06),cuff)
                part(0.11,0.012,0.11,SCNVector3(x,0.256,0.06),rubber)
                for z in [-0.095,-0.045,0.005] {part(0.12,0.013,0.013,SCNVector3(x,0.073,z),cuff)}
            }
        case .chicken:
            let feather=surface("feather",0xf0e7cc),wing=surface("wing",0xc8b790),red=surface("comb",0xb4483e)
            round(0.17,SCNVector3(0,0,0.01),SCNVector3(1,0.86,1.30),feather)
            for side in [-1.0,1] {
                round(0.10,SCNVector3(side*0.135,0.015,0.045),SCNVector3(0.45,0.8,1.25),wing)
                root.addChildNode(beam(SCNVector3(side*0.065,-0.08,0.04),SCNVector3(side*0.065,-0.16,-0.04),radius:0.018,mat:gold))
            }
            round(0.09,SCNVector3(0,0.18,-0.14),SCNVector3(0.85,1,1),feather)
            part(0.065,0.035,0.095,SCNVector3(0,0.16,-0.235),gold)
            part(0.035,0.08,0.12,SCNVector3(0,0.27,-0.13),red)
            for side in [-1.0,1] {round(0.016,SCNVector3(side*0.074,0.20,-0.17),SCNVector3(1,1,1),surface("eye",0x252c27))}
            for side in [-1.0,0,1] {root.addChildNode(beam(SCNVector3(0,0.03,0.15),SCNVector3(side*0.06,0.14,0.28),radius:0.027,mat:wing))}
        case .orb:
            let blue=surface("orb",0x8fc6ef,65)
            blue.emission.intensity=0.45
            for i in 0..<4 {let a=Double(i)*Double.pi/2;round(0.092,SCNVector3(cos(a)*0.235,0.045,sin(a)*0.235),SCNVector3(1,1,1),blue)}
            let g=SCNTorus(ringRadius:0.235,pipeRadius:0.009);g.ringSegmentCount=24;g.pipeSegmentCount=4;g.materials=[surface("orb-link",0x4b7a9f)]
            let n=SCNNode(geometry:g);n.position.y=0.045;root.addChildNode(n)
        default:break
        }
        return finish()
    }
}
