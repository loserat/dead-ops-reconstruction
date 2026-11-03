import Foundation

struct TeamLifeAward {
    var nextSlot=0
    var waitRemaining=0.0
}
extension GameCore {
    var isPlayerActive:Bool {!playerRoster.current.isDown}
    var livingPlayers:[RunPlayer] {players.filter{!$0.isDown}}
    var hasRecoverablePlayer:Bool {players.contains{!$0.isDown || $0.lives>0 || $0.sponsoredRespawn}}

    func finishTeamRun() {
        guard phase != .gameOver else{return}
        combatSpawnFlow?.finish();retiringSpawnFlows=[]
        pendingLifeAwards=[];lifeTransfers=[];directedLifeRewards=[]
        bossVictory=nil;loopReturn=nil;sourceLoot?.clearArenaChildren()
        phase = .gameOver;gameOverSequence=GameOverSequence();announce("GAME OVER")
    }
    /// Funded returns keep their reserve until the two-second callback completes.
    func queueReserveRespawn() {
        let player=playerRoster.current
        guard player.isDown,(player.lives>0 || player.sponsoredRespawn),player.respawnRemaining==nil else{return}
        player.respawnRemaining=RecoveryRules.reserveWait;player.hasRecoveryProcess=true
        player.recoveryWatchActive=false;player.donationSearchActive=false
    }
    /// Common return at the body's current world position; a map change may have moved that body.
    func respawnSelectedPlayer() {
        let player=playerRoster.current
        player.isDown=false;player.reviveRemaining=0;player.respawnRemaining=nil;player.sponsoredRespawn=false
        player.hasRecoveryProcess=false;player.recoveryWatchActive=false;player.donationSearchActive=false
        cancelBoost();clearPlayerWounds();clearDeferredPlayerDamage()
        hero=layout.clamped(hero,clearance:0.29);heroElevation=max(layout.height(hero),heroElevation);heroFallSpeed=0
        restoreFateBenefits();repositionCompanions();invulnerable=0;beginBodyShield()
        emitAudio(.respawn)
    }
    /// Each ordinary life pickup walks the roster; a downed player holds that callback for two seconds.
    func advanceTeamLifeAwards() {
        var index=0
        while index<pendingLifeAwards.count {
            var award=pendingLifeAwards[index]
            if award.waitRemaining>0.000000001 {index+=1;continue}
            while award.nextSlot<players.count {
                let slot=award.nextSlot,wasDown=players[slot].isDown;award.nextSlot+=1
                withPlayer(slot){grantExtraLife()}
                if wasDown {award.waitRemaining=2;break}
            }
            if award.nextSlot>=players.count && award.waitRemaining<=0.000000001 {pendingLifeAwards.remove(at:index)}
            else {pendingLifeAwards[index]=award;index+=1}
        }
    }
    func startUnfundedRecovery(timeout:Double=RecoveryRules.automatic) {
        let player=playerRoster.current
        player.reviveRemaining=max(0,timeout);player.respawnRemaining=nil
        player.hasRecoveryProcess=true;player.recoveryWatchActive=true;player.lifeWatchRemaining=RecoveryRules.creditInterval
        player.donationSearchActive=playerCount>1;player.donationPollRemaining=RecoveryRules.searchInterval
    }
    private func prepareRecoveryEvents() {
        for player in players where player.isDown {
            if !player.hasRecoveryProcess {withPlayer(player.slot){startUnfundedRecovery(timeout:player.reviveRemaining)}}
            guard player.respawnRemaining==nil else{continue}
            if player.reviveRemaining<=0.000000001 && player.lives==0 && !player.sponsoredRespawn {
                withPlayer(player.slot){respawnSelectedPlayer()};announce("SPIELER \(player.slot+1) ZURÜCK");continue
            }
            if player.lives>0 {withPlayer(player.slot){queueReserveRespawn()};continue}
            if player.recoveryWatchActive && player.lifeWatchRemaining<=0.000000001 {
                player.lifeWatchRemaining=RecoveryRules.creditInterval
                if player.sponsoredRespawn {withPlayer(player.slot){queueReserveRespawn()};continue}
            }
            if player.donationSearchActive && player.donationPollRemaining<=0.000000001 {
                player.donationPollRemaining=RecoveryRules.searchInterval
                if player.sponsoredRespawn || player.lives>0 {player.donationSearchActive=false;continue}
                let hasDonor=players.contains{$0.slot != player.slot && $0.lives>0}
                if hasDonor {
                    // The source search exits after selecting a richest role even if that transfer is busy.
                    player.donationSearchActive=false;tryDonateLife(to:player.slot)
                }
            }
        }
    }
    /// Shared event clock: polling, charge, flight, funded return and individual physical reward drops.
    func stepTeamRecovery(_ dt:Double) {
        guard dt.isFinite,dt>=0,phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .transition else{return}
        guard hasRecoverablePlayer || lifeTransfers.contains(where:{$0.stage == .flying}) else{finishTeamRun();return}
        for player in players {player.shieldContactThisStep=false}
        advanceTeamLifeAwards();prepareRecoveryEvents()
        var remaining=dt
        while remaining>0.000000001 {
            var chunk=remaining
            for player in players where player.isDown {
                if let due=player.respawnRemaining,due>0 {chunk=min(chunk,due)}
                if player.reviveRemaining>0 {chunk=min(chunk,player.reviveRemaining)}
                if player.recoveryWatchActive && player.lifeWatchRemaining>0 {chunk=min(chunk,player.lifeWatchRemaining)}
                if player.donationSearchActive && player.donationPollRemaining>0 {chunk=min(chunk,player.donationPollRemaining)}
            }
            for award in pendingLifeAwards where award.waitRemaining>0 {chunk=min(chunk,award.waitRemaining)}
            for transfer in lifeTransfers where transfer.remaining>0 {chunk=min(chunk,transfer.remaining)}
            for reward in directedLifeRewards where !reward.landed && reward.fallClock<RecoveryRules.dropFall {chunk=min(chunk,RecoveryRules.dropFall-reward.fallClock)}
            var automatic=[Int]()
            for player in players {
                advanceBodyShield(player,chunk)
                player.donationCooldown=max(0,player.donationCooldown-chunk)
                guard player.isDown else{continue}
                if let due=player.respawnRemaining {player.respawnRemaining=max(0,due-chunk)}
                if player.recoveryWatchActive {player.lifeWatchRemaining=max(0,player.lifeWatchRemaining-chunk)}
                if player.donationSearchActive {player.donationPollRemaining=max(0,player.donationPollRemaining-chunk)}
                if player.reviveRemaining>0 {
                    player.reviveRemaining=max(0,player.reviveRemaining-chunk)
                    if player.reviveRemaining<=0.000000001 {automatic.append(player.slot)}
                }
            }
            for i in pendingLifeAwards.indices {pendingLifeAwards[i].waitRemaining=max(0,pendingLifeAwards[i].waitRemaining-chunk)}
            for i in lifeTransfers.indices {lifeTransfers[i].remaining=max(0,lifeTransfers[i].remaining-chunk);lifeTransfers[i].clock+=chunk}
            advanceDirectedRewards(chunk)
            // Stable own tie policy: free return, funded return, transfer arrival, then a polling wakeup.
            for slot in automatic where players[slot].isDown {withPlayer(slot){respawnSelectedPlayer()}}
            for player in players where player.isDown {
                if let due=player.respawnRemaining,due<=0.000000001 {
                    if player.sponsoredRespawn || player.lives>0 {
                        if !player.sponsoredRespawn {player.lives-=1}
                        withPlayer(player.slot){respawnSelectedPlayer()}
                    }else {withPlayer(player.slot){startUnfundedRecovery()}}
                }
            }
            resolveLifeTransferDeadlines();advanceTeamLifeAwards();prepareRecoveryEvents();remaining=max(0,remaining-chunk)
        }
    }
    /// Free round-boundary return applies only to a body with no spare life; funded returns retain their own delay.
    func restoreWaitingTeamAtRoundStart() {
        guard playerCount>1,phase == .playing else{return}
        for player in players where player.isDown && player.lives==0 {withPlayer(player.slot){respawnSelectedPlayer()}}
    }
}
