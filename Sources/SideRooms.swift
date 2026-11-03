import Foundation

enum SideRoomKind:Int {case treasure, armory, fate
    var title:String {self == .treasure ? "BONUSRAUM":self == .armory ? "WAFFENKAMMER":"RAUM DES SCHICKSALS"}
}
struct SideRoomOffer {let kind:SideRoomKind, p:V2}
struct SideRoomState {let kind:SideRoomKind, sourceRound:Int;var clock=0.0}

extension GameCore {
    func enterSideRoom(_ offer:SideRoomOffer) {
        guard offer.kind != .fate,phase == .cleared,sideRoom==nil,!visitedSideRoomRounds.contains(round),!bossRound else{return}
        if takeFateRouteIfDue() {return}
        retireCombatSpawning()
        clearElectricHazards();clearArenaSupport();visitedSideRoomRounds.insert(round);sideRoom=SideRoomState(kind:offer.kind,sourceRound:round)
        sideRoomOffer=nil;phase = .bonusRoom;martyrDamagePending=false;barrels=[];barrelDamagePending=false;bulls=[];foes=[];shots=[];clearWorldLoot();effects=[]
        flameJets=[];forEachPlayer{hero=layout.clamped(teamPosition(V2(x:0,y:-5.4),slot:activePlayerSlot));cancelBoost();heroElevation=flying ? max(3.1,layout.height(hero)+1.2):layout.height(hero);heroFallSpeed=0;clearDeferredPlayerDamage();repositionCompanions()};environmentRevision+=1
        if offer.kind == .treasure {sourceLoot?.queueBonusRoom(random:{self.random()})}
        else {sourceLoot?.queueArmory(players:playerCount)}
        stepWorldLoot(0)
        announce("\(offer.kind.title) ENTDECKT · EINSAMMELN UND WEITERZIEHEN")
        prepareArenaExits()
    }
    func advanceCombatRound() {
        if takeFateRouteIfDue() {return}
        if bossRound {beginBossVictory();return}
        startNextCombatRound()
    }
    func collectNearbyPickups() {
        guard isPlayerActive else{return}
        let found=pickups.filter{$0.readyForContact && ($0.p-hero).length<0.8 && (flying || abs(layout.height($0.p)-heroElevation)<0.65)}
        pickups.removeAll{$0.readyForContact && ($0.p-hero).length<0.8 && (flying || abs(layout.height($0.p)-heroElevation)<0.65)}
        collectedWorldFunds+=found.count;if sideRoom != nil {collectedRoomFunds+=found.count}
        for p in found {apply(p.kind,at:p.p,loot:p.loot,gemUnits:p.gemUnits)}
    }
    func stepSideRoom(_ dt:Double,input:Controls) {stepSideRoom(dt,inputs:[input])}
    func stepSideRoom(_ dt:Double,inputs:[Controls]) {
        guard dt.isFinite,dt>=0,var room=sideRoom else{return}
        stepRetiringCombatSpawns(dt);stepRareLifeTimer(dt)
        room.clock+=dt;sideRoom=room;elapsed+=dt;messageTime=max(0,messageTime-dt)
        stepTesla(dt,at:elapsed)
        forEachLivingPlayer{invulnerable=max(0,invulnerable-dt);stepPlayerWoundRecovery(dt)}
        stepTeamRecovery(dt)
        effects=effects.compactMap{var e=$0;e.ttl-=dt;return e.ttl>0 ? e:nil}
        stepWorldLoot(dt)
        for player in players where !player.isDown {
            guard phase == .bonusRoom else{return}
            withPlayer(player.slot) {
                let input=controls(for:activePlayerSlot,in:inputs)
                if input.aim.length>0.18 {facing=input.aim.unit}
                if vehicle != nil {moveVehicle(dt,move:input.move)}
                else {hero=layout.moved(hero,by:input.move.unit*(dt*moveSpeed*min(1,input.move.length)))}
                updateHeroElevation(dt)
                updateCompanions(dt,advanceTimers:false);stepSupportPowers(dt,advanceTimers:false)
                collectNearbyPickups()
                // Temporary equipment is not spent while exploring safe rooms.
                if room.kind != .fate {_=tryTeamExit()}
            }
        }
        collectDirectedRewards()
        if room.kind == .fate {stepFateLifeStatues();stepFateRoom()}
    }
}
