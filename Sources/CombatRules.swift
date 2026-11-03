import Foundation

/// Timings/AI ceilings read from the archived BO1 scripts, not authenticated engine behavior.
/// Timed admission consumes failures;world scale and engine-specific limits remain interpretations.
enum CombatRules {
    static let boostDuration=0.6
    static let boostSpeed=20.0 // Provisional 100 source units per own world unit.
    static func enemyLimit(round:Int)->Int {
        switch round {
        case 9,13,17,22:return 20
        case 30:return 28
        case 34:return 10
        default:return 32
        }
    }
}
extension GameCore {
    func cancelBoost(){dashTime=0;playerRoster.current.boostStepDuration=0;playerRoster.current.boostDirection = .zero}
    var boostProtected:Bool {dashTime>0 || playerRoster.current.boostStepDuration>0}
    var activeAIEnemies:Int {foes.reduce(0){$0+($1.hp>0 ? 1:0)}+silverbacks.reduce(0){$0+($1.hp>0 ? 1:0)}}
    var enemySpawnCapacity:Int {max(0,CombatRules.enemyLimit(round:round)-activeAIEnemies)}
    func moveBoost(_ dt:Double) {
        let player=playerRoster.current,travelTime=min(max(0,dt),dashTime)
        player.boostStepDuration=travelTime
        let count=max(1,Int(ceil(travelTime*CombatRules.boostSpeed/0.14)))
        let delta=player.boostDirection*(travelTime*CombatRules.boostSpeed/Double(count))
        // Follow the actual obstacle-constrained path; a straight endpoint sweep could cut a corner.
        for _ in 0..<count {
            let old=hero,oldHeight=heroElevation
            hero=layout.moved(hero,by:delta);updateHeroElevation(travelTime/Double(count))
            resolveBoostContacts(from:old,to:hero,oldHeight:oldHeight,endHeight:heroElevation)
            resolveBodyShieldContacts(from:old,oldHeight:oldHeight)
        }
        dashTime=max(0,dashTime-travelTime)
        if dashTime<1e-9 {dashTime=0}
    }
}
