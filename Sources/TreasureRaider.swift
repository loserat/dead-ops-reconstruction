import Foundation

/// BO1 intermission Silverback: invincible, competing for ground treasure, dangerous after its roar.
/// Visit cadence, dwell time, speed and scoop radius are own tunable approximations.
enum RaiderMotion {case arriving,roaring,looting,leaving}
struct TreasureRaider {
    let id:Int,entrance:Int
    var p:V2,elevation:Double,facing=V2(x:0,y:1)
    var arrival:EnemyArrival?,departure:EnemyArrival?
    var motion:RaiderMotion = .arriving
    var clock=0.0,totalClock=0.0,gait=0.0,scoopClock=0.0,hitFlash=0.0
    var teslaMarked=false,teslaContacted=false
    var stolen=0
    var hostile:Bool {motion != .arriving}
}
extension GameCore {
    func nextRaidGap()->Int {
        // A separate stream preserves the enemy/drop randomness when a visit is scheduled.
        raidScheduleSeed=raidScheduleSeed &* 6364136223846793005 &+ 1442695040888963407
        return 4+Int((raidScheduleSeed>>32)%3)
    }
    func prepareRaidSchedule() {
        while nextRaidRound<round || (nextRaidRound==round && bossRound) {nextRaidRound+=nextRaidGap()}
    }
    var weaponsEnabled:Bool {phase == .playing || phase == .cleared}
    var raiderTarget:Pickup? {
        guard let raider=treasureRaider else{return nil}
        return pickups.filter{$0.kind == .treasure || $0.kind == .gem}.min{($0.p-raider.p).length<($1.p-raider.p).length}
    }
    func beginTreasureRaid() {
        guard phase == .cleared,sideRoom==nil,!bossRound,!raiderVisited,round>=nextRaidRound else{return}
        raiderVisited=true;nextRaidRound=round+nextRaidGap()
        guard pickups.contains(where:{$0.kind == .treasure || $0.kind == .gem}) else{return}
        let entrance=layout.entranceForBody(index:(round/5)%layout.enemyEntranceCount,height:3.1),arrival=layout.enemyArrival(index:entrance)
        treasureRaider=TreasureRaider(id:id(),entrance:entrance,p:arrival.start.p,elevation:arrival.start.height,arrival:arrival)
        raidsSeen+=1;announce("SILVERBACK-BESUCH · SCHÄTZE EINSAMMELN ODER WEITERZIEHEN")
    }
    func registerRaiderHit(_ damage:Double,id:Int?=nil) {
        guard damage>0,var raider=treasureRaider,id==nil || id==raider.id else{return}
        // No health field: neither sustained fire nor a nuke can convert this visit into a boss kill.
        if raider.hitFlash<=0 {
            effects.append(Effect(id:self.id(),p:raider.p,ttl:0.15,size:0.35,color:0,height:raider.elevation+1.3))
            raider.hitFlash=0.10
        }
        treasureRaider=raider
    }
    func stepTreasureRaider(_ dt:Double) {
        guard phase == .cleared,sideRoom==nil else{return}
        if treasureRaider==nil && clearClock>=0.8 {beginTreasureRaid()}
        guard var raider=treasureRaider else{return}
        let dt=max(0,dt);raider.clock+=dt;raider.totalClock+=dt;raider.hitFlash=max(0,raider.hitFlash-dt)
        switch raider.motion {
        case .arriving:
            if var arrival=raider.arrival {
                let done=arrival.advance(position:&raider.p,height:&raider.elevation,distance:3.6*dt)
                raider.facing=arrival.heading;raider.gait+=dt*10.8;raider.arrival=done ? nil:arrival
                if done {raider.motion = .roaring;raider.clock=0;emitAudio(.boss);announce("SILVERBACK BRÜLLT · ABSTAND HALTEN · UNVERWUNDBAR")}
            }
        case .roaring:
            if raider.clock>=0.85 {raider.motion = .looting;raider.clock=0}
        case .looting:
            let loot=pickups.filter{$0.kind == .treasure || $0.kind == .gem}
            if raider.totalClock>=13 || loot.isEmpty {raider.motion = .leaving;raider.clock=0}
            else if let target=loot.min(by:{($0.p-raider.p).length<($1.p-raider.p).length}) {
                let destination=layout.clamped(target.p,clearance:0.82)
                raiderNavigation.update(layout:layout,target:destination,dt:dt)
                let d=raiderNavigation.direction(from:raider.p,to:destination,layout:layout)
                let before=raider.p;raider.p=layout.moved(raider.p,by:d*(3.6*dt),clearance:0.75)
                raider.elevation=layout.height(raider.p);if d.length>0.01 {raider.facing=d};raider.gait+=(raider.p-before).length*3
                raider.scoopClock=max(0,raider.scoopClock-dt)
                if raider.scoopClock<=0,let index=pickups.firstIndex(where:{($0.kind == .treasure || $0.kind == .gem) && ($0.p-raider.p).length<1.1 && abs(layout.height($0.p)-raider.elevation)<0.65 && layout.lineClear(raider.p,$0.p,clearance:0.02)}) {
                    let loot=pickups.remove(at:index);raider.stolen+=1;treasuresStolen+=1;raider.scoopClock=0.25
                    effects.append(Effect(id:id(),p:loot.p,ttl:0.22,size:0.4,color:2,height:layout.height(loot.p)+0.2))
                }
            }
        case .leaving:
            if var departure=raider.departure {
                let done=departure.advance(position:&raider.p,height:&raider.elevation,distance:4.2*dt)
                raider.facing=departure.heading;raider.gait+=dt*12.6;raider.departure=departure
                if done {treasureRaider=nil;announce("SILVERBACK WEITERGEZOGEN");return}
            }else {
                let route=layout.enemyArrival(index:raider.entrance),target=route.end.p
                raiderNavigation.update(layout:layout,target:target,dt:dt)
                let d=raiderNavigation.direction(from:raider.p,to:target,layout:layout)
                let before=raider.p;raider.p=layout.moved(raider.p,by:d*(4.2*dt),clearance:0.75)
                raider.elevation=layout.height(raider.p);if d.length>0.01 {raider.facing=d};raider.gait+=(raider.p-before).length*3
                // The last short approach is validated at the same body clearance as navigation.
                if (before-target).length<=4.2*dt && layout.lineClear(before,target,clearance:0.71) {
                    raider.p=target;raider.elevation=route.end.height
                    raider.departure=EnemyArrival(kind:route.kind,points:Array(route.points.reversed()))
                }
            }
        }
        treasureRaider=raider
        forEachLivingPlayer {
            if raider.hostile && abs(heroElevation-raider.elevation)<0.9 && (hero-raider.p).length<1.15 {
                loseLife(allowAfterRound:true)
            }
        }
    }
}
