import Foundation

/// Archived _zombietron/_score/_pickups behavior, not authenticated engine code.
enum ScoreRules {
    static let extraLifeInterval=200_000,ordinaryKill=100,bossKill=30_000
}
extension GameCore {
    func award(_ amount:Int) {
        score+=amount
        // One transaction processes one threshold, even when a large award crosses more.
        // The reward is a physical personal statue, not an immediate or team-wide life.
        if score>=nextLifeAt {
            nextLifeAt+=ScoreRules.extraLifeInterval
            makeDirectedReward(for:activePlayerSlot,kind:.life,personalLife:true)
            announce("LEBENSSTATUE IM ANFLUG")
        }
    }
    func scoreLifeStatus(for slot:Int)->String? {
        let rewards=visibleDirectedRewards.filter{$0.personalLife && $0.targetSlot==slot}
        guard !rewards.isEmpty else{return nil}
        return rewards.contains{!$0.landed} ? "LEBENSSTATUE IM ANFLUG":"LEBENSSTATUE BEREIT"
    }
}
