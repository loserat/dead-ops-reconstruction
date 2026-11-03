import Foundation

/// Archived ordinary-zombie script: wait .4, damage120, repeat for8 seconds.
/// The engine weapon's initial gas damage is unavailable; this projects ONLY the afterburn.
struct FlameAfterburn {
    static let interval=0.4,rawTickDamage=120.0,duration=8.0,maximumTicks=20
    static let playbackRate=0.65
    let tickDamage:Double
    private(set) var age=0.0,ticks=0,lastClock:Double
    var remaining:Double {ticks>=Self.maximumTicks ? 0:max(0,Self.duration-age)}
    init(vitality:ReferenceVitality,clock:Double) {
        let amount=Self.rawTickDamage*vitality.damageScale
        tickDamage=amount.isFinite && amount>=0 ? amount:0
        lastClock=clock.isFinite ? clock:0
    }
    /// Clock gates newly ignited bodies: the frame which created a burn cannot age it by a full dt.
    /// Frozen menu/transition time is never caught up as a burst of damage on resume.
    mutating func advance(_ dt:Double,at clock:Double?=nil)->Int {
        guard dt.isFinite,dt>=0 else{return 0}
        let end=clock ?? lastClock+dt
        guard end.isFinite else{return 0}
        let used=min(dt,max(0,end-lastClock));lastClock=max(lastClock,end)
        age=min(Self.duration,age+used)
        let due=min(Self.maximumTicks,Int(floor((age+1e-9)/Self.interval)))
        let count=max(0,due-ticks);ticks=due
        if ticks==Self.maximumTicks {age=Self.duration}
        return count
    }
}
extension GameCore {
    func igniteFlameTarget(_ index:Int) {
        if foes[index].kind == .hound {
            // The dog uses a separate native archetype/handler not present in this archive.
            // Retain its explicit old approximation until that behavior can be established.
            foes[index].burning=max(foes[index].burning,2.5);foes[index].burningOwner=activePlayerSlot
            return
        }
        // is_on_fire guards start_burning in the script: another gas hit never restarts its thread.
        guard foes[index].flameAfterburn==nil else{return}
        if foes[index].referenceVitality==nil {
            let f=foes[index]
            foes[index].referenceVitality=ReferenceVitality.foe(f.kind,round:round,mini:false,localMaximum:max(f.hp,RoundRules.health(f.kind,round:round)))
        }
        foes[index].flameAfterburn=FlameAfterburn(vitality:foes[index].referenceVitality!,clock:elapsed)
        foes[index].burning=FlameAfterburn.duration;foes[index].burningOwner=activePlayerSlot
    }
}
