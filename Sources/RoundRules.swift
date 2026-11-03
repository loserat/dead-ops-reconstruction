import Foundation

/// Forty-round arena structure;health scaling remains provisional,spawns use TimedAttackWaves.
enum RoundRules {
    static let cycleLength=40
    static func stage(_ round:Int)->Int {(max(1,round)-1)%cycleLength+1}
    static func loop(_ round:Int)->Int {(max(1,round)-1)/cycleLength}
    static func health(_ kind:FoeKind,round:Int)->Double {
        let base=kind == .hound ? 2.0:kind == .martyr ? 30:kind == .sasquatch ? 12:kind == .engineer ? 6:kind == .crawler ? 8:Double(round<3 ? 1:round<7 ? 2:round<11 ? 3:4)
        return base*Double(loop(round)+1)
    }
}
/// Scripted victory window: 1s after touching the boss teleporter, then 7s of HUD.
/// The original cinematic length is not supplied by these scripts. Its local replacement stays 2.8s.
struct BossVictory {
    static let leadIn=1.0,hudDuration=7.0,duration=leadIn+hudDuration
    let fromRound:Int
    var clock=0.0
    var hudClock:Double {clock-Self.leadIn}
    var titleOpacity:Double {opacity(start:0,fadeIn:2)}
    var subtitleOpacity:Double {opacity(start:0,fadeIn:2.5)}
    var brotherOpacity:Double {opacity(start:2,fadeIn:2.5)}
    private func opacity(start:Double,fadeIn:Double)->Double {
        guard hudClock>=start,hudClock<Self.hudDuration else{return 0}
        return hudClock<5 ? min(1,(hudClock-start)/fadeIn):max(0,(7-hudClock)/2)
    }
}
struct LoopReturn {
    static let duration=2.8
    let fromRound:Int,visitor:V2
    var clock=0.0
    var visitorHeight:Double {max(0,7-clock*8)}
    var flight:Double {max(0,min(1,(clock-1.3)/1.3))}
    var lift:Double {sin(flight*Double.pi)*5+flight*4}
    var displacement:V2 {V2(x:-flight*4,y:-flight*3)}
}
extension GameCore {
    var loopIndex:Int {RoundRules.loop(round)}
    var stageRound:Int {RoundRules.stage(round)}
    var bossRound:Bool {round>0 && round%RoundRules.cycleLength==0}
    var bossCount:Int {bossRound ? round/RoundRules.cycleLength:0}
    func beginBossVictory() {
        guard phase == .cleared,bossRound,silverbackStarted,allSilverbacksDefeated,bossVictory==nil,loopReturn==nil,arenaTransit==nil else{return}
        bossVictory=BossVictory(fromRound:round);emitAudio(.victory)
        announce("SILVERBACK BESIEGT")
    }
    func stepBossVictory(_ dt:Double,inputs:[Controls]) {
        guard var victory=bossVictory,phase == .cleared,dt.isFinite,dt>=0 else{return}
        let used=min(dt,max(0,BossVictory.duration-victory.clock))
        // The script does not freeze controls for its victory HUD. Continue the normal
        // cleared-round movement, equipment, physical pickups and recovery before the movie.
        advancingBossVictory=true;step(used,inputs:inputs);advancingBossVictory=false
        guard phase == .cleared,round==victory.fromRound,bossVictory != nil else{bossVictory=nil;return}
        victory.clock+=used;bossVictory=victory
        if victory.clock+1e-9>=BossVictory.duration {
            bossVictory=nil;beginLoopReturn()
            if dt>used {stepLoopReturn(dt-used)}
        }
    }
    private func beginLoopReturn() {
        guard phase == .cleared,bossRound,silverbackStarted,allSilverbacksDefeated else{return}
        clearArenaSupport();foes=[];shots=[];flameJets=[];effects=[];clearWorldLoot();bulls=[];barrels=[]
        sideRoomOffer=nil;bossVictory=nil;forEachPlayer{cancelBoost()}
        loopReturn=LoopReturn(fromRound:round,visitor:layout.clamped(hero+V2(x:1.9,y:-1.0),clearance:0.9));phase = .loopReturn
        announce("EIN WEITERER SILVERBACK · ZURÜCK ZUR INSEL")
    }
    func stepLoopReturn(_ dt:Double) {
        guard var transit=loopReturn,phase == .loopReturn,dt.isFinite,dt>=0 else{return}
        let used=min(dt,max(0,LoopReturn.duration-transit.clock))
        stepRareLifeTimer(used);stepWorldLoot(used)
        transit.clock+=used;elapsed+=used;messageTime=max(0,messageTime-used);loopReturn=transit
        if transit.clock+1e-9>=LoopReturn.duration {
            transit.clock=LoopReturn.duration;loopReturn=transit
            // Keep the final movie pose until black; the map is replaced only at fade-out completion.
            arenaTransit=ArenaTransit(id:id(),target:.bossReturn,fromPhase:.loopReturn,fromOrientation:viewOrientation,debounce:0,hold:0)
            phase = .transition
            if dt>used {stepArenaTransit(dt-used)}
        }
    }
    func startNextCombatRound() {
        bossVictory=nil;loopReturn=nil
        if let room=sideRoom,room.kind != .fate {bonusViewFlip.toggle()}
        clearArenaSupport();round+=1;flameJets=[];sideRoom=nil;fateRoom=nil;martyrDamagePending=false;barrels=[];barrelDamagePending=false;bulls=[];foes=[];shots=[];clearWorldLoot();effects=[]
        forEachPlayer{hero=teamPosition(layout.entry,slot:activePlayerSlot);invulnerable=max(invulnerable,2);clearDeferredPlayerDamage()}
        phase = .playing
        environmentRevision+=1;beginRound();positionTeamForArenaEntry()
    }
}
