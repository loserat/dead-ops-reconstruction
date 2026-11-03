import Foundation
import SceneKit
import CoreGraphics

extension ArcadeGame {
    /// A revolved, closed profile with explicit normals and UVs. Built only with the arena.
    /// The first coordinate is radius, the second height; the profile runs around the shell.
    func landmarkProfile(_ profile:[V2],segments:Int=64,material:SCNMaterial,
                         scale:V2=V2(x:1,y:1),sheer:Double=0)->SCNNode {
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        for j in profile.indices {
            let p=profile[j],before=profile[max(0,j-1)],after=profile[min(profile.count-1,j+1)]
            let dr=after.x-before.x,dy=after.y-before.y
            for i in 0...segments {
                let t=Double(i)/Double(segments),a=t*Double.pi*2,c=cos(a),s=sin(a)
                let lift=sheer*pow(abs(s),6)*min(1,p.y/0.28)
                vertices.append(SCNVector3(p.x*c*scale.x,p.y+lift,p.x*s*scale.y))
                let x=dy*c/scale.x,z=dy*s/scale.y,y = -dr,length=max(1e-12,sqrt(x*x+y*y+z*z))
                normals.append(SCNVector3(x/length,y/length,z/length))
                uv.append(CGPoint(x:t*2,y:Double(j)/Double(profile.count-1)))
            }
        }
        for j in 0..<profile.count-1 {for i in 0..<segments {
            let a=Int32(j*(segments+1)+i),b=a+1,c=a+Int32(segments+1),d=c+1
            // Profile x angle has the same outward orientation as the explicit normals.
            indices += [a,c,b,b,c,d]
        }}
        return mesh(vertices,indices,uv:uv,normals:normals,mat:material)
    }

    func abandonedBoat()->SCNNode {
        let root=SCNNode()
        let hull=artMaterial("wood-boat-painted72-hull",0xc1bba8)
        hull.shininess=3;hull.specular.contents=rgb(0x090a08)
        let shell=landmarkProfile([
            V2(x:0,y:0.02),V2(x:0.30,y:0.02),V2(x:0.70,y:0.09),
            V2(x:0.96,y:0.28),V2(x:1,y:0.35),V2(x:0.85,y:0.35),
            V2(x:0.80,y:0.27),V2(x:0.47,y:0.085),V2(x:0,y:0.085)
        ],material:hull,scale:V2(x:0.43,y:1.65),sheer:0.04)
        root.addChildNode(shell)
        // A continuous gunwale makes the thickness readable, without loose subpixel strips.
        let trim=artMaterial("wood-boat-painted72-trim",0xdad6c5)
        let rail=landmarkProfile([
            V2(x:0.90,y:0.335),V2(x:1,y:0.335),V2(x:1,y:0.375),
            V2(x:0.84,y:0.375),V2(x:0.84,y:0.335),V2(x:0.90,y:0.335)
        ],material:trim,scale:V2(x:0.43,y:1.65),sheer:0.04)
        root.addChildNode(rail)
        let floor=artMaterial("wood-boat-floor72",0x66543e)
        for i in -1...1 {
            let plank=box(0.115,0.045,1.88,0x77664b)
            (plank.geometry as? SCNBox)?.chamferSegmentCount=1
            plank.geometry?.materials=[floor];plank.position=SCNVector3(Double(i)*0.12,0.12,0)
            root.addChildNode(plank)
        }
        for z in [-0.83,0,0.83] {
            let width=0.62*sqrt(1-pow(z/1.65,2))
            let seat=SCNNode(geometry:SCNBox(width:width,height:0.07,length:0.22,chamferRadius:0.015))
            (seat.geometry as? SCNBox)?.chamferSegmentCount=1
            seat.geometry?.materials=[trim];seat.position=SCNVector3(0,0.285,z);root.addChildNode(seat)
            for side in [-1.0,1.0] {
                let bracket=box(0.07,0.13,0.16,0x554e3c)
                (bracket.geometry as? SCNBox)?.chamferSegmentCount=1
                bracket.geometry?.materials=[floor];bracket.position=SCNVector3(side*(width/2-0.07),0.20,z);root.addChildNode(bracket)
            }
        }
        let merged=root.flattenedClone();merged.name="opening-island-boat";return merged
    }

