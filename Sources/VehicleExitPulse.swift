import Foundation

/// Projects the archived raw health domain onto the existing own combat balance.
/// Exit pulse and archived flame afterburn use this projection; direct weapon damage remains own balance.
struct ReferenceVitality {
    let sourceMaximum:Double,localMaximum:Double,exactScriptBase:Bool
    var damageScale:Double {localMaximum/sourceMaximum}
    static func ordinary(_ round:Int)->Double {1000+150*Double(max(1,round)-1)}
    static func foe(_ kind:FoeKind,round:Int,mini:Bool,localMaximum:Double)->ReferenceVitality {
        let ordinary=ordinary(round)
        let modifier:Double
        switch kind {case .prisoner:modifier=0.4;case .crawler:modifier=0.7;case .villager,.sasquatch:modifier=0.5;case .hound:modifier=0.25;default:modifier=1}
        // The dog prespawn never assigns base health: its native archetype is unavailable.
        // Keep an explicit ordinary-base estimate for that single unverified archetype.
        let raw=mini ? floor((ordinary+10000)*modifier):ordinary
        return ReferenceVitality(sourceMaximum:max(1,raw),localMaximum:max(0,localMaximum),exactScriptBase:kind != .hound)
    }
}
enum VehicleExitPulse {
    static let radius=2.0,rawDamage=10000.0,effectDuration=0.45
}
extension GameCore {
    func exitPulseClear(from a:V2,height:Double,to b:V2,targetHeight:Double)->Bool {
        let length=hypot((b-a).length,targetHeight-height),steps=max(1,Int(ceil(length/0.1)))
        for i in 1...steps {
            let t=Double(i)/Double(steps),p=a+(b-a)*t,h=height+(targetHeight-height)*t
            if layout.height(p)>h+0.05 {return false}
            if layout.obstacles.contains(where:{$0.contains(p,clearance:0.02) && h >= $0.elevation && h <= $0.elevation+$0.height}) {return false}
        }
        return true
    }
    func applyVehicleExitPulse(startsAfter:Double=0) {
        let origin=hero,height=heroElevation+0.08,owner=activePlayerSlot
        let ttl=VehicleExitPulse.effectDuration+max(0,startsAfter)
        if ttl>0 {effects.append(Effect(id:id(),p:origin,ttl:ttl,size:VehicleExitPulse.radius,color:8,height:heroElevation+0.06))}
        func reaches(_ p:V2,_ z:Double)->Bool {
            hypot((p-origin).length,z-height)<VehicleExitPulse.radius && exitPulseClear(from:origin,height:height,to:p,targetHeight:z)
        }
        for i in foes.indices where foes[i].hp>0 {
            let f=foes[i]
            guard reaches(f.p,f.elevation+f.hitHeight*0.5) else{continue}
            if foes[i].referenceVitality==nil {
                // Ad-hoc fixtures have no spawn metadata; capture their full current local domain once.
                foes[i].referenceVitality=ReferenceVitality.foe(f.kind,round:round,mini:false,localMaximum:max(f.hp,RoundRules.health(f.kind,round:round)))
            }
            foes[i].hp-=VehicleExitPulse.rawDamage*foes[i].referenceVitality!.damageScale
            foes[i].creditSlot=owner;foes[i].environmentKill=false
        }
        for boss in silverbacks where boss.hp>0 && reaches(boss.p,boss.entryElevation+1.55) {
            // Source ape health is500000*GetPlayers().size, not a10k instant boss kill.
            damageSilverback(VehicleExitPulse.rawDamage*Silverback.maxHP/(500000*Double(max(1,playerCount))),id:boss.id)
        }
        let hitBarrels=Set(barrels.filter{reaches($0.p,$0.elevation+0.35)}.map(\.id))
        detonateBarrels(hitBarrels)
        // A generic native RadiusDamage is not a projectile/grenade/crush cow hit.
        // Keep fake-AI cattle unaffected; native default-MOD details remain unverified.
    }
}
