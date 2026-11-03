import Foundation

struct ArenaExit {
    let id:Int,side:EntrySide?,p:V2,height:Double,opensAt:Double
    let bonus:SideRoomKind?
    var teleporter:Bool {side==nil}
}
struct ArenaTransit {
    enum Target {case exit(EntrySide?,SideRoomKind?),fateReturn,bossReturn}
    let id:Int,target:Target,fromPhase:RunPhase,fromOrientation:ArenaViewOrientation
    let debounce:Double,hold:Double
    var clock=0.0,committed=false,resumePhase:RunPhase = .playing
    var commitAt:Double {debounce+1+hold}
    var endAt:Double {commitAt+0.2+1.5}
    var darkness:Double {
        if clock<debounce {return 0}
        if clock<debounce+1 {return clock-debounce}
        if clock<commitAt+0.2 {return 1}
        return max(0,1-(clock-commitAt-0.2)/1.5)
    }
    var cameraProgress:Double {max(0,min(1,(clock-commitAt)/0.2))}
}
extension ArenaLayout {
    /// Own editable portal positions inside the traversable perimeter, using existing map collision.
    func playerExit(on side:EntrySide)->V2 {
        let wide=kind == .cave ? 7.5:10.0,deep=kind == .cave ? 4.7:6.3
        let p:V2
        switch side {
        case .north:p=V2(x:0,y:kind == .prison ? -6.4:-deep)
        case .east:p=V2(x:wide,y:entryCrossOffset(side:.east))
        case .south:p=exit
        case .west:p=V2(x:-wide,y:entryCrossOffset(side:.west))
        }
        return clamped(p,clearance:0.4)
    }
}
extension GameCore {
    func exitRandom()->Double {
        exitSeed=exitSeed &* 6364136223846793005 &+ 1442695040888963407
        return Double(exitSeed>>11)/Double(UInt64.max>>11)
    }
    var exitClock:Double {sideRoom?.clock ?? clearClock}
    var availableExits:[ArenaExit] {arenaExits.filter{exitClock+1e-9 >= $0.opensAt}}
    var suggestedExit:V2 {
        let candidates=availableExits.isEmpty ? arenaExits:availableExits
        return candidates.first(where:{$0.bonus != nil})?.p ?? candidates.min(by:{($0.p-hero).length<($1.p-hero).length})?.p ?? layout.exit
    }
    func prepareArenaExits() {
        arenaExits=[];sideRoomOffer=nil
        guard sideRoom?.kind != .fate else{return}
        if sideRoom==nil && round%4==0 {
            // Own safe central pad; source chooses a random pickup location and raises it over3s.
            let sites=[V2(x:0,y:-2.2),V2(x:3,y:0),V2(x:-3,y:0),V2(x:0,y:2.2)].map{layout.clamped($0,clearance:0.75)}
            let p=sites[Int(exitRandom()*Double(sites.count))]
            arenaExits=[ArenaExit(id:id(),side:nil,p:p,height:layout.height(p),opensAt:3,bonus:nil)];return
        }
        var sides=EntrySide.allCases.filter{$0 != previousExitSide}
        for i in stride(from:sides.count-1,through:1,by:-1) {sides.swapAt(i,Int(exitRandom()*Double(i+1)))}
        let count=round%4==3 ? 1:1+Int(exitRandom()*3)
        let nextRound=round==Int.max ? round:round+1
        let magicIndex=count>1 && nextRound-lastMagicExitRound>2 ? Int(exitRandom()*Double(count)):-1
        for i in 0..<count {
            var bonus:SideRoomKind?
            if i==magicIndex {
                let armory=nextRound>4 && ((nextRound>=20 && lastArmoryExitRound==nil) || exitRandom()<0.20)
                bonus=armory ? .armory:.treasure
            }
            let side=sides[i],p=layout.playerExit(on:side)
            arenaExits.append(ArenaExit(id:id(),side:side,p:p,height:layout.height(p),opensAt:Double(i)*0.2,bonus:bonus))
            if let bonus {sideRoomOffer=SideRoomOffer(kind:bonus,p:p)}
        }
    }
    func requestArenaExit(_ exit:ArenaExit) {
        guard arenaTransit==nil,bossVictory==nil,phase == .cleared || (phase == .bonusRoom && sideRoom?.kind != .fate),
              availableExits.contains(where:{$0.id==exit.id}) else{return}
        if exit.teleporter,phase == .cleared,bossRound {beginBossVictory();return}
        stampede?.stop()
        arenaTransit=ArenaTransit(id:id(),target:.exit(exit.side,exit.bonus),fromPhase:phase,fromOrientation:viewOrientation,debounce:exit.teleporter ? 0:0.1,hold:exit.teleporter ? 0:1.7)
        forEachPlayer{cancelBoost()};phase = .transition
    }
    func requestFateReturn() {
        guard arenaTransit==nil,sideRoom?.kind == .fate else{return}
        arenaTransit=ArenaTransit(id:id(),target:.fateReturn,fromPhase:.bonusRoom,fromOrientation:viewOrientation,debounce:0,hold:0)
        phase = .transition
    }
    func positionTeamForArenaEntry() {
        let first=stageRound==1 && sideRoom==nil
        let base=first ? layout.entry:layout.playerExit(on:previousExitSide)*0.80
        let row=(previousExitSide == .north || previousExitSide == .south) ? V2(x:0.75,y:0):V2(x:0,y:0.75)
        forEachPlayer {
            hero=layout.clamped(base+row*(Double(activePlayerSlot)-Double(playerCount-1)*0.5),clearance:vehicle?.kind == .tank ? 0.65:0.4)
            facing=(V2.zero-hero).unit;if facing.length<0.01 {facing=V2(x:0,y:-1)}
            heroElevation=layout.height(hero);heroFallSpeed=0
            if vehicle != nil {repositionVehicleAfterTeleport();vehicle?.heading=facing}
            repositionCompanions()
        }
    }
    private func commitArenaTransit(_ transit:inout ArenaTransit) {
        let previousKind=layout.kind
        transit.committed=true
        switch transit.target {
        case .fateReturn,.bossReturn:startNextCombatRound()
        case .exit(let side,let bonus):
            if let side {previousExitSide=side}
            phase=transit.fromPhase
            if transit.fromPhase == .bonusRoom {startNextCombatRound()}
            else if let bonus {
                lastMagicExitRound=round==Int.max ? round:round+1
                if bonus == .armory {lastArmoryExitRound=lastMagicExitRound}
                enterSideRoom(SideRoomOffer(kind:bonus,p:hero))
            }else{advanceCombatRound()}
        }
        if previousKind == .marketplace,stampede?.mode == .normal,sideRoom==nil {stepStampedeLeadIn(1.7)}
        if phase == .gameOver {arenaTransit=nil;return}
        transit.resumePhase=phase
        if phase == .bonusRoom && sideRoom?.kind != .fate {positionTeamForArenaEntry()}
        phase = .transition
    }
    func stepArenaTransit(_ dt:Double) {
        guard var transit=arenaTransit,phase == .transition,dt.isFinite,dt>=0 else{return}
        var remaining=dt
        repeat {
            let deadline=transit.committed ? transit.endAt:transit.commitAt
            let used=min(remaining,max(0,deadline-transit.clock))
            if used>0 {
                let flow=combatSpawnFlow,flowClock=flow?.clock ?? 0
                let active=arenaTransit?.committed != true && sideRoom==nil && flow?.held != true && flow?.forcedFinished != true ? min(used,max(0,(flow?.sequenceEndsAt ?? 0)-flowClock)):0
                stepStampedeTransition(used,transit:transit)
                stepBackgroundCombatSpawns(used);stepRareLifeTimer(used)
                stepRetiringOrbs(used,at:elapsed+used)
                elapsed+=used;messageTime=max(0,messageTime-used);stepWorldLoot(used,activeWindows:active>0 ? [0..<active]:[])
                forEachLivingPlayer{invulnerable=max(0,invulnerable-used);stepPlayerWoundRecovery(used)}
                arenaTransit=transit;stepTeamRecovery(used);forEachLivingPlayer{collectNearbyPickups()};collectDirectedRewards()
                if phase == .gameOver {arenaTransit=nil;return}
                transit.clock+=used;remaining=max(0,remaining-used)
            }
            if transit.clock+1e-9>=deadline {
                if !transit.committed {commitArenaTransit(&transit)}
                else {phase=transit.resumePhase;arenaTransit=nil;return}
            }
            if phase == .gameOver {arenaTransit=nil;return}
            arenaTransit=transit
            if used==0 && remaining>0 && transit.clock<deadline {break}
        }while remaining>1e-9
    }
    func exitDirection(_ point:V2)->String {
        let p=viewOrientation.transform(point)
        return abs(p.x)>abs(p.y) ? (p.x<0 ? "LINKS":"RECHTS"):(p.y<0 ? "OBEN":"UNTEN")
    }
    var exitInstruction:String {
        let exits=availableExits
        if exits.isEmpty {return arenaExits.first?.teleporter==true ? "TELEPORTER WIRD BEREIT":"WEGE ÖFFNEN"}
        return exits.map{exit in
            if exit.teleporter {return "ZUM TELEPORTER"}
            return (exit.bonus==nil ? "WEG ":"GOLDENER WEG ")+exitDirection(exit.p)
        }.joined(separator:" · ")
    }
}
