import Foundation

/// DOA1 inventory and reported fire cadence from the reference; scene units/damage are normalized.
/// Grenade/flame ranges, direct damage and ricochet limits remain own tunable approximations.
struct WeaponProfile {
    let title:String,interval:Double,speed:Double,damage:Double
    let spread:[Double]
    static func forPickup(_ kind:PickupKind?)->WeaponProfile {
        switch kind {
        case .deathMachine:return WeaponProfile(title:"DEATH MACHINE",interval:0.016,speed:38,damage:5,spread:[0])
        case .rocket:return WeaponProfile(title:"RPG",interval:0.20,speed:17,damage:8,spread:[0])
        case .ray:return WeaponProfile(title:"RAY GUN",interval:0.13,speed:24,damage:10,spread:[0])
        case .spread:return WeaponProfile(title:"SPAS-12",interval:0.092,speed:32,damage:2,spread:[-0.26,-0.13,0,0.13,0.26])
        case .grenade:return WeaponProfile(title:"CHINA LAKE",interval:0.40,speed:11,damage:16,spread:[0])
        case .flamethrower:return WeaponProfile(title:"M2 FLAMMENWERFER",interval:0.05,speed:0,damage:0.30,spread:[0])
        default:return WeaponProfile(title:"M60",interval:0.022,speed:36,damage:1,spread:[0])
        }
    }
    static let pickups:[PickupKind]=[.deathMachine,.rocket,.ray,.spread,.grenade,.flamethrower]
}
struct FlameJet {
    let id:Int,p:V2,direction:V2,height:Double,length:Double
    var ttl=0.12,ownerSlot=0
}

