import Foundation
@main struct FirstEight {
 static func main(){
  setbuf(stdout,nil)
  for warmup in [0,31,113] {
   let g=GameCore(),pilot=NormalPilot();for _ in 0..<warmup {_=g.random()};g.reset()
   var time=0.0,phase=g.phase,round=0,frames=0,invalid=0,rooms=0,weaponKinds=Set<Int>()
   while time<1800 && (g.round<=8 || g.phase == .transition) && g.phase != .gameOver {
    let c=pilot.sample(g)
    let previousDeaths=g.deaths,previousPosition=g.hero
    g.step(1.0/60,input:c);time+=1.0/60;frames+=1
    if g.deaths>previousDeaths {print("DEATH seed\(warmup) round\(g.round) at\(Int(time))s from\(previousPosition),traps=\(g.layout.traps.filter{($0.p-previousPosition).length<2}.map{String(describing:$0.state(at:g.hazardClock))})")}

    if let w=g.activeWeapon {weaponKinds.insert(w.rawValue)}
    if !g.layout.walkable(g.hero,clearance:0.24) {invalid+=1}
    if g.round != round {round=g.round;print("RUN\(warmup) round\(round) at\(Int(time))s lives\(g.lives) deaths\(g.deaths)")}
    if g.phase == .bonusRoom && phase != .bonusRoom {rooms+=1};phase=g.phase
   }
   print("RESULT seed\(warmup):round\(g.round),phase\(g.phase),hero\(g.hero),lives\(g.lives),deaths\(g.deaths),invalid\(invalid),foes\(g.foes.count),time\(time)")
   precondition(g.round==9 && g.phase == .playing && !g.godMode && !g.usedGodMode && g.trainingHits==0 && invalid==0,"eight-round normal run failed: seed\(warmup),round\(g.round),phase\(g.phase),p\(g.hero),foes\(g.foes.count)")
   print("PASS first eight normal rounds seed\(warmup):\(Int(time)) simulated seconds,\(frames) frames,\(g.lives) lives remaining,\(g.deaths) deaths,\(rooms) side rooms,\(weaponKinds.count) found gun types,0 invalid positions,no Godmode or injected equipment")
  }
 }
}
