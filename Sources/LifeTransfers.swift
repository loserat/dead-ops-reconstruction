import Foundation

/// Read script waits. World dimensions and simultaneous callback ordering remain our own mapping.
enum RecoveryRules {
    static let automatic=60.0,reserveWait=2.0,donorCooldown=10.0,recipientCooldown=65.0
    static let searchInterval=1.0,creditInterval=0.2,linkWait=1.0,flight=1.0
    static let rewardAttempt=0.05,rewardSpacing=0.3,shortShield=3.05,fullShield=8.65
    static let dropFall=1.3,dropHeight=8.0,pickupDelay=0.4,pickupRadius=0.8,pickupHeight=0.65
}
enum LifeDonationReward:Int,CaseIterable {
    // The archive's table order matters for deterministic random probes.
    case bombs,helicopter,tank,boosts
    var kind:PickupKind {switch self {case .bombs:return .bomb;case .helicopter:return .helicopter;case .tank:return .tank;case .boosts:return .dash}}
    var count:Int {self == .bombs ? 3:self == .boosts ? 4:1}
    static func choose(_ roll:Double)->Self {
        guard roll.isFinite else{return .bombs}
        return allCases[max(0,min(3,Int(max(0,min(1,roll))*4)))]
    }
}
enum LifeTransferStage {case linking,flying,choosingReward,issuingReward,finishing}
struct LifeTransfer {
    let id:Int,donor:Int,recipient:Int
    var stage:LifeTransferStage = .linking,remaining=RecoveryRules.linkWait
    var clock=0.0
    var origin=V2.zero,target=V2.zero,originElevation=0.0,targetElevation=0.0
    var reward:LifeDonationReward?,rewardsRemaining=0
    var flightProgress:Double {stage == .flying ? max(0,min(1,1-remaining/RecoveryRules.flight)):0}
}
/// Own separate arena/room identities stand in for the original single large world.
struct RewardMap:Equatable {let arena:ArenaKind,room:SideRoomKind?}
struct DirectedLifeReward {
    let id:Int,targetSlot:Int,kind:PickupKind
    var map:RewardMap,p:V2,elevation:Double,fallClock=0.0,landed=false
    var personalLife=false
}
struct DirectedRewardBundle {let reward:DirectedLifeReward;var count=1}
private struct DirectedRewardKey:Hashable {
    let kind:Int,x:Double,y:Double,elevation:Double,fallingID:Int?
    let personalLife:Bool
}
extension GameCore {
    var rewardMap:RewardMap {RewardMap(arena:layout.kind,room:sideRoom?.kind)}
    var visibleDirectedRewards:[DirectedLifeReward] {directedLifeRewards.filter{$0.map==rewardMap}}
    /// Identical landed objects share one rendered silhouette. Logical triggers remain separate.
    var visibleRewardBundles:[DirectedRewardBundle] {
        var indices=[DirectedRewardKey:Int](),bundles=[DirectedRewardBundle]()
        for reward in visibleDirectedRewards {
            let key=DirectedRewardKey(kind:reward.kind.rawValue,x:reward.p.x,y:reward.p.y,elevation:reward.elevation,fallingID:reward.landed ? nil:reward.id,personalLife:reward.personalLife)
            if let index=indices[key] {bundles[index].count+=1}
            else {indices[key]=bundles.count;bundles.append(DirectedRewardBundle(reward:reward))}
        }
        return bundles
    }
    var recoveryCameraPlayers:[RunPlayer] {
        let visible=players.filter{!$0.isDown || $0.respawnRemaining != nil || $0.sponsoredRespawn || incomingTransfer(to:$0.slot) != nil}
        return visible.isEmpty ? players:visible
    }
    func incomingTransfer(to slot:Int)->LifeTransfer? {lifeTransfers.first{$0.recipient==slot && ($0.stage == .linking || $0.stage == .flying)}}
    /// Selection uses the richest other role, including a funded downed body, with first-slot ties.
    @discardableResult
    func tryDonateLife(to slot:Int)->Bool {
        guard phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .transition,
              playerCount>1,players.indices.contains(slot) else{return false}
        let recipient=players[slot]
        guard recipient.isDown,recipient.lives==0,!recipient.sponsoredRespawn,recipient.respawnRemaining==nil,
              incomingTransfer(to:slot)==nil,
              let donor=players.filter({$0.slot != slot && $0.lives>0}).max(by:{a,b in a.lives==b.lives ? a.slot>b.slot:a.lives<b.lives}),
              donor.donationCooldown<=0,recipient.donationCooldown<=0 else{return false}
        donor.donationCooldown=RecoveryRules.donorCooldown;recipient.donationCooldown=RecoveryRules.recipientCooldown
        recipient.donationSearchActive=false
        lifeTransfers.append(LifeTransfer(id:id(),donor:donor.slot,recipient:slot))
        announce("LEBENSGABE · SPIELER \(donor.slot+1) → \(slot+1)")
        return true
    }
    func donationRewardAllowed(_ reward:LifeDonationReward)->Bool {
        guard reward == .tank || reward == .helicopter else{return true}
        let inNewCombat=phase == .playing || (phase == .transition && arenaTransit?.committed==true && arenaTransit?.resumePhase == .playing)
        let rewardRound=inNewCombat ? round:round==Int.max ? round:round+1
        guard rewardRound >= (reward == .tank ? 4:9) else{return false}
        if reward == .helicopter,layout.kind == .prison,(sideRoom?.kind != nil || phase != .playing) {return false}
        let exclusive:Set<PickupKind>=[.tank,.helicopter,.orb,.barrelShield,.teddy]
        return !players.contains{$0.vehicle != nil || !$0.orbShields.isEmpty || !$0.shieldBarrels.isEmpty || $0.teddyRemaining>0}
            && !pickups.contains{exclusive.contains($0.kind)}
    }
    func makeDirectedReward(for slot:Int,kind:PickupKind,personalLife:Bool=false) {
        guard players.indices.contains(slot) else{return}
        let p=players[slot]
        directedLifeRewards.append(DirectedLifeReward(id:id(),targetSlot:slot,kind:kind,map:rewardMap,p:p.hero,elevation:p.heroElevation+RecoveryRules.dropHeight,personalLife:personalLife))
    }
    /// A compensation bundle is a set of physical drops; each object still needs a live collector.
    func grantDonationReward(_ reward:LifeDonationReward) {
        for _ in 0..<reward.count {makeDirectedReward(for:activePlayerSlot,kind:reward.kind)}
    }
    func resolveLifeTransferDeadlines() {
        var finished=Set<Int>()
        for index in lifeTransfers.indices {
            var transfer=lifeTransfers[index]
            guard transfer.remaining<=0.000000001 else{continue}
            guard players.indices.contains(transfer.donor),players.indices.contains(transfer.recipient) else{finished.insert(transfer.id);continue}
            let donor=players[transfer.donor],recipient=players[transfer.recipient]
            switch transfer.stage {
            case .linking:
                // The old callback can race a donor's own return. Never manufacture a reserve on that tie.
                guard donor.lives>0 else{finished.insert(transfer.id);continue}
                donor.lives-=1;donor.donationsGiven+=1;withPlayer(donor.slot){beginBodyShield(short:true)}
                transfer.origin=donor.hero;transfer.originElevation=donor.heroElevation
                transfer.target=recipient.hero;transfer.targetElevation=recipient.heroElevation
                transfer.stage = .flying;transfer.remaining=RecoveryRules.flight
            case .flying:
                recipient.sponsoredRespawn=true;recipient.donationsReceived+=1
                transfer.stage = .choosingReward;transfer.remaining=RecoveryRules.rewardAttempt
            case .choosingReward:
                let reward=LifeDonationReward.choose(random())
                if donationRewardAllowed(reward) {
                    transfer.reward=reward;transfer.rewardsRemaining=reward.count-1
                    makeDirectedReward(for:donor.slot,kind:reward.kind)
                    transfer.stage=transfer.rewardsRemaining>0 ? .issuingReward:.finishing
                    transfer.remaining=RecoveryRules.rewardSpacing
                }else{transfer.remaining=RecoveryRules.rewardAttempt}
            case .issuingReward:
                if let reward=transfer.reward {makeDirectedReward(for:donor.slot,kind:reward.kind)}
                transfer.rewardsRemaining-=1
                if transfer.rewardsRemaining<=0 {transfer.stage = .finishing}
                transfer.remaining=RecoveryRules.rewardSpacing
            case .finishing:finished.insert(transfer.id)
            }
            lifeTransfers[index]=transfer
        }
        lifeTransfers.removeAll{finished.contains($0.id)}
    }
    func advanceDirectedRewards(_ dt:Double) {
        for i in directedLifeRewards.indices where !directedLifeRewards[i].landed {
            directedLifeRewards[i].fallClock+=dt
        }
        syncDirectedRewardPositions()
    }
    func syncDirectedRewardPositions() {
        for i in directedLifeRewards.indices where !directedLifeRewards[i].landed && players.indices.contains(directedLifeRewards[i].targetSlot) {
            let target=players[directedLifeRewards[i].targetSlot],clock=directedLifeRewards[i].fallClock
            directedLifeRewards[i].p=target.hero;directedLifeRewards[i].map=rewardMap
            directedLifeRewards[i].elevation=target.heroElevation+RecoveryRules.dropHeight*max(0,1-clock/RecoveryRules.dropFall)
            directedLifeRewards[i].landed=clock>=RecoveryRules.dropFall
        }
    }
    func collectDirectedRewards() {
        syncDirectedRewardPositions()
        var collected=Set<Int>()
        for player in livingPlayers {
            for reward in directedLifeRewards where !collected.contains(reward.id) && reward.map==rewardMap && reward.fallClock>=RecoveryRules.pickupDelay {
                guard (reward.p-player.hero).length<RecoveryRules.pickupRadius,
                      abs(reward.elevation-player.heroElevation)<RecoveryRules.pickupHeight else{continue}
                collected.insert(reward.id)
                withPlayer(player.slot){
                    if reward.personalLife {grantExtraLife();emitAudio(.life);announce("EXTRA-LEBEN")}
                    else {apply(reward.kind,at:reward.p)}
                }
            }
        }
        directedLifeRewards.removeAll{collected.contains($0.id)}
    }
}
