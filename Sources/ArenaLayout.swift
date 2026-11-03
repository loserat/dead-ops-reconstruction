import Foundation

enum ArenaKind: Int,CaseIterable { case island, courtyard, prison, cave, marketplace, urban, street, facility, forest, jungle
    var title:String {self == .island ? "INSEL":self == .courtyard ? "INNENHOF":self == .prison ? "GEFÄNGNIS":self == .cave ? "HÖHLE":self == .marketplace ? "MARKTPLATZ":self == .urban ? "STADT":self == .street ? "STRASSE":self == .facility ? "SCHNEEBUNKER":self == .forest ? "SCHNEEWALD":"DSCHUNGEL"}
}
/// Both art and collision use these dimensions. Values are approximations from the video.
struct ArenaObstacle {
    enum Shape {case circle(Double), rectangle(V2)}
    let p:V2, shape:Shape, angle:Double, elevation:Double, height:Double
    private let cosine:Double,sine:Double
    init(_ p:V2,radius:Double,elevation:Double=0,height:Double=1.2){self.p=p;shape = .circle(radius);angle=0;cosine=1;sine=0;self.elevation=elevation;self.height=height}
    init(_ p:V2,half:V2,angle:Double=0,elevation:Double=0,height:Double=1.2){self.p=p;shape = .rectangle(half);self.angle=angle;cosine=cos(angle);sine=sin(angle);self.elevation=elevation;self.height=height}
    func local(_ q:V2)->V2 {let v=q-p;return V2(x:v.x*cosine-v.y*sine,y:v.x*sine+v.y*cosine)}
    func world(_ q:V2)->V2 {p+V2(x:q.x*cosine+q.y*sine,y:-q.x*sine+q.y*cosine)}
    func pushed(_ point:V2,clearance:Double)->V2 {
        let q=local(point)
        switch shape {
        case .circle(let radius):
            let r=radius+clearance
            return q.length<r ? world((q.length>0.0001 ? q.unit:V2(x:1,y:0))*r):point
        case .rectangle(let half):
            let near=V2(x:max(-half.x,min(half.x,q.x)),y:max(-half.y,min(half.y,q.y))),delta=q-near
            if delta.length>0.0001 {return delta.length<clearance ? world(near+delta.unit*clearance):point}
            let dx=half.x-abs(q.x),dy=half.y-abs(q.y)
            return dx<dy ? world(V2(x:(q.x<0 ? -1:1)*(half.x+clearance),y:q.y)) : world(V2(x:q.x,y:(q.y<0 ? -1:1)*(half.y+clearance)))
        }
    }
    func contains(_ point:V2,clearance:Double)->Bool {(pushed(point,clearance:clearance)-point).length>0.00001}
    func clearsSegment(from a:V2,to b:V2,clearance:Double)->Bool {
        switch shape {
        case .circle(let radius):return p.distance(toSegmentFrom:a,to:b)>=radius+clearance-0.00001
        case .rectangle(let half):
            let u=local(a),v=local(b),delta=v-u
            var lo=0.0,hi=1.0
            for (start,d,extent) in [(u.x,delta.x,half.x),(u.y,delta.y,half.y)] {
                if abs(d)<1e-12 {if abs(start)>extent {lo=1;hi=0;break}}
                else {
                    let t0=(-extent-start)/d,t1=(extent-start)/d
                    lo=max(lo,min(t0,t1));hi=min(hi,max(t0,t1))
                }
            }
            if lo<=hi {return false}
            func edgeDistance(_ q:V2)->Double {hypot(max(0,abs(q.x)-half.x),max(0,abs(q.y)-half.y))}
            var distance=min(edgeDistance(u),edgeDistance(v))
            for x in [-half.x,half.x] {for y in [-half.y,half.y] {
                distance=min(distance,V2(x:x,y:y).distance(toSegmentFrom:u,to:v))
            }}
            return distance>=clearance-0.00001
        }
    }
}

