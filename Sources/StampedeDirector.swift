import Foundation

struct StampedeBirth:Equatable {
    let clock:Double,side:EntrySide,golden:Bool,spawnRoll:Double,destinationRoll:Double
    var activationDelay:Double {golden ? 0.1:0}
}
/// Archived buffalo/challenge waits; map coordinates and VM RNG order remain local.
struct StampedeDirector {
    enum Mode {case normal,challenge}
    private enum Event {case initialize,chooseSide,spawn,nextBurst}
    let mode:Mode
    private(set) var clock=0.0,nextAt=10.0,active=true
    private(set) var bursts=0,births=0,remaining=0
    private(set) var side:EntrySide?,previousSide:EntrySide?,earlierSide:EntrySide?
    private var event:Event = .initialize
    init(mode:Mode) {self.mode=mode}
    var wait:Double {max(0,nextAt-clock)}
    mutating func setWait(_ value:Double) {if value.isFinite {nextAt=clock+max(0,value)}}
    mutating func stop(){active=false;remaining=0}
    private static func roll(_ random:()->Double)->Double {max(0,min(1.0.nextDown,random()))}
    private static func choose(_ random:()->Double)->EntrySide {[.north,.south,.west,.east][Int(roll(random)*4)]}
    mutating func step(_ dt:Double,openSides:Set<EntrySide>=[],random:()->Double)->[StampedeBirth] {
        guard dt.isFinite,dt>=0,dt<=3600,clock+dt<1e12 else{return []}
        let target=clock+dt
        guard active else{clock=target;return []}
        var emitted=[StampedeBirth]()
        while nextAt<=target+1e-9 {
            clock=nextAt
            switch event {
            case .initialize:
                if mode == .challenge {previousSide=Self.choose(random);earlierSide=previousSide}
                event = .chooseSide
            case .chooseSide:
                let selected=Self.choose(random)
                if (mode == .challenge && (selected==previousSide || selected==earlierSide)) || (mode == .normal && openSides.contains(selected)) {nextAt+=0.05;continue}
                earlierSide=previousSide;previousSide=selected;side=selected;bursts+=1
                remaining=(mode == .challenge ? 5:2)+Int(Self.roll(random)*Double(mode == .challenge ? 5:4))
                event = .spawn
            case .spawn:
                let start=Self.roll(random),end=Self.roll(random),golden=Int(Self.roll(random)*100)<5
                emitted.append(StampedeBirth(clock:clock,side:side!,golden:golden,spawnRoll:start,destinationRoll:end));births+=1;remaining-=1
                // Sacred cows wait one local network frame before their trigger, move and child wait.
                nextAt+=(golden ? 0.1:0)+1+1.5*Self.roll(random)
                event=remaining>0 ? .spawn:.nextBurst
            case .nextBurst:
                nextAt+=Double(mode == .challenge ? 1:10)+floor(Self.roll(random)*Double(mode == .challenge ? 2:20))
                event = .chooseSide
            }
        }
        clock=target;return emitted
    }
}
