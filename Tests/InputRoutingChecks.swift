import Foundation
import CoreGraphics
@main struct InputRoutingChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ test:Bool,_ message:String){guard test else{fatalError(message)};passed+=1;print("PASS \(message)")}
  let two=InputRouting(count:2),four=InputRouting(count:4)
  var roster=ControllerRoster()
  expect(roster.update(two,controllers:["A","B"]).isEmpty && roster.bindings==["A","B"],"two controllers get separate initial slots")
  roster.update(two,controllers:["B","A"])
  expect(roster.bindings==["A","B"],"native enumeration order cannot swap connected player roles")
  expect(roster.update(two,controllers:["B"])==[0] && roster.bindings==["A","B"],"disconnect reports the lost slot and keeps the surviving controller in its role")
  expect(roster.update(two,controllers:["B"]).isEmpty,"a missing connection emits its loss only once")
  roster.update(two,controllers:["B","A"])
  expect(roster.bindings==["A","B"],"a retained connection token returns to its reserved slot")
  roster.update(two,controllers:["B"]);roster.update(two,controllers:["B","A-new"])
  expect(roster.bindings==["A-new","B"],"a replacement connection fills the missing slot without moving a survivor")
  roster.update(four,controllers:["B","A-new","C","D"])
  expect(roster.bindings==["A-new","B","C","D"],"adding player slots preserves existing connected assignments")
  roster.update(two,controllers:["D","C","B","A-new"])
  expect(roster.bindings==["A-new","B"],"reducing the roster does not promote a spare pad over a connected player")
  roster.update(two,controllers:["B","C","D"])
  expect(roster.bindings==["A-new","B"],"an already connected unused pad cannot silently take a disconnected player's role")
  let keyboard=InputRouting(count:3,keyboardPlayer:true);roster.update(keyboard,controllers:["B","C","C","D"])
  expect(roster.bindings==[nil,"B","C"],"keyboard mode reserves player one and duplicate device entries cannot fill two roles")
  expect(InputRouting(count:999).count==4 && InputRouting(count:0).count==1,"routing remains bounded to one through four players")
  var edge=PadPulseState()
  let all:PadButtons=[.dash,.bomb,.accept,.pause,.back]
  let held=PadSample(move:V2(x:1,y:0),aim:V2(x:0,y:1),buttons:all)
  let first=edge.sample(held,at:0)
  expect(!first.dash && !first.bomb && !first.accept && !first.pause && !first.back && first.move.x==1 && first.aim.y==1,"attaching a pad with held buttons preserves analog position without inventing button presses")
  let repeatHold=edge.sample(held,at:0.1)
  expect(!repeatHold.bomb && !repeatHold.accept && repeatHold.menuX==0,"holding attached buttons cannot repeat gameplay actions or immediately scroll")
  _=edge.sample(PadSample(),at:0.2);let press=edge.sample(PadSample(buttons:all),at:0.3)
  expect(press.dash && press.bomb && press.accept && press.pause && press.back,"release followed by press creates each independent button edge once")
  let noRepeat=edge.sample(PadSample(buttons:all),at:0.31)
  expect(!noRepeat.dash && !noRepeat.bomb && !noRepeat.accept && !noRepeat.pause && !noRepeat.back,"a held physical button does not become multiple one-shot events")
  var second=PadPulseState();_=second.sample(PadSample(),at:0)
  expect(second.sample(PadSample(buttons:.bomb),at:1).bomb && !edge.sample(PadSample(buttons:all),at:1).bomb,"one controller's press history cannot affect another controller")
  var nav=PadPulseState();_=nav.sample(PadSample(),at:0)
  let direction=PadSample(dpad:V2(x:0,y:1))
  expect(nav.sample(direction,at:0.01).menuY==1 && nav.sample(direction,at:0.2).menuY==0 && nav.sample(direction,at:0.36).menuY==1 && nav.sample(direction,at:0.4).menuY==0 && nav.sample(direction,at:0.53).menuY==1,"each pad has the original initial delay and bounded navigation-repeat cadence")
  let box=FrameInputMailbox()
  func device(_ id:String,_ connected:Bool=true)->InputDeviceStatus {InputDeviceStatus(token:id,name:"Identical PS5 name",connected:connected)}
  box.configure(four);expect(box.routing()==four,"renderer routing requests cross the same locked bridge as value data")
  box.publish(players:[Controls(move:V2(x:1,y:0),dash:true),Controls(aim:V2(x:0,y:1),bomb:true)],devices:[device("A"),device("B")],size:CGSize(width:1600,height:900))
  box.publish(players:[Controls(move:V2(x:0,y:1)),Controls(aim:V2(x:1,y:0))],devices:[device("A"),device("B")],size:CGSize(width:1280,height:720))
  let frame=box.take()
  expect(frame.players.count==2 && frame.players[0].dash && !frame.players[0].bomb && frame.players[1].bomb && !frame.players[1].dash,"each player's buffered one-shot events survive faster native sampling separately")
  expect(frame.players[0].move==V2(x:0,y:1) && frame.players[1].aim==V2(x:1,y:0) && frame.size==CGSize(width:1280,height:720),"the latest held movement, aim and viewport arrive as one full frame")
  expect(frame.devices.map(\.token)==["A","B"] && frame.devices.map(\.name)==["Identical PS5 name","Identical PS5 name"],"identical vendor names remain distinct by opaque connection token")
  let next=box.take()
  expect(!next.players[0].dash && !next.players[1].bomb && next.players[0].move==frame.players[0].move && next.players[1].aim==frame.players[1].aim,"taking a render frame consumes events once while retaining each held axis")
  box.publish(players:[Controls(bomb:true),Controls()],devices:[device("A"),device("B")],size:frame.size)
  box.publish(players:[Controls(),Controls()],devices:[device("A-new"),device("B")],size:frame.size)
  expect(!box.take().players[0].bomb,"a replacement controller cannot inherit an old connection's pending bomb")
  box.publish(players:[Controls(dash:true),Controls()],devices:[device("A-new"),device("B")],size:frame.size)
  box.publish(players:[Controls(move:V2(x:1,y:1),aim:V2(x:1,y:1),bomb:true,accept:true),Controls()],devices:[device("A-new",false),device("B")],size:frame.size)
  let loss=box.take()
  expect(loss.players[0].systemPause && !loss.players[0].dash && !loss.players[0].bomb && !loss.players[0].accept && loss.players[0].move == .zero && loss.players[0].aim == .zero,"disconnect clears stale actions and axes and publishes one system pause")
  expect(!box.take().players[0].systemPause,"the disconnect pause is itself consumed once")
  box.publish(players:[Controls(),Controls(bomb:true)],devices:[device("A-new"),device("B")],size:frame.size)
  box.publish(players:[Controls()],devices:[device("A-new")],size:frame.size)
  box.publish(players:[Controls(),Controls()],devices:[device("A-new"),device("C")],size:frame.size)
  expect(!box.take().players[1].bomb,"removing and readding a player slot cannot restore discarded buffered actions")
  box.publish(players:[],devices:[],size:CGSize(width:CGFloat.nan,height:0))
  expect(box.take().players.count==1 && box.take().size==CGSize(width:1,height:1),"empty input and invalid viewport data remain a safe neutral frame")
  box.publish(players:[Controls()],devices:[device("absent",false)],size:frame.size,availableControllers:4,operatorControls:Controls(accept:true,pause:true,openSettings:true,menuRow:1))
  let operatorFrame=box.take()
  expect(operatorFrame.availableControllers==4 && operatorFrame.operatorControls.accept && operatorFrame.operatorControls.pause && operatorFrame.operatorControls.menuRow==1 && !operatorFrame.players[0].accept,"keyboard and mouse can operate menus without impersonating an absent player's controller")
  expect(!box.take().operatorControls.accept && box.take().operatorControls.menuRow==nil,"operator menu events are consumed once independently of player inputs")
  let menu=InputMenu.merge([Controls(),Controls(bomb:true,accept:true,pause:true,menuY:1)],operatorControls:Controls(openSettings:true),count:2)
  expect(menu.accept && menu.pause && menu.menuY==1 && menu.openSettings && !menu.bomb,"teammate menu events combine without copying a teammate's bomb to player one")
  expect(!InputMenu.merge([Controls(),Controls(pause:true)],count:1).pause,"unconfigured controllers do not gain menu authority through the combiner")
  let ordered=InputMenu.merge([Controls(menuX:1),Controls(menuX:-1)],operatorControls:Controls(menuX:-1))
  expect(ordered.menuX==1,"conflicting simultaneous menu directions resolve once by stable player order")
  let actual=GameCore();actual.reset(playerCount:2);actual.foes=[];actual.pickups=[];actual.combatSpawningHeld=true
  for p in actual.players {p.invulnerable=999}
  let bridge=FrameInputMailbox()
  bridge.publish(players:[Controls(move:V2(x:-1,y:0)),Controls(move:V2(x:1,y:0))],devices:[device("A"),device("B")],size:frame.size)
  let startPositions=actual.players.map(\.hero);actual.step(0.1,inputs:bridge.take().players)
  expect(actual.players[0].hero.x<startPositions[0].x && actual.players[1].hero.x>startPositions[1].x && abs(actual.elapsed-0.1)<0.000001,"a full two-player mailbox packet drives the actual shared simulation once")
  let concurrent=FrameInputMailbox(),group=DispatchGroup(),queue=DispatchQueue(label:"input-routing-test",attributes:.concurrent)
  group.enter();queue.async {
   for n in 0..<4000 {
    let count=n%4+1
    let players=(0..<count).map{i in Controls(move:V2(x:Double(n),y:Double(i)),aim:V2(x:Double(count),y:Double(n)))}
    let devices=(0..<count).map{i in InputDeviceStatus(token:"\(n):\(i)",name:"\(n)",connected:true)}
    concurrent.configure(InputRouting(count:count,keyboardPlayer:count%2==0))
    concurrent.publish(players:players,devices:devices,size:CGSize(width:CGFloat(n+1),height:CGFloat(count)))
   };group.leave()
  }
  var torn=false
  for _ in 0..<4000 {
   let f=concurrent.take()
   guard f.devices.first?.token != nil else{continue}
   let n=f.players[0].move.x,count=f.players.count
   if f.devices.count != count || f.size != CGSize(width:CGFloat(n+1),height:CGFloat(count)) {torn=true}
   for i in f.players.indices {
    if f.players[i].move != V2(x:n,y:Double(i)) || f.players[i].aim != V2(x:Double(count),y:n) || f.devices[i].token != "\(Int(n)):\(i)" {torn=true}
   }
   let request=concurrent.routing();if request.count<1 || request.count>4 {torn=true}
  }
  group.wait();expect(!torn,"4000 concurrent full-roster publications and render reads never expose torn axes, identities or viewport packets")
  print("\(passed) multi-player input-routing checks passed;native controller sampling and visible lobby are separate")
 }
}
