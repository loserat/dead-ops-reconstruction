import Foundation

/// Approximate layout from the sampled prison rounds: ground court, raised perimeter, stairs and a one-way drop.
enum PrisonLayout {
    static let deck=1.6,innerX=9.0,innerY=5.5,stairFoot=2.9,stairHalf=1.35
    static func height(_ p:V2)->Double {
        if abs(p.x)>=innerX || abs(p.y)>=innerY {return deck}
        if abs(p.x)<=stairHalf && p.y>=stairFoot {return deck*(p.y-stairFoot)/(innerY-stairFoot)}
        return 0
    }
    static func allows(_ a:V2,_ b:V2)->Bool {
        let ha=height(a),hb=height(b)
        if abs(ha-hb)<=0.9*(b-a).length+0.025 {return true}
        return ha>hb && a.y<=(-innerY) && b.y>(-innerY) && abs(a.x)<1.1 && abs(b.x)<1.1
    }
    static func railHeight(_ p:V2)->Double {deck*max(0,min(1,(p.y-stairFoot)/(innerY-stairFoot)))}
    static let trapPositions=[V2(x:-5.6,y:-2.5),V2(x:5.6,y:-2.5),V2(x:-5.6,y:2.5),V2(x:5.6,y:2.5)]
    static let railPosts=(0..<8).flatMap{i in [-1.0,1].map{V2(x:$0*1.48,y:3.05+Double(i)*0.30)}}
    static let obstacles:[ArenaObstacle] = {
        railPosts.map{ArenaObstacle($0,half:V2(x:0.06,y:0.16),elevation:railHeight($0),height:0.75)} +
        [ArenaObstacle(V2(x:-7,y:3.5),radius:0.75,height:0.7),ArenaObstacle(V2(x:7,y:-3.5),radius:0.65,height:0.7)]
    }()
}

extension GameCore {
    func updateHeroElevation(_ dt:Double) {
        if flying {if vehicle?.landingTarget==nil {heroElevation=max(3.1,layout.height(hero)+1.2)};heroFallSpeed=0;return}
        let floor=layout.height(hero)
        if heroElevation<=floor+0.12 {heroElevation=floor;heroFallSpeed=0}
        else {heroFallSpeed-=14*dt;heroElevation=max(floor,heroElevation+heroFallSpeed*dt)}
    }
    func updateFoeElevation(_ index:Int,_ dt:Double) {
        let floor=layout.height(foes[index].p)
        if foes[index].elevation<=floor+0.12 {foes[index].elevation=floor;foes[index].fallSpeed=0}
        else {foes[index].fallSpeed-=14*dt;foes[index].elevation=max(floor,foes[index].elevation+foes[index].fallSpeed*dt)}
    }
}
