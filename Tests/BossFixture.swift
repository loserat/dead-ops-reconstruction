import Foundation

extension GameCore {
    /// Explicit post-introduction fixture for isolated body/weapon/reward tests.
    /// It creates all requested brothers without pretending to exercise source timing.
    /// Normal pilots and BossWorldChecks never call this helper.
    func fixtureSilverbacks() {
        beginSilverbackEncounter()
        guard var intro=bossArrivalClock else{return}
        _=intro.step(max(0,intro.battleStartsAt-intro.clock));bossArrivalClock=intro
        while silverbacks.count<bossCount {admitSilverbackBrother(silverbacks.count)}
        bossFrameBirths=[:];finishCombatSpawning()
    }
}

extension GameCore {
    /// Isolated fixture preparation: finish actual source child programs without moving/collecting.
    /// Live-entry timing has separate LootRoomChecks and native renderer coverage.
    func finishRoomLootForChecks() {
        guard phase == .bonusRoom,let director=sourceLoot else{fatalError("room fixture requires a real source room")}
        let end=director.clock+30
        while director.pendingChildren>0 && director.clock<end {stepWorldLoot(1.0/60)}
        precondition(director.pendingChildren==0,"source room fixture did not finish")
    }
}
