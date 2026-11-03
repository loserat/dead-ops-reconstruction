import Foundation

/// Real timed admissions. No fixed population, reserved slot or deferred failed spawn.
final class CombatSpawnFlow {
    var waves:TimedAttackWaves
    var bossWaves:BossAttackWaves?
    var healthBurst:BossHealthBurstClock?,monitoredBossID:Int?
    let round:Int,arenaRevision:Int
    var held=false,forcedFinished=false
    var nextDeathCheck:Double
    var nextMini:Double?
    var miniAttempts=0,miniAdmitted=0,retiredAtExit=0
    init(round:Int,arenaRevision:Int,players:Int,boss:Bool=false,random:()->Double)throws {
        self.round=round;self.arenaRevision=arenaRevision
        waves=try TimedAttackWaves(round:round,random:random)
        if boss {bossWaves=BossAttackWaves(templates:waves.groups)}
        nextDeathCheck=boss ? .infinity:waves.mainFunctionReturnsAt
        if !Self.unlocked(round).isEmpty {nextMini=Self.miniDelay(round:round,players:players,random:random())}
    }
    var clock:Double {bossWaves?.clock ?? waves.clock}
    var sequenceEndsAt:Double {if let boss=bossWaves {return boss.mainSequenceEndsAt ?? .infinity};return waves.mainSequenceEndsAt}
    var functionReturnsAt:Double {if let boss=bossWaves {return boss.mainFunctionReturnsAt ?? .infinity};return waves.mainFunctionReturnsAt}
    var functionHasReturned:Bool {bossWaves?.mainFunctionHasReturned ?? waves.mainFunctionHasReturned}
    var roundActive:Bool {!forcedFinished && (bossWaves?.roundActiveFlag ?? waves.roundActiveFlag)}
    var pendingCount:Int {bossWaves?.pendingAttemptCount ?? waves.pendingAttemptCount}
    var nextProgramEvent:Double? {bossWaves?.nextEventAt ?? (bossWaves == nil ? waves.nextAttemptAt:nil)}
    var currentSide:EntrySide {bossWaves?.currentGroup?.side ?? waves.currentGroup?.side ?? .north}
    static func unlocked(_ round:Int)->[FoeKind] {
        [(9,FoeKind.prisoner),(13,.crawler),(17,.villager),(22,.engineer),(30,.sasquatch),(34,.hound)].filter{$0.0<round}.map{$0.1}
    }
    static func miniDelay(round:Int,players:Int,random:Double)->Double {
        max(1,(5+5*random)/Double(max(1,players))-Double(round)/10)
    }
    func takeDeathCheck()->Bool {
        if forcedFinished {return true}
        guard !held,functionHasReturned else{return false}
        if !nextDeathCheck.isFinite {nextDeathCheck=functionReturnsAt}
        guard clock+1e-9>=nextDeathCheck else{return false}
        repeat {nextDeathCheck+=1}while nextDeathCheck<=clock
        return true
    }
    func finish(){waves.cancel();bossWaves?.cancel();healthBurst?.cancel();nextMini=nil;forcedFinished=true;held=false}
}
extension ArenaLayout {
    func entrance(on side:EntrySide,roll:Double)->Int {
        let candidates=(0..<enemyEntranceCount).filter{enemyEntrySide(index:$0)==side}
        precondition(!candidates.isEmpty,"An arena must have physical entrances on every source side")
        return candidates[min(candidates.count-1,Int(max(0,min(1.0.nextDown,roll))*Double(candidates.count)))]
    }
}
extension GameCore {
    var spawnRemaining:Int {combatSpawnFlow?.pendingCount ?? 0}
    var spawnClock:Double {guard let flow=combatSpawnFlow,let next=flow.nextProgramEvent else{return 0};return max(0,next-flow.clock)}
    var combatSpawningHeld:Bool {
        get{combatSpawnFlow?.held ?? false}
        set{combatSpawnFlow?.held=newValue}
    }
    func finishCombatSpawning(){combatSpawnFlow?.finish()}
    func retireCombatSpawning() {
        if let old=combatSpawnFlow,(old.pendingCount>0 || (old.bossWaves != nil && old.roundActive)),!old.forcedFinished,!old.held {retiringSpawnFlows.append(old)}
        combatSpawnFlow=nil
    }
    func prepareCombatSpawning(boss:Bool=false)->Bool {
        retireCombatSpawning()
        do {combatSpawnFlow=try CombatSpawnFlow(round:round,arenaRevision:environmentRevision,players:playerCount,boss:boss,random:{self.random()});return true}
        catch {combatSpawnFlow=nil;phase = .checkpointComplete;announce("RUNDE KANN NICHT GELADEN WERDEN");return false}
    }
    func ordinaryWaveKind()->FoeKind {
        switch round {
        case 9:return .prisoner
        case 13:return .crawler
        case 17:return .villager
        case 22:return .engineer
        case 30:return .sasquatch
        case 34:return .hound
        default:return layout.kind == .prison ? .prisoner:.zombie
        }
    }
    @discardableResult func admitWaveEnemy(side:EntrySide,kind:FoeKind?=nil,worldVisible:Bool=true)->Bool {
        // The script chooses a spawn point even when engine admission subsequently fails.
        let entry=layout.entrance(on:side,roll:random()),lane=random()*2-1,selected=kind ?? ordinaryWaveKind()
        guard enemySpawnCapacity>0 else{return false}
        guard worldVisible else {return true} // Off-map/exit cleanup has no player score or drop.
        let hp=RoundRules.health(selected,round:round),speed=1.15+random()*0.6+Double(min(round,12))*0.14
        var foe=arrivingFoe(kind:selected,hp:hp,speed:speed,entrance:entry,lane:lane)
        let mini=kind != nil || [9,13,17,22,30,34].contains(round)
        foe.referenceVitality=ReferenceVitality.foe(selected,round:round,mini:mini,localMaximum:hp)
        foes.append(foe);return true
    }
    private var sourceExitsOpen:Bool {
        phase == .cleared && clearClock>=(arenaExits.map(\.opensAt).max() ?? 0)+0.2
    }
    func stepCombatSpawns(_ dt:Double) {
        guard dt.isFinite,dt>0 else{return}
        roundClock+=dt
        guard let flow=combatSpawnFlow,!flow.held,!flow.forcedFinished else{return}
        let visible=phase == .playing || (phase == .cleared && !sourceExitsOpen)
        func admission(_ side:EntrySide)->Bool {
            if self.silverbackStarted && !self.silverbacks.isEmpty && self.sourceBossDead {return false}
            if self.round==30 && self.random()<0.20 {
                if self.admitWaveEnemy(side:side,kind:.martyr,worldVisible:visible) {if !visible {flow.retiredAtExit+=1};return true}
            }
            let admitted=self.admitWaveEnemy(side:side,worldVisible:visible)
            if admitted && !visible {flow.retiredAtExit+=1};return admitted
        }
        func waveStep(_ chunk:Double) {
            if var boss=flow.bossWaves {
                _=boss.step(chunk,processCurrentEvents:true,bossDead:self.sourceBossDead,rollbackRandom:{self.random()},admit:{admission($0.side)})
                flow.bossWaves=boss
            }else {_=flow.waves.step(chunk){admission($0.side)}}
        }
        let target=flow.clock+dt
        repeat {
            let mini=flow.nextMini.flatMap{$0<flow.sequenceEndsAt ? $0:nil}
            let hp=flow.healthBurst?.nextEventAt
            let next=min(mini ?? .infinity,hp ?? .infinity)
            let stop=min(target,max(flow.clock,next)),chunk=stop-flow.clock
            waveStep(chunk)
            if var monitor=flow.healthBurst {
                monitor.step(chunk,processCurrentEvents:true,health:{self.silverbacks.first{$0.id==flow.monitoredBossID}?.hp ?? 0},random:{self.random()},admit:{event in
                    self.admitWaveEnemy(side:flow.currentSide,kind:event.kind,worldVisible:visible)
                });flow.healthBurst=monitor
            }
            if let due=mini,due<=flow.clock+1e-9,due<flow.sequenceEndsAt {
            let pool=CombatSpawnFlow.unlocked(round)
            let side=flow.currentSide
            if Int(random()*100)<30+round*playerCount,!pool.isEmpty {
                let kind=pool[min(pool.count-1,Int(random()*Double(pool.count)))]
                flow.miniAttempts+=1
                if admitWaveEnemy(side:side,kind:kind,worldVisible:visible) {flow.miniAdmitted+=1}
                if playerCount==4 && pool.contains(.engineer) {
                    flow.miniAttempts+=1
                    if admitWaveEnemy(side:side,kind:.engineer,worldVisible:visible) {flow.miniAdmitted+=1}
                }
            }
            flow.nextMini=due+CombatSpawnFlow.miniDelay(round:round,players:playerCount,random:random())
            }
            if flow.clock>=flow.sequenceEndsAt {flow.nextMini=nil}
            if flow.clock>=target-1e-12 {break}
        }while true
    }
    /// Old group timers keep expiring after a map change; they cannot create bodies on the new map.
    func stepRetiringCombatSpawns(_ dt:Double) {
        guard dt.isFinite,dt>0 else{return}
        for flow in retiringSpawnFlows where !flow.held {
            if var boss=flow.bossWaves {
                _=boss.step(dt,bossDead:true,rollbackRandom:{0},admit:{_ in flow.retiredAtExit+=1;return true});flow.bossWaves=boss
            }else {_=flow.waves.step(dt){_ in flow.retiredAtExit+=1;return true}}
        }
        retiringSpawnFlows.removeAll{$0.pendingCount==0}
    }
    func stepBackgroundCombatSpawns(_ dt:Double) {
        if arenaTransit?.committed != true,sideRoom==nil {stepCombatSpawns(dt)}
        stepRetiringCombatSpawns(dt)
    }
}
