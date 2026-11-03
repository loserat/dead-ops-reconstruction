import Foundation

/// Own editable opening arenas. Physical footprints and rendered landmarks share these anchors.
/// These are not measurements of the original game's maps.
enum OpeningMapDesign {
    struct RuinedWall {
        let length:Double,depth:Double,height:Double,base:Double,seed:UInt64
        var top:[V2] {
            let count=max(3,Int(ceil(length/0.7)))
            return (0...count).map { i in
                var hash=(seed ^ UInt64(i)) &* 0x9e3779b97f4a7c15
                hash=(hash ^ (hash>>29)) &* 0xbf58476d1ce4e5b9
                let fraction=0.62+Double((hash>>32)%39)/100
                return V2(x:(Double(i)/Double(count)-0.5)*length,y:base+height*fraction)
            }
        }
    }
    // Door leaves sit at the rear wall, wholly beyond playable ground even when open.
    static let courtyardDoorCenters=[V2(x:-2.65,y:-8.05),V2(x:2.65,y:-8.05)]
    /// Visual sand bank only; playable grass, obstacle footprints and arrivals do not move.
    static func coastalBank(angle:Double,fraction:Double)->(radius:Double,height:Double,wetness:Double) {
        let f=max(0,min(1,fraction)),t=max(0,min(1,(f-0.80)/0.20)),wet=t*t*(3-2*t)
        let variation=0.026*sin(angle*3+0.7)+0.014*cos(angle*8-0.3)+0.009*sin(angle*17)
        return (1+pow(f,6)*variation,0.005-0.14*pow(f,12),wet)
    }
    /// Own chipped paving profiles. All stones remain on the existing continuous ground;
    /// missing edge stones reveal the prepared soil field, not a gameplay hole.
    struct Stone {
        let outline:[V2],missing:Bool
        static let half=0.276,thickness=0.035,spacing=0.57
    }
    static func courtyardStone(ix:Int,iz:Int)->Stone {
        let seed=(UInt64(bitPattern:Int64(ix)) &* 73856093) ^ (UInt64(bitPattern:Int64(iz)) &* 19349663) ^ 0x71ca7
        let h=Stone.half,corners=[V2(x:-h,y:-h),V2(x:h,y:-h),V2(x:h,y:h),V2(x:-h,y:h)]
        var outline=[V2]()
        for i in 0..<4 {
            let bits=(seed>>UInt64(i*11))&1023
            let cut=bits%4==0 ? 0:0.024+Double(bits%12)*0.005
            let corner=corners[i]
            if cut==0 {outline.append(corner)}
            else {
                outline.append(corner+(corners[(i+3)%4]-corner).unit*cut)
                outline.append(corner+(corners[(i+1)%4]-corner).unit*cut)
            }
        }
        let p=V2(x:Double(ix)*Stone.spacing,y:Double(iz)*Stone.spacing)
        let boundary=(abs(abs(p.x)-2.05)<0.48 && abs(p.y)>2.8) || (abs(abs(p.y)-1.65)<0.48 && abs(p.x)>2.8)
        return Stone(outline:outline,missing:boundary && seed%11==0)
    }
    struct Path {
        let points:[V2],width:Double
        func distance(_ p:V2)->Double {
            var nearest=Double.infinity
            for i in 1..<points.count {nearest=min(nearest,p.distance(toSegmentFrom:points[i-1],to:points[i]))}
            return nearest
        }
    }
    struct Pier {
        let entrance:Int,center:V2,angle:Double,length:Double
        let outside:V2,hinge:V2,landing:V2
        let deckHeight=0.22,width=2.05
        func route(lane:Double)->EnemyArrival {
            let cross=abs(outside.x-hinge.x)>abs(outside.y-hinge.y) ? V2(x:0,y:lane):V2(x:lane,y:0)
            return EnemyArrival(kind:.pier,points:[EnemyEntryPoint(p:outside+cross,height:deckHeight),EnemyEntryPoint(p:hinge+cross,height:deckHeight),EnemyEntryPoint(p:landing+cross,height:0)])
        }
        func surfaceHeight(_ p:V2)->Double {
            let delta=landing-hinge,t=max(0,min(1,((p-hinge).x*delta.x+(p-hinge).y*delta.y)/(delta.length*delta.length)))
            return deckHeight*(1-t)
        }
    }
    static let boat=ArenaObstacle(V2(x:-7,y:1.3),half:V2(x:0.46,y:1.7),angle:-0.12,height:0.5)
    static let hut=V2(x:-13.4,y:-7.8)
    static let fountainRadius=1.65
    static let piers=[
        Pier(entrance:4,center:V2(x:13.5,y:1.3),angle:0,length:5,outside:V2(x:15.5,y:1.3),hinge:V2(x:11,y:1.3),landing:V2(x:9.6,y:1.3)),
        Pier(entrance:5,center:V2(x:-1.7,y:9.4),angle:Double.pi/2,length:4.8,outside:V2(x:-1.7,y:11.1),hinge:V2(x:-1.7,y:7),landing:V2(x:-1.7,y:5.8))]
    static let islandPaths=[
        Path(points:[V2(x:9.6,y:1.3),V2(x:6,y:1),V2(x:2.5,y:0.8),.zero],width:1.3),
        Path(points:[V2(x:-1.7,y:5.8),V2(x:-1.8,y:3.4),V2(x:-0.7,y:1.8),.zero],width:1.1),
        Path(points:[V2(x:-10,y:0),V2(x:-8,y:-1.2),V2(x:-5.2,y:-1.5),V2(x:-2,y:0),.zero],width:0.9),
        Path(points:[V2(x:3,y:-5.9),V2(x:3,y:-4),V2(x:2,y:-2),.zero],width:0.85),
        Path(points:[V2(x:4,y:5.8),V2(x:4,y:4),V2(x:2.5,y:2.5),.zero],width:0.85)]
    static func isCourtyardPath(_ p:V2)->Bool {
        abs(p.x)<2.05 || abs(p.y)<1.65 || abs(p.x)>10.55 || abs(p.y)>6.65 || p.length<2.45
    }
}
