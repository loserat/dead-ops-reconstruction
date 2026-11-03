import Foundation
import SceneKit

extension ArcadeGame {
    func buildEnemyEntranceArt() {
        let kind=core.layout.kind
        if kind == .island {
            for (p,angle) in [(V2(x:15.3,y:1.3),0.0),(V2(x:-1.7,y:10.6),Double.pi/2)] {
                let shelter=SCNNode();shelter.name="pier-entry-shelter"
                for x in [-0.95,0.95] {for z in [-0.9,0.9] {
                    let post=box(0.11,2.1,0.11,0x73654d);post.position=SCNVector3(x,1.22,z);shelter.addChildNode(post)
                }}
                let roof=box(2.5,0.13,2.25,0x6b674e);roof.position.y=2.3;shelter.addChildNode(roof)
                shelter.position=SCNVector3(p.x,0,p.y);shelter.eulerAngles.y=NodeFloat(angle);decor.addChildNode(shelter)
            }
            return
        }
        let group=SCNNode();group.name="enemy-entrances"
        if kind == .prison {
            for x in [-4.0,4.0] {
                let bridge=SCNNode()
                for i in 0..<15 {
                    let plank=box(2.4,0.10,0.24,0x737b6a);plank.position=SCNVector3(x,1.55,7.6+Double(i)*0.24);bridge.addChildNode(plank)
                }
                for side in [-1.0,1] {
                    bridge.addChildNode(beam(SCNVector3(x+side*1.18,1.6,7.5),SCNVector3(x+side*1.18,1.6,11.3),radius:0.065,mat:material(0x505e53)))
                }
                group.addChildNode(bridge.flattenedClone())
                addEntryPassage(to:group,x:x,side:1,mouth:10.1,start:11.3,height:1.6)
            }
            for index in 2..<core.layout.enemyEntranceCount {
                let a=core.layout.enemyArrival(index:index),mouth:Double=index<4 ? 12:7.9
                addCardinalEntry(to:group,side:core.layout.enemyEntrySide(index:index),offset:index<4 ? 0:a.end.p.x,mouth:mouth,start:index<4 ? 16:11.6,height:0,ceiling:1.5)
            }
        }else if kind == .forest || kind == .jungle {
            for side in EntrySide.allCases {
                let local=SCNNode(),long=side == .east || side == .west
                local.eulerAngles.y=NodeFloat(side == .east ? Double.pi/2:side == .west ? -Double.pi/2:side == .north ? Double.pi:0)
                let path=box(2.7,0.018,5.5,kind == .forest ? 0x89968b:0x66734b);path.position=SCNVector3(0,0.006,long ? 14:9.7);path.opacity=0.40;path.castsShadow=false;local.addChildNode(path)
                for x in [-1.8,1.8] {
                    let tree=kind == .forest ? winterTree(seed:UInt64(x<0 ? 1701:1702),height:4.2):palm(seed:UInt64(x<0 ? 1703:1704),height:4.8).flattenedClone()
                    tree.position=SCNVector3(x,0,long ? 17:12.6);local.addChildNode(tree)
                }
                group.addChildNode(local)
            }
        }else{
            for side in EntrySide.allCases {
                let cross=side == .east || side == .west
                let offset=core.layout.entryCrossOffset(side:side)
                let h=kind == .street && side == .east ? StreetLayout.deck:kind == .urban && side == .west ? UrbanLayout.deck:0
                addCardinalEntry(to:group,side:side,offset:offset,mouth:kind == .cave ? (cross ? 9.45:6.45):(cross ? 12:8.1),start:kind == .cave ? (cross ? 13.5:10):(cross ? 16.5:11.4),height:h)
            }
        }

        decor.addChildNode(group)
    }
    func addCardinalEntry(to group:SCNNode,side:EntrySide,offset:Double,mouth:Double,start:Double,height:Double,ceiling:Double=3.5) {
        let local=SCNNode();local.name="entry-\(side.rawValue)"
        local.eulerAngles.y=NodeFloat(side == .east ? Double.pi/2:side == .west ? -Double.pi/2:side == .north ? Double.pi:0)
        if side == .east || side == .west {local.position.z=NodeFloat(offset)}else{local.position.x=NodeFloat(offset)}
        addEntryPassage(to:local,x:0,side:1,mouth:mouth,start:start,height:height,ceiling:ceiling)
        group.addChildNode(local)
    }
    func addEntryPassage(to group:SCNNode,x:Double,side:Double,mouth:Double,start:Double,height:Double,ceiling:Double=3.5) {
        let passage=SCNNode();passage.name="entry-passage"
        let kind=core.layout.kind,depth=start-mouth,center=(start+mouth)/2
        // Own map-specific masonry/wood/metal; the simulation's entrance path stays unchanged.
        let tint:Int,trim:Int,style:String,profile:Double
        switch kind {
        case .courtyard:tint=0x867c65;trim=0x9c9075;style="stone-entry-courtyard";profile=2.25
        case .prison:tint=0x626b64;trim=0x7a8379;style="plaster-entry-prison";profile=2.6
        case .cave:tint=0x5f6656;trim=0x7b7e65;style="rock-entry-cave";profile=2.3
        case .marketplace:tint=0x79644e;trim=0x9b8260;style="wood-entry-market";profile=2.4
        case .urban,.street:tint=0x78786b;trim=0x9a9b88;style="plaster-entry-city";profile=2.8
        case .facility:tint=0x5e6c69;trim=0x8e9d95;style="metal-entry-facility";profile=2.7
        default:tint=0x69715e;trim=0x8b9075;style="stone-entry";profile=2.4
        }
        let ceiling=ceiling==3.5 ? profile:ceiling
        let wallMaterial=artMaterial(style,tint),trimMaterial=artMaterial(style+"-trim",trim)
        let floor=box(3.2,0.16,CGFloat(depth+0.6),0x71776a);floor.geometry?.materials=[artMaterial("stone-entry-floor",0x777564)]
        floor.position=SCNVector3(x,height-0.08,side*center);passage.addChildNode(floor)
        for dx in [-1.7,1.7] {
            let wall=stoneBlock(0.38,ceiling-0.1,depth+0.6,tint);wall.geometry?.materials=[wallMaterial]
            wall.position=SCNVector3(x+dx,height+(ceiling-0.1)/2,side*center);passage.addChildNode(wall)
            let jamb=box(0.48,CGFloat(ceiling+0.02),0.46,trim);jamb.geometry?.materials=[trimMaterial]
            jamb.position=SCNVector3(x+dx,height+ceiling/2,side*mouth);passage.addChildNode(jamb)
        }
        // Open near portal and a roof only over the far birth shelter keep the approach visible.
        let lintel=stoneBlock(3.88,0.19,0.5,trim);lintel.geometry?.materials=[trimMaterial]
        lintel.position=SCNVector3(x,height+ceiling,side*mouth);passage.addChildNode(lintel)
        for i in 0..<6 {
            let plank=box(3.8,0.10,0.30,tint);plank.geometry?.materials=[artMaterial(kind == .facility ? "metal-entry-roof":"wood-entry-roof",kind == .facility ? 0x697a76:0x74664e)]
            plank.position=SCNVector3(x,height+ceiling,side*(start-1.35+Double(i)*0.31));passage.addChildNode(plank)
        }
        let back=box(3.6,CGFloat(ceiling),0.22,0x18251e);back.position=SCNVector3(x,height+ceiling/2,side*(start+0.25));passage.addChildNode(back)
        group.addChildNode(passage.flattenedClone())
    }
    func sideFacadeWithOpening(x:Double,center:Double=0,span:Double,width:Double,height:Double,base:Double=0,openingCenter:Double=0,color:Int)->SCNNode {
        let root=SCNNode();root.name="facade-with-entry"
        for (lo,hi) in [(center-span/2,openingCenter-1.7),(openingCenter+1.7,center+span/2)] where hi>lo {
            let n=stoneBlock(width,height,hi-lo,color);n.position=SCNVector3(x,base+height/2,(lo+hi)/2);root.addChildNode(n)
        }
        return root
    }
    func syncEnemyEntryArt() {
        let marked=core.foes.filter{($0.arrival?.kind == .water && $0.elevation > -1.1 && $0.elevation < -0.05) || ($0.kind == .engineer && $0.elevation>core.layout.height($0.p)+0.15)}
        sync(&entryMarkerNodes,ids:Set(marked.map(\.id)))
        for f in marked {
            let water=f.arrival?.kind == .water
            let n:SCNNode
            if let old=entryMarkerNodes[f.id] {n=old}else{
                let torus=SCNTorus(ringRadius:water ? 0.32:0.48,pipeRadius:water ? 0.014:0.021)
                let mat=material(water ? 0xb4dfe1:0xe4c681);mat.lightingModel = .constant;mat.transparency=0.6
                torus.materials=[mat];n=SCNNode(geometry:torus);n.castsShadow=false;entryMarkerNodes[f.id]=n;actors.addChildNode(n)
            }
            n.position=SCNVector3(f.p.x,water ? -0.215:core.layout.height(f.p)+0.025,f.p.y)
            let pulse=water ? 0.85+0.28*sin(core.elapsed*8+Double(f.id)):1.0+min(8,f.elevation-core.layout.height(f.p))*0.055
            n.scale=SCNVector3(pulse,1,pulse);n.opacity=water ? 0.42:0.58
        }
    }
}
