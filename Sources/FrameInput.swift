import Foundation

struct FrameInputSnapshot {
    var players:[Controls],devices:[InputDeviceStatus],size:CGSize,availableControllers:Int,operatorControls:Controls
    var controls:Controls {players.first ?? Controls()}
}
/// Native input objects stay on their thread; rendering receives complete value snapshots.
final class FrameInputMailbox {
    private let lock=NSLock()
    private var pending=[Controls()],devices=[InputDeviceStatus.missing],size=CGSize(width:1280,height:720)
    private var requested=InputRouting()
    private var availableControllers=0
    private var pendingOperator=Controls()
    func configure(_ routing:InputRouting){lock.lock();requested=routing;lock.unlock()}
    func routing()->InputRouting {lock.lock();defer{lock.unlock()};return requested}
    func publish(_ input:Controls,size:CGSize) {publish(players:[input],devices:[],size:size)}
    func publish(players:[Controls],devices supplied:[InputDeviceStatus],size:CGSize,availableControllers:Int=0,operatorControls:Controls=Controls()) {
        lock.lock();defer{lock.unlock()}
        let count=max(1,min(4,players.count))
        self.availableControllers=max(0,min(4,availableControllers))
        pendingOperator.accept = pendingOperator.accept || operatorControls.accept
        pendingOperator.pause = pendingOperator.pause || operatorControls.pause
        pendingOperator.back = pendingOperator.back || operatorControls.back
        pendingOperator.openSettings = pendingOperator.openSettings || operatorControls.openSettings
        pendingOperator.systemPause = pendingOperator.systemPause || operatorControls.systemPause
        if operatorControls.menuX != 0 {pendingOperator.menuX=operatorControls.menuX}
        if operatorControls.menuY != 0 {pendingOperator.menuY=operatorControls.menuY}
        if let row=operatorControls.menuRow {pendingOperator.menuRow=row}
        if let point=operatorControls.menuPoint {pendingOperator.menuPoint=point}
        if pending.count>count {pending.removeLast(pending.count-count);devices.removeLast(devices.count-count)}
        while pending.count<count {pending.append(Controls());devices.append(.missing)}
        for slot in 0..<count {
            let device=slot<supplied.count ? supplied[slot]:.missing
            let sample=slot<players.count ? players[slot]:Controls()
            let input=slot<supplied.count && !device.connected ? Controls(systemPause:sample.systemPause):sample
            if devices[slot].token != device.token {pending[slot]=Controls()}
            if devices[slot].connected && !device.connected {pending[slot]=Controls(systemPause:true)}
            devices[slot]=device
            pending[slot].move=input.move;pending[slot].aim=input.aim
            pending[slot].dash = pending[slot].dash || input.dash;pending[slot].bomb = pending[slot].bomb || input.bomb
            pending[slot].accept = pending[slot].accept || input.accept;pending[slot].pause = pending[slot].pause || input.pause
            pending[slot].back = pending[slot].back || input.back;pending[slot].openSettings = pending[slot].openSettings || input.openSettings
            pending[slot].systemPause = pending[slot].systemPause || input.systemPause
            if input.menuX != 0 {pending[slot].menuX=input.menuX};if input.menuY != 0 {pending[slot].menuY=input.menuY}
            if let row=input.menuRow {pending[slot].menuRow=row}
            if let point=input.menuPoint {pending[slot].menuPoint=point}
        }
        self.size=CGSize(width:size.width.isFinite ? max(1,size.width):1,height:size.height.isFinite ? max(1,size.height):1)
    }
    func take()->FrameInputSnapshot {
        lock.lock();defer{lock.unlock()}
        let frame=FrameInputSnapshot(players:pending,devices:devices,size:size,availableControllers:availableControllers,operatorControls:pendingOperator)
        pending=pending.map{Controls(move:$0.move,aim:$0.aim)}
        pendingOperator=Controls()
        return frame
    }
}
