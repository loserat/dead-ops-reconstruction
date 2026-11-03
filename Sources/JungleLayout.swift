import Foundation

enum JungleLayout {
    static let traps=[V2(x:-6.4,y:-3.6),V2(x:6.4,y:-3.6),V2(x:-6.4,y:3.6),V2(x:6.4,y:3.6)]
    static let obstacles=[ArenaObstacle(.zero,radius:1.15,height:5.8)]
}
enum SilverbackMotion {case pursuit,windup,charge,recovery}
struct Silverback {
    static let maxHP=1200.0
    var id=0
    var p=V2(x:0,y:-6),facing=V2(x:0,y:1),chargeDirection=V2(x:0,y:1)
    var hp=Silverback.maxHP,clock=0.0,gait=0.0,deathClock=0.0
    var teslaMarked=false,teslaContacted=false
    var creditSlot:Int?=nil
    var deathAwarded=false,sourceDeathNotified=false
    var arrival:EnemyArrival?=nil,entryElevation=0.0
    var motion:SilverbackMotion = .pursuit
}
extension GameCore {
    func damageSilverback(_ damage:Double,id:Int?=nil) {
        registerRaiderHit(damage,id:id)
        for i in silverbacks.indices where silverbacks[i].hp>0 && (id==nil || silverbacks[i].id==id) {silverbacks[i].hp=max(0,silverbacks[i].hp-damage);if damage>0 {silverbacks[i].creditSlot=activePlayerSlot;notifyTeslaBossDamage(silverbacks[i].id)};if silverbacks[i].hp<=0 {sourceBossDead=true;silverbacks[i].sourceDeathNotified=true}}
    }
    func stepSilverback(_ dt:Double) {
        guard phase == .playing,!silverbacks.isEmpty else{return}
        forEachLivingPlayer{silverbackNavigation.update(layout:layout,target:hero,dt:dt)}
        for i in silverbacks.indices {
          withPlayer(targetSlot(near:silverbacks[i].p)) {
            var boss=silverbacks[i]
            let dt=max(0,dt-(bossFrameBirths[boss.id] ?? 0))
            if boss.hp<=0 {
                if !boss.sourceDeathNotified {sourceBossDead=true;boss.sourceDeathNotified=true}
                if !boss.deathAwarded {boss.deathAwarded=true;withPlayer(boss.creditSlot.flatMap{players.indices.contains($0) ? $0:nil} ?? activePlayerSlot){award(ScoreRules.bossKill*multiplier)};announce("SILVERBACK BESIEGT")}
                boss.deathClock+=dt;silverbacks[i]=boss;return
            }
            if var arrival=boss.arrival {
                let finished=arrival.advance(position:&boss.p,height:&boss.entryElevation,distance:max(0,dt)*2.7)
                boss.facing=arrival.heading;boss.gait+=max(0,dt)*8.1;boss.arrival=finished ? nil:arrival;silverbacks[i]=boss;return
            }
            boss.clock+=dt
            var direction=silverbackNavigation.direction(from:boss.p,to:hero,layout:layout),speed=0.0
            switch boss.motion {
            case .pursuit:speed=2.7;if boss.clock>=3.5 {boss.motion = .windup;boss.clock=0}
            case .windup:if boss.clock>=0.8 {boss.chargeDirection=(hero-boss.p).unit;boss.motion = .charge;boss.clock=0}
            case .charge:direction=boss.chargeDirection;speed=6.2;if boss.clock>=0.75 {boss.motion = .recovery;boss.clock=0;speed=0}
            case .recovery:if boss.clock>=1.1 {boss.motion = .pursuit;boss.clock=0}
            }
            if boss.motion == .pursuit {
                for other in silverbacks where other.id != boss.id && other.hp>0 && other.arrival==nil {
                    let d=boss.p-other.p
                    if d.length>0.01 && d.length<2.2 {direction=direction+d.unit*(2.2-d.length)*0.6}
                }
                direction=direction.unit
            }
            if direction.length>0.01 {boss.facing=direction}
            boss.p=layout.moved(boss.p,by:direction*speed*dt,clearance:0.9);boss.gait+=speed*dt*3
            silverbacks[i]=boss
          }
        }
    }
    func resolveSilverbackContact() {
        guard phase == .playing,heroElevation<2 else{return}
        if silverbacks.contains(where:{$0.hp>0 && ($0.p-hero).length<1.15}) {loseLife()}
    }
    func resolveSilverbackOrbs() {resolveTeslaOrbContacts(bossesOnly:true)}
    func silverbackImpact(from start:V2,to end:V2,height:Double)->(id:Int,p:V2)? {
        let n=max(1,Int(ceil((end-start).length/0.12)))
        for i in 0...n {
            let p=start+(end-start)*(Double(i)/Double(n))
            if height>=0.1,height<=3.1,let boss=silverbacks.first(where:{$0.hp>0 && (p-$0.p).length<1.0}) {return (boss.id,p)}
            if let raider=treasureRaider,height>=raider.elevation+0.1,height<=raider.elevation+3.1,(p-raider.p).length<1.0 {return (raider.id,p)}
        }
        return nil
    }
    func silverbackHit(from start:V2,to end:V2,height:Double)->V2? {silverbackImpact(from:start,to:end,height:height)?.p}
}
