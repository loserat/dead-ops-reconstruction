import Foundation

enum StreetLayout {
    static let deck=1.4,edgeX=8.0,landingY=2.0,footY=5.0
    static func height(_ p:V2)->Double {
        guard p.x>=edgeX else{return 0}
        if abs(p.y)<=landingY {return deck}
        if abs(p.y)<=footY {return deck*(footY-abs(p.y))/(footY-landingY)}
        return 0
    }
    static func allows(_ a:V2,_ b:V2)->Bool {
        if (a.x<edgeX) != (b.x<edgeX) {
            let t=(edgeX-a.x)/(b.x-a.x),y=a.y+(b.y-a.y)*t
            if abs(y)<footY-0.00001 {return false}
        }
        return abs(height(a)-height(b))<=0.9*(b-a).length+0.025
    }
    static let traps=[V2(x:-6,y:-3.4),V2(x:-6,y:3.4),V2(x:3.5,y:-3.4),V2(x:3.5,y:3.4)]
    static let obstacles=[ArenaObstacle(V2(x:-10,y:0),half:V2(x:0.6,y:0.9),height:0.8)]
}
struct FlamingBarrel {
    let id:Int
    var p:V2,v:V2
    var elevation=5.0,verticalSpeed=0.0,ttl=7.0,spin=0.0,bounces=0
}
extension GameCore {
    func spawnBarrel() {
        let side=random()<0.5 ? -1.0:1.0
        let p=V2(x:side*11.0,y:random()*11-5.5)
        barrels.append(FlamingBarrel(id:id(),p:p,v:V2(x:-side*(2.6+random()*1.2),y:random()-0.5),elevation:layout.height(p)+5,ttl:6+random()*2))
    }
    func stepBarrels(_ dt:Double) {
        guard layout.kind == .street,phase == .playing else{return}
        barrelClock-=dt
        if barrelClock<=0 && (spawnRemaining>0 || foes.contains{$0.hp>0}) {spawnBarrel();barrelClock=round==25 ? 2.5:3.3}
        for i in barrels.indices {
            let old=barrels[i].p,proposed=old+barrels[i].v*dt
            var q=barrels[i].elevation>layout.height(proposed)+1.5 ? layout.boundary(proposed,clearance:0.40):layout.clamped(proposed,clearance:0.40)
            if (q-proposed).length>0.01 {let normal=(q-proposed).unit,dot=barrels[i].v.x*normal.x+barrels[i].v.y*normal.y;barrels[i].v=barrels[i].v-normal*(2*dot)}
            if layout.height(q)>barrels[i].elevation+0.15 {
                let normal=V2(x:layout.height(q+V2(x:0.15,y:0))-layout.height(q-V2(x:0.15,y:0)),y:layout.height(q+V2(x:0,y:0.15))-layout.height(q-V2(x:0,y:0.15))).unit
                let dot=barrels[i].v.x*normal.x+barrels[i].v.y*normal.y
                barrels[i].v=normal.length>0 ? barrels[i].v-normal*(2*dot):barrels[i].v*(-1);q=old
            }
            barrels[i].p=q;barrels[i].ttl-=dt;barrels[i].spin+=barrels[i].v.length*dt/0.35
            barrels[i].verticalSpeed-=14*dt;barrels[i].elevation+=barrels[i].verticalSpeed*dt
            let floor=layout.height(q)
            if barrels[i].elevation<=floor {
                barrels[i].elevation=floor
                if barrels[i].verticalSpeed < -1.5 && barrels[i].bounces<3 {barrels[i].verticalSpeed *= -0.52;barrels[i].bounces+=1}
                else {barrels[i].verticalSpeed=0;barrels[i].v=barrels[i].v*exp(-0.65*dt)}
            }
        }
        detonateBarrels(Set(barrels.filter{$0.ttl<=0}.map(\.id)))
    }
    func detonateBarrels(_ initial:Set<Int>,canDamageHero:Bool=true) {
        var pending=initial,visited=Set<Int>()
        while let id=pending.first {
            pending.remove(id)
            guard !visited.contains(id),let index=barrels.firstIndex(where:{$0.id==id}) else{continue}
            emitAudio(.explosion);visited.insert(id);let barrel=barrels.remove(at:index),height=barrel.elevation+0.35
            for other in barrels where hypot((other.p-barrel.p).length,other.elevation-barrel.elevation)<2.5 {pending.insert(other.id)}
            effects.append(Effect(id:self.id(),p:barrel.p,ttl:0.6,size:3.6,color:2,height:height))
            if canDamageHero {forEachLivingPlayer{
                let distance=hypot((hero-barrel.p).length,heroElevation+0.5-height)
                if distance<BlastSource.barrel.profile.outer && layout.lineClear(barrel.p,hero,clearance:0.02) {queueBlast(.barrel,distance:distance)}
            }}
            for j in foes.indices where foes[j].hp>0 && hypot((foes[j].p-barrel.p).length,foes[j].elevation+0.5-height)<2.5 {foes[j].hp=0;foes[j].creditSlot=activePlayerSlot}
        }
    }
    func resolveBarrelDamage() {resolveDeferredBlasts()}
    func explodeBarrels(at p:V2,height:Double,radius:Double) {
        detonateBarrels(Set(barrels.filter{hypot(($0.p-p).length,$0.elevation+0.35-height)<radius+0.35}.map(\.id)))
    }
    func barrelHit(from start:V2,to end:V2,height:Double)->(id:Int,p:V2)? {
        let segments=max(1,Int(ceil((end-start).length/0.12)))
        for i in 0...segments {
            let p=start+(end-start)*(Double(i)/Double(segments))
            if let barrel=barrels.first(where:{hypot(($0.p-p).length,$0.elevation+0.35-height)<0.45}) {return (barrel.id,p)}
        }
        return nil
    }
}
