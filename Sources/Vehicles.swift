import Foundation

enum VehicleKind:Int,CaseIterable {
    case tank,helicopter
    var title:String {self == .tank ? "PANZER":"HIND"}
    var firstRound:Int {self == .tank ? 4:9}
    var pickup:PickupKind {self == .tank ? .tank:.helicopter}
}
struct VehicleState {
    let kind:VehicleKind
    var remaining:Double,heading:V2
    var velocity=V2.zero,travel=0.0,cannonClock=0.0,missileClock=0.0,flash=0.0,missileFlash=0.0
    var missiles=0
    var landingTarget:V2?
}

extension GameCore {
    /// Source end_of_round_cleanup notifies every active Hind in the prison arena.
    /// Use the ordinary safe dismount; do not wait for another round or an exit choice.
    func cleanupSourceRoundVehicles() {
        guard sideRoom==nil,layout.kind == .prison else{return}
        forEachPlayer {if vehicle?.kind == .helicopter {endVehicle()}}
    }
    var flying:Bool {vehicle?.kind == .helicopter}
    var cameraFloorElevation:Double {flying ? layout.height(hero):heroElevation}
    var chickenWeapon:PickupKind? {vehicle.map{$0.kind == .tank ? .grenade:.ray} ?? activeWeapon}
    func flightPosition(_ p:V2,by delta:V2)->V2 {
        var q=p
        let steps=max(1,Int(ceil(delta.length/0.14)))
        for _ in 0..<steps {
            q=layout.boundary(q+delta*(1/Double(steps)),clearance:0.45)
            for o in layout.obstacles where o.elevation+o.height>max(3.1,layout.height(q)+1.2)-0.25 {q=o.pushed(q,clearance:0.65)}
            q=layout.boundary(q,clearance:0.45)
        }
        return q
    }
    func safeLandingPoint()->V2 {
        if layout.walkable(hero,clearance:0.36) {return hero}
        let clamped=layout.clamped(hero,clearance:0.45)
        if layout.walkable(clamped,clearance:0.36) {return clamped}
        for r in [0.5,1.0,1.5,2.0,3.0,4.0,6.0] {
            let points=(0..<32).map{i in hero+V2(x:cos(Double(i)*Double.pi/16),y:sin(Double(i)*Double.pi/16))*r}
            if let p=points.first(where:{layout.walkable($0,clearance:0.36)}) {return p}
        }
        return layout.clamped(layout.spawn,clearance:0.45)
    }
    func beginVehicle(_ kind:VehicleKind) {
        cancelBoost();shotClock=0;flameJets.removeAll{$0.ownerSlot==activePlayerSlot}
        if kind == .tank {hero=layout.clamped(hero,clearance:0.65);heroElevation=layout.height(hero)}
        else {hero=flightPosition(hero,by:.zero);heroElevation=max(3.1,layout.height(hero)+1.2)}
        vehicle=VehicleState(kind:kind,remaining:20*pickupDurationFactor,heading:facing)
        heroFallSpeed=0
        for i in chickens.indices {chickens[i].shotClock=0}
        repositionCompanions();announce("\(kind.title) · \(Int(20*pickupDurationFactor)) SEKUNDEN")
    }
    func repositionVehicleAfterTeleport() {
        guard var v=vehicle else{return}
        v.velocity = .zero
        if v.kind == .tank {hero=layout.clamped(hero,clearance:0.65);heroElevation=layout.height(hero)}
        else {hero=flightPosition(hero,by:.zero);heroElevation=max(3.1,layout.height(hero)+1.2)}
        if v.landingTarget != nil {v.landingTarget=safeLandingPoint()}
        vehicle=v
    }
    func endVehicle(shieldStartsAfter:Double=0) {
        guard vehicle != nil else{return}
        vehicle=nil;shotClock=0;cancelBoost()
        hero=safeLandingPoint();heroElevation=layout.height(hero);heroFallSpeed=0
        beginBodyShield(short:true,startsAfter:shieldStartsAfter)
        applyVehicleExitPulse(startsAfter:shieldStartsAfter)
        emitAudio(.respawn)
        for i in chickens.indices {chickens[i].shotClock=0}
        repositionCompanions();announce("WIEDER ZU FUSS")
    }
    func stepVehicleClock(_ dt:Double) {
        guard var v=vehicle else{return}
        v.flash=max(0,v.flash-dt);v.missileFlash=max(0,v.missileFlash-dt)
        if v.landingTarget==nil {
            let before=v.remaining
            v.remaining=max(0,v.remaining-max(0,dt))
            if v.remaining<=0 {
                if v.kind == .helicopter {v.landingTarget=safeLandingPoint();v.velocity = .zero;cancelBoost()}
                else {vehicle=v;endVehicle(shieldStartsAfter:max(0,min(max(0,dt),before)));return}
            }
        }
        vehicle=v
    }
    func moveVehicle(_ dt:Double,move:V2) {
        guard var v=vehicle else{return}
        let old=hero
        if let target=v.landingTarget {
            let d=target-hero
            if d.length>0.025 {hero=hero+d.unit*min(d.length,max(0,dt)*4)}
            else {
                hero=target;heroElevation=max(layout.height(target),heroElevation-max(0,dt)*4)
                if heroElevation<=layout.height(target)+0.02 {vehicle=v;endVehicle();return}
            }
            v.travel+=(hero-old).length;vehicle=v;return
        }
        let amount=min(1,move.length)
        if v.kind == .tank {
            if amount>0.10 {
                let a=atan2(v.heading.y,v.heading.x),wanted=atan2(move.y,move.x)
                let delta=atan2(sin(wanted-a),cos(wanted-a)),turn=max(-2.8*dt,min(2.8*dt,delta))
                v.heading=V2(x:cos(a+turn),y:sin(a+turn))
            }
            let alignment=max(0,v.heading.x*move.unit.x+v.heading.y*move.unit.y)
            let target=v.heading*(4.8*amount*alignment)
            v.velocity=v.velocity+(target-v.velocity)*(1-exp(-7*max(0,dt)))
            let delta=v.velocity*dt
            hero=layout.moved(hero,by:delta,clearance:0.65)
        }else {
            v.heading=facing
            let target=move.unit*(6.8*amount)
            v.velocity=v.velocity+(target-v.velocity)*(1-exp(-6*max(0,dt)))
            let delta=v.velocity*dt
            hero=flightPosition(hero,by:delta)
            heroElevation=max(3.1,layout.height(hero)+1.2);heroFallSpeed=0
        }
        v.travel+=(hero-old).length;vehicle=v
    }
    func crushWithTank(from old:V2,_ dt:Double) {
        guard vehicle?.kind == .tank else{return}
        for i in foes.indices where foes[i].hp>0 && abs(foes[i].elevation-heroElevation)<0.8 {
            if foes[i].p.distance(toSegmentFrom:old,to:hero)<0.86+foes[i].contactRadius*0.25 {foes[i].hp=0;foes[i].creditSlot=activePlayerSlot}
        }
        for boss in silverbacks where boss.hp>0 && boss.p.distance(toSegmentFrom:old,to:hero)<1.4 {damageSilverback(35*max(0,dt),id:boss.id)}
    }
    func fireVehicleWeapons(_ dt:Double,firing:Bool) {
        guard var v=vehicle else{return}
        guard firing,v.landingTarget==nil else {v.cannonClock=0;v.missileClock=0;vehicle=v;return}
        v.cannonClock-=dt;v.missileClock-=dt
        let dir=facing.unit,right=V2(x:-dir.y,y:dir.x)
        var count=0
        while v.cannonClock<=0 && count<64 {
            emitAudio(v.kind == .tank ? .tankShot:.helicopterShot);v.flash=0.055
            if v.kind == .tank {
                shots.append(Shot(id:id(),p:hero+dir*0.85,v:dir*22,ttl:1.2,damage:16,kind:.rocket,height:heroElevation+0.65,piercing:false,explosionDamage:16,ownerSlot:activePlayerSlot))
                v.cannonClock+=0.20
            }else {
                let target=layout.height(hero+dir*2.5)+0.53
                shots.append(Shot(id:id(),p:hero+dir*0.65,v:dir*32,ttl:1.2,damage:2,kind:nil,height:heroElevation+0.05,verticalSpeed:-36,targetHeight:target,ownerSlot:activePlayerSlot))
                v.cannonClock+=0.08
            }
            count+=1
        }
        if v.kind == .helicopter {
            count=0
            while v.missileClock<=0 && count<64 {
                let side=v.missiles%2==0 ? -1.0:1.0,p=hero+dir*0.45+right*(side*0.48)
                shots.append(Shot(id:id(),p:p,v:dir*24,ttl:1.3,damage:10,kind:.rocket,height:heroElevation+0.05,verticalSpeed:-36,piercing:false,explosionDamage:10,targetHeight:layout.height(hero+dir*2.5)+0.53,ownerSlot:activePlayerSlot))
                v.missiles+=1;v.missileFlash=0.07;v.missileClock+=0.20;count+=1
            }
        }
        vehicle=v
    }
}