struct ArenaLayout {
    let kind:ArenaKind
    var bonusRoom:SideRoomKind?=nil
    var runtimeTraps:[ElectricTrap]?=nil,runtimeObstacles:[ArenaObstacle]?=nil
    var hazardRevision=0
    static let treasurePiles=[V2(x:-5.2,y:-3.3),V2(x:5.2,y:-3.3),V2(x:-5.2,y:3.3),V2(x:5.2,y:3.3)]
    // Leave a tank-width aisle between prison treasure chests and the four towers.
    // Layout and art share these centers, including the surrounding loot ring.
    var treasurePileCenters:[V2] {if kind == .facility {return FacilityLayout.piles};if kind == .urban {return UrbanLayout.piles};return kind == .cave ? CaveLayout.piles:kind == .prison ? [V2(x:-3.2,y:-2.5),V2(x:3.2,y:-2.5),V2(x:-3.2,y:2.5),V2(x:3.2,y:2.5)]:Self.treasurePiles}
    static let lastRound=40
    static func forRound(_ round:Int)->ArenaLayout {let r=RoundRules.stage(round);return ArenaLayout(kind:r<=4 ? .island:r<=8 ? .courtyard:r<=12 ? .prison:r<=16 ? .cave:r<=20 ? .marketplace:r<=24 ? .urban:r<=28 ? .street:r<=32 ? .facility:r<=36 ? .forest:.jungle)}
    var spawn:V2 {kind == .island ? .zero:V2(x:0,y:kind == .prison ? -3.6:-4.8)}
    var entry:V2 {kind == .prison ? spawn:V2(x:0,y:-5.5)}
    func height(_ p:V2)->Double {if kind == .street {return StreetLayout.height(p)};return kind == .urban ? UrbanLayout.height(p):kind == .prison ? PrisonLayout.height(p):0}
    func canTraverse(_ a:V2,_ b:V2)->Bool {if kind == .street {return StreetLayout.allows(a,b)};return kind == .urban ? UrbanLayout.allows(a,b):kind != .prison || PrisonLayout.allows(a,b)}
    var exit:V2 {V2(x:kind == .urban ? 4.5:0,y:kind == .urban ? 6.6:kind == .prison ? 7.0:kind == .cave ? 5.2:kind == .courtyard || kind == .marketplace || kind == .street || kind == .facility || kind == .forest || kind == .jungle ? 6.6:6.2)}
    func sideRoute(onLeft:Bool)->V2 {V2(x:(onLeft ? -1:1)*(kind == .cave ? 7.5:9.5),y:kind == .urban || kind == .street ? 6.0:kind == .cave ? 4.5:5.35)}
    var armoryRackX:Double {kind == .cave ? 8.2:10.6}
    // Layouts are immutable combinations of arena and room. Share their exact existing
    // obstacle arrays instead of rebuilding/retaining temporary geometry at every line sample.
    private static let obstacleCache:[[ArenaObstacle]]=ArenaKind.allCases.flatMap { kind in
        ([nil,.treasure,.armory,.fate] as [SideRoomKind?]).map { room in
            var layout=ArenaLayout(kind:kind);layout.bonusRoom=room;return layout.uncachedObstacles
        }
    }
    private static let previewObstacleCache:[[ArenaObstacle]]=ArenaKind.allCases.flatMap { kind in
        ([nil,.treasure,.armory,.fate] as [SideRoomKind?]).map { room in
            var l=ArenaLayout(kind:kind);l.bonusRoom=room
            return l.staticObstacles+l.traps.map{ArenaObstacle($0.p,radius:ElectricTrap.solidRadius,elevation:l.height($0.p),height:1.2)}
        }
    }
    var staticObstacles:[ArenaObstacle] {Self.obstacleCache[kind.rawValue*4+(bonusRoom.map{$0.rawValue+1} ?? 0)]}
    var obstacles:[ArenaObstacle] {runtimeObstacles ?? Self.previewObstacleCache[kind.rawValue*4+(bonusRoom.map{$0.rawValue+1} ?? 0)]}
    private var uncachedObstacles:[ArenaObstacle] {
        let base=kind == .jungle ? JungleLayout.obstacles:kind == .forest ? ForestLayout.obstacles:kind == .facility ? FacilityLayout.obstacles:kind == .street ? StreetLayout.obstacles:kind == .urban ? UrbanLayout.obstacles:kind == .island ? [OpeningMapDesign.boat] : kind == .prison ? PrisonLayout.obstacles : kind == .cave ? CaveLayout.obstacles: kind == .marketplace ? MarketplaceLayout.obstacles: [ArenaObstacle(.zero,radius:OpeningMapDesign.fountainRadius)]
        if bonusRoom == .treasure {return base+treasurePileCenters.map{ArenaObstacle($0,half:V2(x:0.55,y:0.4),elevation:height($0),height:0.65)}}
        if bonusRoom == .armory {return base+[-1.0,1].map{ArenaObstacle(V2(x:$0*armoryRackX,y:0),half:V2(x:0.35,y:1.5),elevation:height(V2(x:$0*armoryRackX,y:0)),height:1.4)}}
        return base
    }
    // Preview sites are only editable map anchors. Actual game instances come from GameCore.
    var hazardSites:[V2] {
        switch kind {
        case .island:return []
        case .courtyard:return [V2(x:-7,y:-3.7),V2(x:7,y:-3.7),V2(x:-7,y:3.7),V2(x:7,y:3.7)]
        case .prison:return PrisonLayout.trapPositions
        case .cave:return CaveLayout.traps
        case .marketplace:return MarketplaceLayout.traps
        case .urban:return UrbanLayout.traps
        case .street:return StreetLayout.traps
        case .facility:return FacilityLayout.traps
        case .forest:return ForestLayout.traps
        case .jungle:return JungleLayout.traps
        }
    }
    var traps:[ElectricTrap] {runtimeTraps ?? hazardSites.enumerated().map{ElectricTrap(p:$0.element,offset:0,id:$0.offset,elevation:height($0.element),seed:UInt64($0.offset))}}
    func contains(_ p:V2,margin:Double=0)->Bool {
        kind == .island ? IslandLayout.contains(p,margin:margin) : abs(p.x)<=(kind == .cave ? CaveLayout.width:11.6)-margin+1e-9 && abs(p.y)<=(kind == .cave ? CaveLayout.depth:7.6)-margin+1e-9
    }
    func boundary(_ p:V2,clearance:Double)->V2 {
        if kind == .island {return IslandLayout.clamped(p)}
        let w=kind == .cave ? CaveLayout.width:11.6,d=kind == .cave ? CaveLayout.depth:7.6
        return V2(x:max(-w+clearance,min(w-clearance,p.x)),y:max(-d+clearance,min(d-clearance,p.y)))
    }
    func clamped(_ p:V2,clearance:Double=0.29)->V2 {
        var q=boundary(p,clearance:clearance)
        let geometry=obstacles
        for _ in 0..<2 {for o in geometry{q=o.pushed(q,clearance:clearance)};q=boundary(q,clearance:clearance)}
        if geometry.contains(where:{$0.contains(q,clearance:clearance)}) || (q-p).length>max(0.3,clearance*1.5) {
            // Touching expanded solids can push a body back into a previously processed
            // neighbor. Resolve the union, not merely the final individual obstacle.
            for _ in 0..<12 {
                for o in geometry {q=o.pushed(q,clearance:clearance)}
                q=boundary(q,clearance:clearance)
                if !geometry.contains(where:{$0.contains(q,clearance:clearance)}) {break}
            }
            let origin=boundary(p,clearance:clearance)
            var nearest:V2? = geometry.contains(where:{$0.contains(q,clearance:clearance)}) ? nil:q
            func consider(_ candidate:V2) {
                guard contains(candidate,margin:clearance),!geometry.contains(where:{$0.contains(candidate,clearance:clearance)}) else{return}
                if nearest==nil || (candidate-origin).length<(nearest!-origin).length {nearest=candidate}
            }
            for obstacle in geometry {consider(obstacle.pushed(origin,clearance:clearance))}
            let circles=geometry.compactMap { obstacle -> (V2,Double)? in
                if case .circle(let r)=obstacle.shape {return (obstacle.p,r+clearance)};return nil
            }
            for i in circles.indices {for j in circles.indices where j>i {
                let (a,ra)=circles[i],(b,rb)=circles[j],delta=b-a,d=delta.length
                guard d>1e-9,d<=ra+rb,d>=abs(ra-rb) else{continue}
                let along=(ra*ra-rb*rb+d*d)/(2*d),h=sqrt(max(0,ra*ra-along*along)),axis=delta*(1/d)
                let mid=a+axis*along,side=V2(x:-axis.y,y:axis.x)*h
                consider(mid+side);consider(mid-side)
            }}
            if let nearest {return nearest}
            for ring in 1...60 {
                for ray in 0..<32 {
                    let a=Double(ray)*Double.pi/16
                    let candidate=boundary(origin+V2(x:cos(a),y:sin(a))*(Double(ring)*0.05),clearance:clearance)
                    if !geometry.contains(where:{$0.contains(candidate,clearance:clearance)}) {return candidate}
                }
            }
        }
        return q
    }
    func walkable(_ p:V2,clearance:Double=0.29)->Bool {contains(p,margin:clearance) && !obstacles.contains{$0.contains(p,clearance:clearance)}}
    func lineClear(_ a:V2,_ b:V2,clearance:Double=0.29)->Bool {
        let n=max(1,Int(ceil((b-a).length/0.13)))
        let geometry=obstacles
        guard contains(a,margin:clearance),contains(b,margin:clearance),geometry.allSatisfy({$0.clearsSegment(from:a,to:b,clearance:clearance)}) else{return false}
        var previous=a
        for i in 0...n {
            let p=a+(b-a)*(Double(i)/Double(n))
            if !canTraverse(previous,p){return false}
            previous=p
        }
        return true
    }
    func moved(_ p:V2,by delta:V2,clearance:Double=0.29)->V2 {
        var q=p
        let geometry=obstacles
        func legal(_ a:V2,_ b:V2)->Bool {canTraverse(a,b) && geometry.allSatisfy{$0.clearsSegment(from:a,to:b,clearance:clearance)}}
        let n=max(1,Int(ceil(delta.length/0.14)))
        for _ in 0..<n {
            let step=delta*(1/Double(n)),candidate=clamped(q+step,clearance:clearance)
            if legal(q,candidate) {q=candidate}
            else {
                let x=clamped(q+V2(x:step.x,y:0),clearance:clearance)
                if legal(q,x) {q=x}
                let y=clamped(q+V2(x:0,y:step.y),clearance:clearance)
                if legal(q,y) {q=y}
            }
        }
        return q
    }
}

