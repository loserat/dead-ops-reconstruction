import Foundation
import GameController

struct NativeInputSnapshot {
    var players:[Controls],devices:[InputDeviceStatus],availableControllers:Int,operatorControls:Controls
}
/// Main-thread adapter only. Neither game state nor SceneKit nodes are read here.
final class InputState {
    var keys:Set<UInt16>=[]
    var pendingAccept=false,pendingPause=false,pendingDash=false,pendingBomb=false,pendingSettings=false,pendingSystemPause=false
    var pendingMenuRow:Int?
    var pendingMenuPoint:V2?
    private var navX=0,navY=0,navNext=0.0
    private var roster=ControllerRoster(),tokens:[ObjectIdentifier:String]=[:],pulses:[String:PadPulseState]=[:]
    private var retained:[ObjectIdentifier:GCController]=[:]
    var controllerName="Controller verbinden"
    func menuArrow(_ key:UInt16) {
        pendingMenuRow=nil
        if key==123 || key==124 {navX=0}else{navY=0}
        keys.insert(key)
    }
    func sample()->Controls {samplePlayers(routing:InputRouting()).players[0]}
    func samplePlayers(routing:InputRouting)->NativeInputSnapshot {
        assert(Thread.isMainThread)
        let now=ProcessInfo.processInfo.systemUptime
        let controllers=GCController.controllers().filter{$0.extendedGamepad != nil}
        let present=Set(controllers.map(ObjectIdentifier.init))
        tokens=tokens.filter{present.contains($0.key)}
        retained=retained.filter{present.contains($0.key)}
        var values:[String:Controls]=[:],names:[String:String]=[:],ids=[String]()
        for controller in controllers {
            let key=ObjectIdentifier(controller)
            retained[key]=controller
            if tokens[key]==nil {tokens[key]=UUID().uuidString}
            let id=tokens[key]!
            guard let pad=controller.extendedGamepad else{continue}
            var buttons:PadButtons=[]
            if pad.rightTrigger.isPressed || pad.rightShoulder.isPressed {buttons.insert(.dash)}
            if pad.leftTrigger.isPressed || pad.leftShoulder.isPressed {buttons.insert(.bomb)}
            if pad.buttonA.isPressed {buttons.insert(.accept)}
            if pad.buttonB.isPressed {buttons.insert(.back)}
            if pad.buttonMenu.isPressed {buttons.insert(.pause)}
            let raw=PadSample(move:V2(x:Double(pad.leftThumbstick.xAxis.value),y:-Double(pad.leftThumbstick.yAxis.value)),
                              aim:V2(x:Double(pad.rightThumbstick.xAxis.value),y:-Double(pad.rightThumbstick.yAxis.value)),
                              dpad:V2(x:Double(pad.dpad.xAxis.value),y:-Double(pad.dpad.yAxis.value)),buttons:buttons)
            var state=pulses[id] ?? PadPulseState();values[id]=state.sample(raw,at:now);pulses[id]=state
            names[id]=controller.vendorName ?? "Controller";ids.append(id)
        }
        pulses=pulses.filter{values[$0.key] != nil}
        let lost=roster.update(routing,controllers:ids)
        var keyboard=sampleKeyboard(at:now)
        let operatorControls=Controls(accept:keyboard.accept,pause:keyboard.pause,back:keyboard.back,openSettings:keyboard.openSettings,systemPause:keyboard.systemPause,menuX:keyboard.menuX,menuY:keyboard.menuY,menuRow:keyboard.menuRow,menuPoint:keyboard.menuPoint)
        var players=Array(repeating:Controls(),count:routing.count),devices=Array(repeating:InputDeviceStatus.missing,count:routing.count)
        for slot in 0..<routing.count {
            if let token=roster.bindings[slot],let value=values[token] {
                players[slot]=value;devices[slot]=InputDeviceStatus(token:token,name:names[token] ?? "Controller",connected:true)
            }else if let token=roster.bindings[slot] {
                devices[slot]=InputDeviceStatus(token:token,name:"Controller fehlt",connected:false)
            }
        }
        #if os(macOS)
        if routing.count==1 || routing.keyboardPlayer {
            let pad=players[0]
            if pad.move.length>0 {keyboard.move=pad.move};if pad.aim.length>0 {keyboard.aim=pad.aim}
            mergeActions(pad,into:&keyboard)
            players[0]=keyboard
            if routing.keyboardPlayer && routing.count>1 || !devices[0].connected {devices[0]=InputDeviceStatus(token:"keyboard",name:"Tastatur · WASD / Pfeile",connected:true)}
        }
        #endif
        for slot in lost {players[slot].systemPause=true}
        controllerName=devices[0].name
        return NativeInputSnapshot(players:players,devices:devices,availableControllers:ids.count,operatorControls:operatorControls)
    }
    private func mergeActions(_ source:Controls,into target:inout Controls) {
        target.dash = target.dash || source.dash;target.bomb = target.bomb || source.bomb
        target.accept = target.accept || source.accept;target.pause = target.pause || source.pause
        target.back = target.back || source.back;target.openSettings = target.openSettings || source.openSettings
        target.systemPause = target.systemPause || source.systemPause
        if source.menuX != 0 {target.menuX=source.menuX};if source.menuY != 0 {target.menuY=source.menuY}
        if let row=source.menuRow {target.menuRow=row}
        if let point=source.menuPoint {target.menuPoint=point}
    }
    private func sampleKeyboard(at now:Double)->Controls {
        var c=Controls()
        c.move=V2(x:(keys.contains(2) ? 1:0)-(keys.contains(0) ? 1:0),y:(keys.contains(1) ? 1:0)-(keys.contains(13) ? 1:0))
        c.aim=V2(x:(keys.contains(124) ? 1:0)-(keys.contains(123) ? 1:0),y:(keys.contains(125) ? 1:0)-(keys.contains(126) ? 1:0))
        let mx=(keys.contains(124) ? 1:0)-(keys.contains(123) ? 1:0)
        let my=(keys.contains(125) || keys.contains(1) ? 1:0)-(keys.contains(126) || keys.contains(13) ? 1:0)
        if mx != navX || my != navY {c.menuX=mx;c.menuY=my;navNext=now+0.34}
        else if (mx != 0 || my != 0) && now>=navNext {c.menuX=mx;c.menuY=my;navNext=now+0.16}
        navX=mx;navY=my
        c.menuRow=pendingMenuRow;pendingMenuRow=nil
        c.menuPoint=pendingMenuPoint;pendingMenuPoint=nil
        c.openSettings=pendingSettings;c.systemPause=pendingSystemPause;pendingSettings=false;pendingSystemPause=false
        c.accept=pendingAccept;c.pause=pendingPause;c.dash=pendingDash;c.bomb=pendingBomb
        pendingAccept=false;pendingPause=false;pendingDash=false;pendingBomb=false
        return c
    }
}
