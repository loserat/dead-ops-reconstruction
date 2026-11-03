import Foundation

struct MonkeyDecoy {
    let id:Int
    var p:V2,elevation:Double,remaining=8.0,stowed=false
    let navigation=ArenaNavigation()
}
enum SentryMotion {case falling,active,leaving}
struct SentryTurret {
    let id:Int
    var p:V2,elevation:Double,heading=V2(x:0,y:-1),remaining=30.0,verticalSpeed=0.0
    var motion:SentryMotion = .falling
    var shotClock=0.0,flash=0.0,departureClock=0.0,shotCount=0
    var stowed=false,served=false
}
struct ShieldBarrel {
    let id:Int
    var angle:Double,p:V2,previousP:V2
}
struct DepartingShieldBarrel {
    let id:Int
    var p:V2,previousP:V2,v:V2,height:Double,ttl=0.8
}

extension GameCore {
    func clearCarriedSupport() {teddyRemaining=0;shieldBarrelRemaining=0;shieldBarrels=[];departingShieldBarrels=[]}
    func clearArenaSupport() {
        clearTeslaTargets()
        treasureRaider=nil
        forEachPlayer {
            monkeys.removeAll{!$0.stowed};sentries.removeAll{!$0.stowed}
            departingShieldBarrels=[];flyingOrbs=[]
        }
    }
    func grantBarrelShield() {
        shieldBarrelRemaining=20*pickupDurationFactor
        if shieldBarrels.isEmpty {
            for i in 0..<2 {
                let a=Double(i)*Double.pi,p=hero+V2(x:cos(a),y:sin(a))*1.18
                shieldBarrels.append(ShieldBarrel(id:id(),angle:a,p:p,previousP:p))
            }
        }
    }
    func addMonkey(at p:V2) {
        if monkeys.count>=6 {monkeys.removeFirst()}
        let q=layout.clamped(p,clearance:0.38)
        monkeys.append(MonkeyDecoy(id:id(),p:q,elevation:layout.height(q),stowed:phase == .bonusRoom))
    }
    func addSentry(at p:V2) {
        if sentries.count>=6 {sentries.removeFirst()}
        let q=layout.clamped(p,clearance:0.50)
        sentries.append(SentryTurret(id:id(),p:q,elevation:layout.height(q)+8,stowed:phase == .bonusRoom))
        if phase != .bonusRoom {emitAudio(.sentryArrival)}
    }
    func deployStowedSupport() {
        for i in monkeys.indices where monkeys[i].stowed {
            let q=layout.clamped(hero+V2(x:Double(i%3)-1,y:1.1+Double(i/3)),clearance:0.38)
            monkeys[i].p=q;monkeys[i].elevation=layout.height(q);monkeys[i].stowed=false
        }
        for i in sentries.indices where sentries[i].stowed {
            let q=layout.clamped(hero+V2(x:Double(i%3)*1.1-1.1,y:1.8+Double(i/3)),clearance:0.50)
            sentries[i].p=q;sentries[i].elevation=layout.height(q)+8;sentries[i].stowed=false
            emitAudio(.sentryArrival)
        }
    }
    func repositionShieldBarrels() {
        for i in shieldBarrels.indices {
            let a=shieldBarrels[i].angle,p=hero+V2(x:cos(a),y:sin(a))*1.18
            shieldBarrels[i].p=p;shieldBarrels[i].previousP=p
        }
        departingShieldBarrels=[]
    }
    func stepSupportPowers(_ dt:Double,advanceTimers:Bool=true) {
        if advanceTimers {teddyRemaining=max(0,teddyRemaining-dt);shieldBarrelRemaining=max(0,shieldBarrelRemaining-dt)}
        if shieldBarrelRemaining<=0 && !shieldBarrels.isEmpty {
            for b in shieldBarrels {
                departingShieldBarrels.append(DepartingShieldBarrel(id:b.id,p:b.p,previousP:b.p,v:(b.p-hero).unit*8,height:heroElevation+0.42))
            }
            shieldBarrels=[]
        }
        for i in shieldBarrels.indices {
            shieldBarrels[i].previousP=shieldBarrels[i].p;shieldBarrels[i].angle+=dt*4
            let a=shieldBarrels[i].angle;shieldBarrels[i].p=hero+V2(x:cos(a),y:sin(a))*1.18
        }
        for i in departingShieldBarrels.indices {
            let old=departingShieldBarrels[i].p,new=old+departingShieldBarrels[i].v*dt
            departingShieldBarrels[i].previousP=old;departingShieldBarrels[i].p=new;departingShieldBarrels[i].ttl-=dt
            if !projectileClear(from:old,to:new,height:departingShieldBarrels[i].height) {departingShieldBarrels[i].ttl=0}
        }
        departingShieldBarrels.removeAll{$0.ttl<=0}
        guard advanceTimers else{return}
        for i in monkeys.indices where !monkeys[i].stowed {monkeys[i].remaining-=dt}
        let exploded=monkeys.filter{!$0.stowed && $0.remaining<=0}
        monkeys.removeAll{!$0.stowed && $0.remaining<=0}
        for m in exploded {weaponExplosion(at:m.p,height:m.elevation+0.45,radius:3.8,damage:50,scoreFactor:2)}
        stepSentries(dt)
    }
    func updateSupportNavigation(_ dt:Double) {
        for m in monkeys where !m.stowed {m.navigation.update(layout:layout,target:m.p,dt:dt)}
        if teddyRemaining>0 {
            for i in 0..<layout.enemyEntranceCount {
                let target=layout.clamped(layout.enemyArrival(index:i).end.p,clearance:0.32)
                teddyNavigation[i].update(layout:layout,target:target,dt:dt)
            }
        }
    }
    func teddyFreezes(_ foe:Foe)->Bool {teddyRemaining>0 && foe.kind != .zombie && foe.kind != .villager}
    func supportPursuit(_ index:Int)->(target:V2,direction:V2,waiting:Bool) {
        let f=foes[index]
        if teddyRemaining>0 {
            if f.retreatEntrance==nil && (f.p-hero).length<3.8 {
                foes[index].retreatEntrance=f.homeEntrance ?? (0..<layout.enemyEntranceCount).min(by:{(layout.enemyArrival(index:$0).end.p-f.p).length<(layout.enemyArrival(index:$1).end.p-f.p).length})
            }
            if let entrance=foes[index].retreatEntrance {
                let route=entrance%layout.enemyEntranceCount,target=layout.clamped(layout.enemyArrival(index:route).end.p,clearance:0.32)
                return (target,teddyNavigation[route].direction(from:f.p,to:target,layout:layout),(f.p-target).length<0.38)
            }
        }else{foes[index].retreatEntrance=nil}
        let playerDistance=hypot((hero-f.p).length,heroElevation-f.elevation)
        if let m=monkeys.filter({!$0.stowed && hypot(($0.p-f.p).length,$0.elevation-f.elevation)<playerDistance}).min(by:{hypot(($0.p-f.p).length,$0.elevation-f.elevation)<hypot(($1.p-f.p).length,$1.elevation-f.elevation)}) {
            return (m.p,m.navigation.direction(from:f.p,to:m.p,layout:layout),(m.p-f.p).length<0.40)
        }
        return (hero,navigation.direction(from:f.p,to:hero,layout:layout),false)
    }
    func fireSentry(_ turret:inout SentryTurret,_ dt:Double,at target:V2?) {
        guard let target=target else{turret.shotClock=0;return}
        let aim=(target-turret.p).unit;turret.heading=aim;turret.shotClock-=dt
        var count=0
        while turret.shotClock<=0 && count<128 {
            // Deterministic dispersion avoids consuming the world/drop random stream.
            let angle=atan2(aim.y,aim.x)+sin(Double(turret.shotCount)*2.399+Double(turret.id)) * 0.095
            let dir=V2(x:cos(angle),y:sin(angle))
            shots.append(Shot(id:id(),p:turret.p+dir*0.55,v:dir*36,ttl:1.1,damage:3,kind:nil,height:turret.elevation+0.72,ownerSlot:activePlayerSlot))
            emitAudio(.turretShot);turret.flash=0.045;turret.shotCount+=1;turret.shotClock+=0.015;count+=1
        }
    }
    func stepSentries(_ dt:Double) {
        for i in sentries.indices where !sentries[i].stowed {
            var t=sentries[i];let oldMotion=t.motion;t.flash=max(0,t.flash-dt)
            if phase == .cleared && t.served {t.motion = .leaving}
            if phase == .playing {t.served=true}
            t.remaining=max(0,t.remaining-dt)
            if t.remaining<=0 {t.motion = .leaving}
            if t.motion == .leaving && oldMotion != .leaving {emitAudio(.sentryDepart)}
            switch t.motion {
            case .falling:
                t.verticalSpeed-=18*dt;t.elevation+=t.verticalSpeed*dt
                if t.elevation<=layout.height(t.p) {
                    t.elevation=layout.height(t.p);t.verticalSpeed=0;t.motion = .active
                    emitAudio(.sentryLand)
                    effects.append(Effect(id:id(),p:t.p,ttl:0.3,size:1.1,color:7,height:t.elevation+0.1))
                    for j in foes.indices where foes[j].hp>0 && (foes[j].p-t.p).length<0.95 && abs(foes[j].elevation-t.elevation)<0.9 {foes[j].hp=0;foes[j].creditSlot=activePlayerSlot}
                }
            case .active:
                if phase == .playing {
                    let height=t.elevation+0.72
                    let f=foes.filter{$0.hp>0 && height>=$0.elevation+0.1 && height<=$0.elevation+$0.hitHeight && ($0.p-t.p).length<12 && projectileClear(from:t.p,to:$0.p,height:height)}.min(by:{($0.p-t.p).length<($1.p-t.p).length})
                    let boss=silverbacks.filter{$0.hp>0 && height<3.1 && ($0.p-t.p).length<12 && projectileClear(from:t.p,to:$0.p,height:height)}.min(by:{($0.p-t.p).length<($1.p-t.p).length})?.p
                    fireSentry(&t,dt,at:f?.p ?? boss)
                }else{t.shotClock=0}
            case .leaving:
                t.elevation+=6*dt;t.departureClock+=dt;t.flash=0;t.shotClock=0
            }
            sentries[i]=t
        }
        sentries.removeAll{$0.departureClock>=1.4}
    }
    func resolveShieldBarrelHits(_ dt:Double) {
        guard phase == .playing else{return}
        func hit(_ a:V2,_ b:V2,_ height:Double) {
            for i in foes.indices where foes[i].hp>0 && abs(foes[i].elevation+0.42-height)<0.8 && foes[i].p.distance(toSegmentFrom:a,to:b)<0.56+foes[i].hitRadius*0.3 {
                if projectileClear(from:b,to:foes[i].p,height:height) {foes[i].hp=0;foes[i].creditSlot=activePlayerSlot}
            }
            for boss in silverbacks where boss.hp>0 && height<2.9 && boss.p.distance(toSegmentFrom:a,to:b)<1.35 && projectileClear(from:b,to:boss.p,height:height) {damageSilverback(18*dt,id:boss.id)}
        }
        for b in shieldBarrels {hit(b.previousP,b.p,heroElevation+0.42)}
        for b in departingShieldBarrels {hit(b.previousP,b.p,b.height)}
    }
}