/// A shared flood map steers the horde around solid props, including from the far side of the fountain.
final class ArenaNavigation {
    private let nx=47,ny=31,cell=0.5
    private let clearance:Double
    init(clearance:Double=0.29){self.clearance=clearance}
    private var distances:[Int]=[],valid:[Bool]=[],heights:[Double]=[],incoming:[[Int]]=[]
    private var lastKind:ArenaKind?,lastBonus:SideRoomKind?,lastTarget = -1,lastHazardRevision = -1
    private var age=1.0
    private let neighbors=[(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)]
    private func point(_ i:Int)->V2 {V2(x:Double(i%nx)*cell-11.5,y:Double(i/nx)*cell-7.5)}
    private func index(_ p:V2)->Int {max(0,min(ny-1,Int(((p.y+7.5)/cell).rounded())))*nx+max(0,min(nx-1,Int(((p.x+11.5)/cell).rounded())))}
    private func surfaceIndex(_ p:V2,layout:ArenaLayout)->Int {
        let guess=index(p),height=layout.height(p)
        if valid[guess] && abs(heights[guess]-height)<0.4 {return guess}
        // Same nearest cell and first-index tie break, without a temporary filtered array
        // or recomputing static floor heights for every actor near a stair/obstacle.
        var best:Int?,distance=0.0
        for i in valid.indices where valid[i] && abs(heights[i]-height)<0.4 {
            let candidate=(point(i)-p).length
            if best==nil || candidate<distance {best=i;distance=candidate}
        }
        return best ?? guess
    }
    func update(layout:ArenaLayout,target:V2,dt:Double) {
        age+=dt
        let kindChanged=lastKind != layout.kind || lastBonus != layout.bonusRoom || lastHazardRevision != layout.hazardRevision
        if kindChanged {
            valid=(0..<nx*ny).map{layout.walkable(point($0),clearance:clearance)}
            heights=(0..<nx*ny).map{layout.height(point($0))}
            incoming=Array(repeating:[],count:nx*ny)
            for i in 0..<nx*ny where valid[i] {
                let x=i%nx,y=i/nx
                for (dx,dy) in neighbors {
                    let xx=x+dx,yy=y+dy
                    guard xx>=0,xx<nx,yy>=0,yy<ny else{continue}
                    let j=yy*nx+xx
                    guard valid[j] else{continue}
                    // Whole-cell height deltas can hide an impossible stair-side step.
                    if layout.lineClear(point(j),point(i),clearance:clearance) {incoming[i].append(j)}
                }
            }
            lastKind=layout.kind;lastBonus=layout.bonusRoom;lastHazardRevision=layout.hazardRevision
        }
        let goal=surfaceIndex(target,layout:layout)
        guard kindChanged || goal != lastTarget || age>0.25 else{return}
        lastTarget=goal;age=0;distances=Array(repeating:Int.max,count:nx*ny)
        var queue=[goal],head=0;distances[goal]=0
        while head<queue.count {
            let i=queue[head];head+=1;let x=i%nx,y=i/nx
            for j in incoming[i] {
                let dx=j%nx-x,dy=j/nx-y
                let candidate=distances[i]+(dx != 0 && dy != 0 ? 14:10)
                if candidate<distances[j] {distances[j]=candidate;queue.append(j)}
            }
        }
    }
    func direction(from p:V2,to target:V2,layout:ArenaLayout)->V2 {
        if layout.lineClear(p,target,clearance:clearance){return (target-p).unit}
        guard !distances.isEmpty else{return .zero}
        let i=surfaceIndex(p,layout:layout),x=i%nx,y=i/nx
        var best:V2?,cost=Double.greatestFiniteMagnitude
        for dy in -2...2 {for dx in -2...2 {
            let xx=x+dx,yy=y+dy
            guard xx>=0,xx<nx,yy>=0,yy<ny else{continue}
            let j=yy*nx+xx,q=point(j)
            guard distances[j]<distances[i],layout.lineClear(p,q,clearance:clearance) else{continue}
            let c=Double(distances[j])/10+(q-p).length/cell+(q-target).length*0.0001
            if c<cost {cost=c;best=q}
        }}
        if let best {return (best-p).unit}
        let center=point(i)
        if (center-p).length>0.003 && layout.lineClear(p,center,clearance:clearance) {return (center-p).unit}
        // A point can sit at a stair lip between grid cells: a short legal axis move
        // may be needed before it can join the coarse navigation grid.
        var escape:V2?,escapeCost=Double.greatestFiniteMagnitude
        var escapeDirections=(0..<16).map { step in let a=Double(step)*Double.pi/8;return V2(x:cos(a),y:sin(a)) }
        let normals=layout.obstacles.compactMap { obstacle -> V2? in
            let out=obstacle.pushed(p,clearance:clearance+0.03)-p
            return out.length>0.00001 ? out.unit:nil
        }
        escapeDirections+=normals
        for i in normals.indices {for j in normals.indices where j>i {
            let bisector=normals[i]+normals[j]
            if bisector.length>0.00001 {escapeDirections.append(bisector.unit)}
        }}
        let combined=normals.reduce(V2.zero,+)
        if combined.length>0.00001 {escapeDirections.append(combined.unit)}
        for radius in [0.25,0.50,0.75,1.0,1.5] {
            for direction in escapeDirections {
                let q=p+direction*radius
                guard layout.lineClear(p,q,clearance:clearance) else{continue}
                let j=surfaceIndex(q,layout:layout)
                guard distances[j]<Int.max,layout.lineClear(q,point(j),clearance:clearance) else{continue}
                let c=Double(distances[j])/10+(q-p).length/cell+(point(j)-q).length/cell
                if c<escapeCost {escape=q;escapeCost=c}
            }
        }
        return escape.map{($0-p).unit} ?? .zero
    }
}
