import Foundation

/// Own timing for the BO1-described pedestal/treasure raid, not extracted original animation data.
struct GameOverSequence {
    static let duration=6.4
    private(set) var clock=0.0
    private(set) var suspended=false
    var finished:Bool {clock>=Self.duration}
    var landing:Double {Self.progress(clock,1.2,2.4)}
    var strike:Double {Self.progress(clock,3.2,3.65)}
    var departure:Double {Self.progress(clock,4.8,6.4)}
    var gathering:Double {Self.progress(clock,3.65,4.8)}
    var heroFlight:Double {Self.progress(clock,3.4,4.4)}
    var visitorHeight:Double {clock<2.4 ? 9*(1-landing):departure*departure*12}
    var caption:String {
        if suspended {return "ANGEHALTEN"}
        if clock<1.2 {return "DEIN SCHATZ …"}
        if clock<3.2 {return "DER SILVERBACK IST ZURÜCK"}
        return "… GEHÖRT JETZT DEM SILVERBACK"
    }
    mutating func step(_ dt:Double,input:Controls) {
        guard !finished else{return}
        if input.systemPause {suspended=true;return}
        if suspended {
            if input.accept || input.pause || input.back {suspended=false}
            return
        }
        if input.accept || input.pause || input.back {clock=Self.duration;return}
        if dt.isFinite && dt>0 {clock=min(Self.duration,clock+dt)}
    }
    private static func progress(_ time:Double,_ start:Double,_ end:Double)->Double {
        max(0,min(1,(time-start)/(end-start)))
    }
}
