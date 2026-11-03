import Foundation

/// Burst severity is collected before any respawn can mutate enemy/projectile arrays.
enum DeferredBlast:Int {case none,houndBite,barrelFringe,martyrFringe,lethal}
enum BlastSource {
    case barrel,martyr
    var profile:BlastProfile {self == .barrel ? BlastProfile(inner:1.65,outer:2.1,fringe:.barrelFringe):BlastProfile(inner:1.5,outer:2.65,fringe:.martyrFringe)}
}
struct BlastProfile {
    let inner:Double,outer:Double,fringe:DeferredBlast
    func impact(distance:Double)->DeferredBlast {
        guard distance.isFinite,distance>=0,distance<outer else{return .none}
        return distance<inner ? .lethal:fringe
    }
}
enum PlayerDamageRules {
    // The source establishes survivable blasts and mixed injuries, not exact original fractions/radii/rates.
    static let barrelFraction=0.5,martyrFraction=0.75,barrelRecoverySeconds=6.0
}
extension GameCore {
    var acceptsPlayerDamage:Bool {(phase == .playing || phase == .cleared) && isPlayerActive && vehicle==nil && !damageProtected}
    var woundFraction:Double {
        let p=playerRoster.current
        return Double(dogWounds)/Double(houndLethalBites)+Double(p.barrelWounds)*PlayerDamageRules.barrelFraction+Double(p.martyrWounds)*PlayerDamageRules.martyrFraction
    }
    var hasPlayerWounds:Bool {dogWounds>0 || playerRoster.current.barrelWounds>0 || playerRoster.current.martyrWounds>0}
    var woundRecoveryActive:Bool {playerRoster.current.barrelWounds>0 || (dogWounds>0 && houndRecoveryEnabled)}
    var playerWoundText:String {
        let blast=playerRoster.current.barrelWounds>0 || playerRoster.current.martyrWounds>0
        return (blast ? "DRUCKWELLE":"")+(blast && dogWounds>0 ? " · ":"")+houndWoundText
    }
    func resetWoundRecoveryClocks(){playerRoster.current.dogRecoveryClock=0;playerRoster.current.barrelRecoveryClock=0}
    func clearDeferredPlayerDamage(){let p=playerRoster.current;p.pendingHoundBite=false;p.pendingBarrelBlast = .none;p.pendingMartyrBlast = .none}
    func clearPlayerWounds(){
        clearHoundWounds();playerRoster.current.barrelWounds=0;playerRoster.current.martyrWounds=0;playerRoster.current.barrelRecoveryClock=0;clearDeferredPlayerDamage()
    }
    func stepPlayerWoundRecovery(_ dt:Double){
        guard dt.isFinite,dt>0,isPlayerActive,phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .transition else{return}
        stepHoundRecovery(dt)
        let p=playerRoster.current
        guard p.barrelWounds>0 else{p.barrelRecoveryClock=0;return}
        p.barrelRecoveryClock+=dt
        while p.barrelRecoveryClock>=PlayerDamageRules.barrelRecoverySeconds && p.barrelWounds>0 {
            p.barrelRecoveryClock-=PlayerDamageRules.barrelRecoverySeconds;p.barrelWounds-=1
        }
        if p.barrelWounds==0 {p.barrelRecoveryClock=0}
    }
    func queueBlast(_ source:BlastSource,distance:Double){
        guard acceptsPlayerDamage else{return}
        let impact=source.profile.impact(distance:distance),p=playerRoster.current
        if source == .barrel {if impact.rawValue>p.pendingBarrelBlast.rawValue {p.pendingBarrelBlast=impact}}
        else if impact.rawValue>p.pendingMartyrBlast.rawValue {p.pendingMartyrBlast=impact}
    }
    func applyBlastDamage(_ impact:DeferredBlast){
        guard impact != .none,acceptsPlayerDamage else{return}
        if impact == .houndBite {applyHoundBiteDamage();return}
        if impact == .lethal {loseLife(allowAfterRound:true);return}
        let damage=impact == .barrelFringe ? PlayerDamageRules.barrelFraction:PlayerDamageRules.martyrFraction
        if woundFraction+damage>=1-0.000001 {loseLife(allowAfterRound:true);return}
        let p=playerRoster.current
        if impact == .barrelFringe {p.barrelWounds+=1}else{p.martyrWounds+=1}
        resetWoundRecoveryClocks();invulnerable=0.8;emitAudio(.hurt)
        effects.append(Effect(id:id(),p:hero,ttl:0.28,size:0.8,color:1))
        announce(impact == .barrelFringe ? "DRUCKWELLE · IN SICHERHEIT ERHOLEN":"MÄRTYRER-WUNDE · NÄCHSTER BISS IST TÖDLICH")
    }
    func resolveDeferredBlasts(){
        forEachPlayer {
            let p=playerRoster.current,impact=DeferredBlast(rawValue:max(p.pendingHoundBite ? DeferredBlast.houndBite.rawValue:0,max(p.pendingBarrelBlast.rawValue,p.pendingMartyrBlast.rawValue)))!
            clearDeferredPlayerDamage()
            // One protection window per combined burst; a direct hit wins over its fringe.
            applyBlastDamage(impact)
        }
    }
}