extension GameCore {
    func fire(from p:V2,direction:V2,height:Double?=nil) {
        fireUsing(activeWeapon,from:p,direction:direction,height:height)
    }
    func fireUsing(_ gun:PickupKind?,from p:V2,direction:V2,height:Double?=nil,descendingTo:Double?=nil) {
        emitAudio(AudioCue.weapon(gun))
        let spec=WeaponProfile.forPickup(gun),h=height ?? heroElevation+0.53
        if gun == .flamethrower {fireFlame(from:p,direction:direction,height:h,damage:spec.damage);return}
        let a=atan2(direction.y,direction.x)
        for off in spec.spread {
            let v=V2(x:cos(a+off),y:sin(a+off))
            shots.append(Shot(id:id(),p:p+v*0.5,v:v*spec.speed,ttl:1.2,damage:spec.damage,kind:gun,height:h,verticalSpeed:gun == .grenade ? 4.7:descendingTo != nil ? -36:0,targetHeight:descendingTo,ownerSlot:activePlayerSlot))
        }
    }
    func projectileClear(from a:V2,to b:V2,height:Double)->Bool {
        let steps=max(1,Int(ceil((b-a).length/0.10)))
        for i in 0...steps {
            let p=a+(b-a)*(Double(i)/Double(steps))
            if layout.height(p)>height+0.05 {return false}
            if layout.obstacles.contains(where:{$0.contains(p,clearance:0.02) && height >= $0.elevation && height <= $0.elevation+$0.height}) {return false}
        }
        return true
    }
    func fireFlame(from p:V2,direction:V2,height:Double,damage:Double) {
        let dir=direction.unit
        var reach=4.4
        for step in 1...29 {let d=Double(step)*0.15;if !projectileClear(from:p,to:p+dir*d,height:height) {reach=max(0.1,d-0.15);break}}
        flameJets.append(FlameJet(id:id(),p:p,direction:dir,height:height,length:reach,ownerSlot:activePlayerSlot))
        if flameJets.count>36 {flameJets.removeFirst(flameJets.count-36)}
        for i in foes.indices where foes[i].hp>0 {
            let d=foes[i].p-p,along=d.x*dir.x+d.y*dir.y
            let side=abs(d.x*dir.y-d.y*dir.x)
            guard along>0,along<4.4,side<0.20+along*0.34,height >= foes[i].elevation-0.2,height<=foes[i].elevation+foes[i].hitHeight,
                  projectileClear(from:p,to:foes[i].p,height:height) else{continue}
            foes[i].hp-=damage;if damage>0 {foes[i].creditSlot=activePlayerSlot};igniteFlameTarget(i)
            if foes[i].kind == .engineer {foes[i].enraged=true}
        }
        for boss in silverbacks where boss.hp>0 {
            let d=boss.p-p,along=d.x*dir.x+d.y*dir.y
            if along>0,along<4.8,abs(d.x*dir.y-d.y*dir.x)<0.65+along*0.34,projectileClear(from:p,to:boss.p,height:height) {damageSilverback(damage*2,id:boss.id)}
        }
        if let raider=treasureRaider {
            let d=raider.p-p,along=d.x*dir.x+d.y*dir.y
            if along>0,along<4.8,abs(d.x*dir.y-d.y*dir.x)<0.65+along*0.34,height>=raider.elevation+0.1,height<=raider.elevation+3.1,projectileClear(from:p,to:raider.p,height:height) {registerRaiderHit(damage)}
        }
        // Fire can ignite the street hazards; actual blast/player damage remains deferred.
        let hit=Set(barrels.filter{b in
            let d=b.p-p,along=d.x*dir.x+d.y*dir.y
            return along>0 && along<4.4 && abs(d.x*dir.y-d.y*dir.x)<0.25+along*0.34 && abs(b.elevation+0.35-height)<0.9 && projectileClear(from:p,to:b.p,height:height)
        }.map(\.id))
        detonateBarrels(hit)
    }
    func stepBurning(_ dt:Double,at clock:Double?=nil) {
        flameJets=flameJets.compactMap{var f=$0;f.ttl-=dt;return f.ttl>0 ? f:nil}
        for i in foes.indices where foes[i].burning>0 && foes[i].hp>0 {
            if var burn=foes[i].flameAfterburn {
                let ticks=burn.advance(dt,at:clock)
                foes[i].flameAfterburn=burn;foes[i].burning=burn.remaining
                // The script captures the first attacker; later gas contacts do not steal that thread.
                if ticks>0,let owner=foes[i].burningOwner,players.indices.contains(owner) {
                    foes[i].hp-=Double(ticks)*burn.tickDamage;foes[i].creditSlot=owner
                }
                continue
            }
            let time=min(max(0,dt),foes[i].burning)
            foes[i].hp-=time*5;if time>0,let owner=foes[i].burningOwner {foes[i].creditSlot=owner};foes[i].burning=max(0,foes[i].burning-time)
        }
    }
    func weaponExplosion(at p:V2,height:Double,radius:Double,damage:Double,scoreFactor:Int=1) {
        emitAudio(.explosion)
        effects.append(Effect(id:id(),p:p,ttl:0.48,size:radius*1.5,color:6,height:height))
        for i in foes.indices where foes[i].hp>0 && hypot((foes[i].p-p).length,foes[i].elevation+0.5-height)<radius {
            if projectileClear(from:p,to:foes[i].p,height:max(height,foes[i].elevation+0.5)) {foes[i].hp-=damage;if damage>0 {foes[i].creditSlot=activePlayerSlot};if foes[i].hp<=0 {foes[i].scoreFactor=max(foes[i].scoreFactor,scoreFactor)}}
        }
        for boss in silverbacks where boss.hp>0 && hypot((boss.p-p).length,1-height)<radius+0.7 && projectileClear(from:p,to:boss.p,height:max(0.7,height)) {damageSilverback(damage*2,id:boss.id)}
        if let raider=treasureRaider,hypot((raider.p-p).length,raider.elevation+1-height)<radius+0.7,projectileClear(from:p,to:raider.p,height:max(0.7,height)) {registerRaiderHit(damage)}
        explodeBulls(at:p,radius:radius)
        explodeBarrels(at:p,height:height,radius:radius)
    }
}
