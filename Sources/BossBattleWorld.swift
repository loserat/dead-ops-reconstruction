import Foundation

extension GameCore {
    func beginSilverbackEncounter() {
        guard bossRound,!silverbackStarted else{return}
        silverbackStarted=true;bossArenaCleared=false;silverbacks=[];sourceBossDead=false
        bossArrivalClock=BossArrivalClock(round:round);bossFrameBirths=[:]
        sideRoomOffer=nil;emitAudio(.boss)
        announce(bossCount==1 ? "BOSSRUNDE · THE COSMIC SILVERBACK":"BOSSRUNDE · \(bossCount) SILVERBACKS")
        messageTime=5.1
    }
    func admitSilverbackBrother(_ ordinal:Int,frameOffset:Double=0) {
        var boss=Silverback();boss.id=id()
        boss.arrival=layout.enemyArrival(index:[0,2,1,3][ordinal%4],lane:Double((ordinal/4)%3-1)*0.5)
        boss.p=boss.arrival!.start.p
        silverbacks.append(boss);sourceBossDead=false;bossFrameBirths[boss.id]=frameOffset
    }
    func startSourceBossProgram() {
        guard prepareCombatSpawning(boss:true),let flow=combatSpawnFlow else{return}
        if let last=silverbacks.last {
            flow.monitoredBossID=last.id;flow.healthBurst=BossHealthBurstClock(health:last.hp)
        }
    }
    /// Splits only source clocks at their real boundaries. Combat/physics still use
    /// the existing frame update; newly born bosses receive only their remaining frame.
    @discardableResult func stepGameplaySpawns(_ dt:Double)->[Range<Double>] {
        bossFrameBirths=[:]
        guard dt.isFinite,dt>0 else{return []}
        var windows=[Range<Double>](),offset=0.0
        func segment(_ duration:Double) {
            let flow=combatSpawnFlow,start=flow?.clock ?? 0
            stepCombatSpawns(duration)
            if phase == .playing,let flow,!flow.forcedFinished {
                let active=flow.held ? (flow.roundActive ? duration:0):min(duration,max(0,flow.sequenceEndsAt-start))
                if active>0 {windows.append(offset..<(offset+active))}
            }
            offset+=duration
        }
        while let intro=bossArrivalClock,!intro.battleStarted,offset<dt {
            let duration=min(dt-offset,max(0,(intro.nextEventAt ?? intro.clock)-intro.clock))
            guard duration>0 else{break}
            segment(duration)
            var updated=intro
            let events=updated.step(duration);bossArrivalClock=updated
            for event in events {
                switch event {
                case .brother(let ordinal):admitSilverbackBrother(ordinal,frameOffset:offset)
                case .startBattle:startSourceBossProgram()
                }
            }
            if phase == .checkpointComplete {return windows}
        }
        if offset<dt {segment(dt-offset)}
        return windows
    }
    var allSilverbacksDefeated:Bool {
        bossArrivalClock?.battleStarted==true && silverbacks.count==bossCount &&
        !silverbacks.isEmpty && silverbacks.allSatisfy{$0.hp<=0 && $0.deathClock>=2}
    }
    func clearSourceBossRoundIfReady() {
        guard phase == .playing,allSilverbacksDefeated,
              foes.isEmpty,bulls.isEmpty,barrels.isEmpty else{return}
        bossArenaCleared=true;phase = .cleared;clearClock=0;seedBossTreasure(at:hero);cleanupSourceRoundVehicles()
        prepareArenaExits();announce("RUNDE \(round) GESCHAFFT · ZUM TELEPORTER")
    }
}
