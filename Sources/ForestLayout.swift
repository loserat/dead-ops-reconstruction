import Foundation

enum ForestLayout {
    static let traps=[V2(x:-6.4,y:-3.6),V2(x:6.4,y:-3.6),V2(x:-6.4,y:3.6),V2(x:6.4,y:3.6)]
    static let rocks=[V2(x:-10.6,y:-4.5),V2(x:10.6,y:-4.5),V2(x:-10.6,y:4.5),V2(x:10.6,y:4.5)]
    static let obstacles=[ArenaObstacle(.zero,radius:1,height:3.3)]+rocks.map{ArenaObstacle($0,radius:0.55,height:0.8)}
}
extension GameCore {
    // Original roles stay fixed even when a user chooses a different cosmetic color.
    var houndLethalBites:Int {activePlayerSlot==1 && fate == .friendship ? 4:3}
    var houndRecoveryEnabled:Bool {round>=34 && deaths==0 && trainingHits==0}
    var houndWoundText:String {dogWounds>0 ? "HUND \(dogWounds)/\(houndLethalBites)":""}
    func clearHoundWounds(){dogWounds=0;playerRoster.current.dogRecoveryClock=0}
    func stepHoundRecovery(_ dt:Double) {
        guard dt.isFinite,dt>0,isPlayerActive,phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .transition else{return}
        let player=playerRoster.current
        guard houndRecoveryEnabled,dogWounds>0 else{player.dogRecoveryClock=0;return}
        player.dogRecoveryClock+=dt
        // Firsthand reports establish recovery, not its exact rate. Six seconds per bite is provisional.
        while player.dogRecoveryClock>=HoundRules.recoverySecondsPerBite && dogWounds>0 {
            player.dogRecoveryClock-=HoundRules.recoverySecondsPerBite;dogWounds-=1
        }
        if dogWounds==0 {player.dogRecoveryClock=0}
    }
    func houndHit() {
        guard phase == .playing,isPlayerActive,vehicle==nil,!damageProtected else{return}
        if collectingPlayerDamage {playerRoster.current.pendingHoundBite=true;return}
        applyHoundBiteDamage()
    }
    func applyHoundBiteDamage(){
        guard phase == .playing,isPlayerActive,vehicle==nil,!damageProtected else{return}
        if woundFraction+1/Double(houndLethalBites)>=1-0.000001 {loseLife();return}
        emitAudio(.hurt);dogWounds+=1;resetWoundRecoveryClocks();invulnerable=0.8
        effects.append(Effect(id:id(),p:hero,ttl:0.28,size:0.8,color:1))
        announce("HUNDEBISS \(dogWounds)/\(houndLethalBites)"+(dogWounds==houndLethalBites-1 ? " · NÄCHSTER BISS KOSTET EIN LEBEN":""))
    }
}

enum HoundRules {
    /// Own tuning until a timed original observation is available.
    static let recoverySecondsPerBite=6.0
}
