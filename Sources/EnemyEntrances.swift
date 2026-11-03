import Foundation

enum EnemyEntryKind {case water,pier,passage,trail,catwalk}
struct EnemyEntryPoint {let p:V2,height:Double}
struct EnemyArrival {
    let kind:EnemyEntryKind,points:[EnemyEntryPoint]
    private(set) var next=1
    private(set) var heading=V2.zero
    var start:EnemyEntryPoint {points[0]}
    var end:EnemyEntryPoint {points[points.count-1]}
    /// Consume a distance budget across waypoints. No boundary clamp or teleport during approach.
    mutating func advance(position:inout V2,height:inout Double,distance:Double)->Bool {
        var remaining=max(0,distance)
        while next<points.count {
            let target=points[next],delta=target.p-position,length=delta.length
            if length<0.000001 {height=target.height;next+=1;continue}
            guard remaining>0 else{break}
            heading=delta.unit
            let used=min(remaining,length),fraction=used/length
            position=position+delta*fraction;height+=(target.height-height)*fraction
            remaining-=used
            if used>=length {position=target.p;height=target.height;next+=1}
        }
        return next==points.count
    }
}

extension ArenaLayout {
    var enemyEntranceCount:Int {kind == .island || kind == .prison ? 6:4}
    func enemyArrival(index:Int,lane:Double=0)->EnemyArrival {
        let route=((index%enemyEntranceCount)+enemyEntranceCount)%enemyEntranceCount,j=max(-1,min(1,lane))*0.32
        func point(_ x:Double,_ y:Double,_ h:Double=0)->EnemyEntryPoint {EnemyEntryPoint(p:V2(x:x,y:y),height:h)}
        if kind == .island {
            switch route {
            case 0:return EnemyArrival(kind:.water,points:[point(-16.2,j,-1.6),point(-14.1,j,-0.55),point(-12.6,j,0),point(-9.7,j)])
            case 1:return EnemyArrival(kind:.water,points:[point(3.0+j,-12.0,-1.6),point(3.0+j,-9.5,-0.55),point(3.0+j,-8.5,0),point(3.0+j,-5.9)])
            case 2:return EnemyArrival(kind:.water,points:[point(16.1,-1.7+j,-1.6),point(14.0,-1.7+j,-0.55),point(12.5,-1.7+j,0),point(9.6,-1.7+j)])
            case 3:return EnemyArrival(kind:.water,points:[point(4.0+j,12.0,-1.6),point(4.0+j,9.5,-0.55),point(4.0+j,8.5,0),point(4.0+j,5.8)])
            case 4:return OpeningMapDesign.piers[0].route(lane:j)
            default:return OpeningMapDesign.piers[1].route(lane:j)
            }
        }
        if kind == .prison {
            if route<2 {let x=(route==0 ? -4.0:4.0)+j;return EnemyArrival(kind:.catwalk,points:[point(x,10.6,1.6),point(x,7.0,1.6),point(x,6.3,1.6)])}
            if route==2 || route==3 {let side=route==2 ? -1.0:1.0;return EnemyArrival(kind:.passage,points:[point(side*15.5,j),point(side*11.9,j),point(side*7.4,j)])}
            let side=route==4 ? -1.0:1.0,x=(route==4 ? -3.0:3.0)+j
            return EnemyArrival(kind:.passage,points:[point(x,side*11.2),point(x,side*7.8),point(x,side*4.4)])
        }
        let small=kind == .cave,trail=kind == .forest || kind == .jungle
        if route==0 || route==2 {
            let side=route==0 ? -1.0:1.0,finish=small ? 4.6:6.3,start=small ? 9.8:trail ? 12.3:11.2
            return EnemyArrival(kind:trail ? .trail:.passage,points:[point(j,side*start),point(j,side*(small ? 6.6:8.4)),point(j,side*finish)])
        }
        let side=route==3 ? -1.0:1.0,finish=small ? 7.5:9.6,start=small ? 13.0:16.0
        // The street's western crate remains solid; this doorway joins the lane below it.
        let y=entryCrossOffset(side:side<0 ? .west:.east)+j
        let height=kind == .street && side>0 ? StreetLayout.deck:kind == .urban && side<0 ? UrbanLayout.deck:0
        return EnemyArrival(kind:trail ? .trail:.passage,points:[point(side*start,y,height),point(side*(small ? 9.8:12.2),y,height),point(side*finish,y,height)])

    }
}

extension GameCore {
    func arrivingFoe(kind:FoeKind,hp:Double,speed:Double,entrance:Int,lane:Double)->Foe {
        if kind == .engineer {
            // Downpour remains a falling entrance, with time to react and a visible landing marker.
            var p=layout.clamped(V2(x:random()*20-10,y:random()*12-6))
            for _ in 0..<5 where (p-hero).length<3.0 {p=layout.clamped(V2(x:random()*20-10,y:random()*12-6))}
            if (p-hero).length<3.0 {
                p=[V2(x:-8,y:-4),V2(x:8,y:-4),V2(x:-8,y:4),V2(x:8,y:4)].map{layout.clamped($0)}.max(by:{($0-hero).length<($1-hero).length})!
            }
            return Foe(id:id(),p:p,hp:hp,speed:speed,gait:random()*10,elevation:layout.height(p)+8,kind:kind,behaviorClock:random()*2.6,lungeDirection:(hero-p).unit)
        }
        let entry=layout.entranceForBody(index:entrance,height:kind == .sasquatch || kind == .martyr ? 1.95:1.3)
        let arrival=layout.enemyArrival(index:entry,lane:lane)
        return Foe(id:id(),p:arrival.start.p,hp:hp,speed:speed,gait:random()*10,elevation:arrival.start.height,kind:kind,behaviorClock:random()*2.6,lungeDirection:(hero-arrival.start.p).unit,arrival:arrival,homeEntrance:entry)
    }
    @discardableResult func advanceFoeArrival(_ index:Int,_ dt:Double)->Bool {
        guard var arrival=foes[index].arrival else{return false}
        var f=foes[index]
        let surfaceSpeed=f.kind == .hound ? 6.5:f.kind == .crawler ? 2.6:max(2.1,f.speed)
        let speed=arrival.kind == .water && f.elevation < -0.05 ? surfaceSpeed*0.55:surfaceSpeed
        let finished=arrival.advance(position:&f.p,height:&f.elevation,distance:speed*max(0,dt))
        f.gait+=speed*max(0,dt)*3;f.fallSpeed=0;f.arrival=finished ? nil:arrival
        foes[index]=f
        return true
    }
}
