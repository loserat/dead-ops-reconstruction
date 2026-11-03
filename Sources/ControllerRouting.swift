import Foundation

struct InputRouting:Equatable {
    let count:Int,keyboardPlayer:Bool
    init(count:Int=1,keyboardPlayer:Bool=false){self.count=max(1,min(4,count));self.keyboardPlayer=keyboardPlayer}
}
struct InputDeviceStatus:Equatable {
    let token:String?,name:String,connected:Bool
    static let missing=InputDeviceStatus(token:nil,name:"Nicht verbunden",connected:false)
}
struct PadButtons:OptionSet {
    let rawValue:Int
    static let dash=Self(rawValue:1),bomb=Self(rawValue:2),accept=Self(rawValue:4),pause=Self(rawValue:8),back=Self(rawValue:16)
}
struct PadSample {
    var move=V2.zero,aim=V2.zero,dpad=V2.zero,buttons:PadButtons=[]
}
/// Per-connection button edges. A held button on a newly attached pad is not a fresh press.
struct PadPulseState {
    private var previous:PadButtons?,navX=0,navY=0,navNext=0.0
    mutating func sample(_ raw:PadSample,at time:Double)->Controls {
        let now=time.isFinite ? time:0
        var result=Controls(move:raw.move.length>0.15 ? raw.move:.zero,aim:raw.aim.length>0.18 ? raw.aim:.zero)
        let px=abs(raw.dpad.x)>0.5 ? raw.dpad.x:raw.move.x,py=abs(raw.dpad.y)>0.5 ? raw.dpad.y:raw.move.y
        let mx=abs(px)>0.6 ? (px>0 ? 1:-1):0,my=abs(py)>0.6 ? (py>0 ? 1:-1):0
        guard let old=previous else{previous=raw.buttons;navX=mx;navY=my;navNext=now+0.34;return result}
        let pressed=raw.buttons.subtracting(old);previous=raw.buttons
        result.dash=pressed.contains(.dash);result.bomb=pressed.contains(.bomb);result.accept=pressed.contains(.accept)
        result.pause=pressed.contains(.pause);result.back=pressed.contains(.back)
        if mx != navX || my != navY {result.menuX=mx;result.menuY=my;navNext=now+0.34}
        else if (mx != 0 || my != 0) && now>=navNext {result.menuX=mx;result.menuY=my;navNext=now+0.16}
        navX=mx;navY=my
        return result
    }
}
enum InputMenu {
    static func merge(_ players:[Controls],operatorControls:Controls=Controls(),count:Int=4)->Controls {
        let inputs=Array(players.prefix(max(1,min(4,count))))
        var result=inputs.first ?? Controls()
        for value in Array(inputs.dropFirst())+[operatorControls] {
            result.accept = result.accept || value.accept;result.pause = result.pause || value.pause
            result.back = result.back || value.back;result.openSettings = result.openSettings || value.openSettings
            result.systemPause = result.systemPause || value.systemPause
            if result.menuX==0 {result.menuX=value.menuX};if result.menuY==0 {result.menuY=value.menuY}
            if result.menuRow==nil {result.menuRow=value.menuRow}
            if result.menuPoint==nil {result.menuPoint=value.menuPoint}
        }
        return result
    }
}
/// Opaque tokens represent native connection objects, never vendor names.
/// Connected slots never reorder. A replacement token fills a missing slot.
struct ControllerRoster {
    private(set) var routing=InputRouting(),bindings:[String?]=[nil]
    private var previousConnected=Set<String>()
    mutating func update(_ routing:InputRouting,controllers:[String])->[Int] {
        let ids=controllers.reduce(into:[String]()) {if !$0.contains($1){$0.append($1)}}
        let connected=Set(ids),changed=self.routing != routing
        let priorFirst=self.routing.keyboardPlayer && self.routing.count>1 ? 1:0
        let first=routing.keyboardPlayer && routing.count>1 ? 1:0
        if priorFirst != first {bindings=Array(repeating:nil,count:routing.count)}
        else {
            if bindings.count>routing.count {bindings.removeLast(bindings.count-routing.count)}
            while bindings.count<routing.count {bindings.append(nil)}
        }
        self.routing=routing
        if first==1 {bindings[0]=nil}
        let lost=(first..<routing.count).filter{slot in
            bindings[slot].map{previousConnected.contains($0) && !connected.contains($0)} ?? false
        }
        let assigned=Set(bindings.compactMap{$0})
        var incoming=ids.filter{!assigned.contains($0)}
        for slot in first..<routing.count where bindings[slot]==nil {
            if !incoming.isEmpty {bindings[slot]=incoming.removeFirst()}
        }
        for slot in first..<routing.count {
            if let id=bindings[slot],!connected.contains(id),let i=incoming.firstIndex(where:{!previousConnected.contains($0)}) {
                bindings[slot]=incoming.remove(at:i)
            }
        }
        previousConnected=connected
        return changed ? []:lost
    }
}