    func courtyardFountain()->SCNNode {
        let root=SCNNode(),stone=openingStoneMaterial("fountain-basin73",tint:0xe7e4d6)
        stone.diffuse.intensity=1.25
        // One continuous outer wall, broad lip, inner wall and floor. No coincident discs.
        root.addChildNode(landmarkProfile([
            V2(x:0,y:0.025),V2(x:1.51,y:0.025),V2(x:1.65,y:0.08),
            V2(x:1.65,y:0.16),V2(x:1.57,y:0.20),V2(x:1.46,y:0.20),
            V2(x:1.46,y:0.34),V2(x:1.50,y:0.38),V2(x:1.50,y:0.47),
            V2(x:1.41,y:0.51),V2(x:1.32,y:0.48),V2(x:1.28,y:0.40),
            V2(x:1.25,y:0.16),V2(x:0,y:0.16)
        ],segments:8,material:stone))
        let pedestal=openingStoneMaterial("fountain-pedestal73",tint:0xeee9dc)
        pedestal.diffuse.intensity=1.25
        root.addChildNode(landmarkProfile([
            V2(x:0,y:0.17),V2(x:0.36,y:0.17),V2(x:0.42,y:0.24),
            V2(x:0.34,y:0.30),V2(x:0.24,y:0.70),V2(x:0.38,y:0.78),
            V2(x:0.62,y:0.83),V2(x:0.75,y:0.96),V2(x:0.73,y:1.03),
            V2(x:0.62,y:1.05),V2(x:0.58,y:0.99),V2(x:0.50,y:0.91),V2(x:0,y:0.87)
        ],segments:32,material:pedestal))
        let water=artMaterial("fountain-water67",0x87948a)
        water.lightingModel = .blinn;water.specular.contents=rgb(0x3d4840);water.shininess=24
        water.normal.contents=waterNormals();water.normal.intensity=0.16
        for property in [water.diffuse,water.normal] {
            property.minificationFilter = .linear;property.magnificationFilter = .linear
            property.mipFilter = .linear;property.maxAnisotropy=4
        }
        for (radius,y) in [(1.26,0.35),(0.51,0.94)] {
            let n=landmarkProfile([V2(x:0,y:y-0.015),V2(x:radius,y:y-0.015),V2(x:radius,y:y),V2(x:0,y:y)],segments:radius>1 ? 8:32,material:water)
            n.castsShadow=false;root.addChildNode(n)
        }
        let nozzle=cylinder(0.065,0.16,0x626b59);nozzle.position.y=1.03;root.addChildNode(nozzle)
        let spray=artMaterial("fountain-spray67",0xd3d9c8)
        spray.lightingModel = .lambert;spray.transparency=0.70;spray.writesToDepthBuffer=false
        // Six smooth tubes replace 96 separate tiny cylinders and ten high-contrast rings.
        // Geometry is static; there is no time-varying noise or per-frame mesh allocation.
        for ray in 0..<6 {
            let angle=Double(ray)*Double.pi/3,c=cos(angle),s=sin(angle)
            var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],indices:[Int32]=[]
            for j in 0...12 {
                let t=Double(j)/12,y=1.10+0.32*t-1.06*t*t,slope=0.32-2.12*t
                let length=sqrt(1+slope*slope),nx = -slope*c/length,ny=1/length,nz = -slope*s/length
                for i in 0...8 {
                    let a=Double(i)*Double.pi/4,u=cos(a),v=sin(a)
                    let dx=u*(-s)+v*nx,dy=v*ny,dz=u*c+v*nz,radius=0.023+0.004*t
                    vertices.append(SCNVector3(c*t+dx*radius,y+dy*radius,s*t+dz*radius))
                    normals.append(SCNVector3(dx,dy,dz))
                }
            }
            for j in 0..<12 {for i in 0..<8 {
                let a=Int32(j*9+i),b=a+1,c=a+9,d=c+1;indices += [a,c,b,b,c,d]
            }}
            let n=mesh(vertices,indices,normals:normals,mat:spray);n.castsShadow=false;root.addChildNode(n)
        }
        let merged=root.flattenedClone();merged.name="opening-courtyard-fountain";return merged
    }
}
