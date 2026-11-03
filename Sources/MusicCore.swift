import Foundation
struct MusicTrack:Equatable {let url:URL,title:String}
struct MusicRequest:Equatable {
    var enabled:Bool,gain:Double,active:Bool,returning:Bool,arena:Int
    init(settings:GameSettings,phase:RunPhase,round:Int){
        enabled=settings.soundEnabled;gain=Double(settings.musicVolume)/100
        active=phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .loopReturn || phase == .transition
        returning=phase == .loopReturn;arena=max(0,round-1)/4
    }
}
struct MusicDisplay {var title="Keine Musik geladen",count=0;var notice=""}
/// Independent of decoding/output, to verify selection and pause policy without making sound.
struct MusicTransport {
    private(set) var index=0,arena:Int?,count=0
    mutating func replace(count:Int){self.count=max(0,count);index=min(index,max(0,count-1))}
    mutating func update(arena:Int){if let old=self.arena,old != arena,count>0 {index=(index+1)%count};self.arena=arena}
    mutating func select(_ delta:Int){guard count>0 else{return};index=(index+(delta<0 ? count-1:1))%count}
    func shouldPlay(_ request:MusicRequest)->Bool {count>0 && request.enabled && request.gain>0 && request.active}
}
