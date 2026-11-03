import Foundation

/// Two stairways connect a raised block with the street. Geometry is an approximation, not a traced map.
enum UrbanLayout {
    static let deck=1.8,edgeX = -1.8,edgeY=2.5
    static func height(_ p:V2)->Double {
        if p.x<edgeX && p.y<edgeY {return deck}
        if abs(p.y)<=1.3 && p.x>=edgeX && p.x<=1.2 {return deck*(1.2-p.x)/3}
        if p.x >= -10.9 && p.x <= -9.1 && p.y>=edgeY && p.y<=5.5 {return deck*(5.5-p.y)/3}
        return 0
    }
    static func allows(_ a:V2,_ b:V2)->Bool {
        // Side walls are discontinuities even where the first riser is very low.
        // A slope tolerance alone depends on step length and can disagree with navigation.
        for side in [-1.3,1.3] where (a.y<=side) != (b.y<=side) {
            let t=(side-a.y)/(b.y-a.y),x=a.x+(b.x-a.x)*t
            if x>edgeX+0.00001 && x<1.2-0.00001 {return false}
        }
        for side in [-10.9,-9.1] where (a.x<=side) != (b.x<=side) {
            let t=(side-a.x)/(b.x-a.x),y=a.y+(b.y-a.y)*t
            if y>2.5+0.00001 && y<5.5-0.00001 {return false}
        }
        if abs(height(a)-height(b))<=0.9*(b-a).length+0.025 {return true}
        return height(a)>height(b) && a.y<=edgeY && b.y>edgeY && a.x > -6.2 && a.x < -3.8 && b.x > -6.2 && b.x < -3.8
    }
    static let traps=[V2(x:-7,y:-3.5),V2(x:-5,y:0.6),V2(x:6.2,y:-3.4),V2(x:6.2,y:3.5)]
    static let piles=[V2(x:-7,y:-1.3),V2(x:-4,y:-4.5),V2(x:5,y:-3.8),V2(x:5,y:4.3)]
    static let obstacles=[ArenaObstacle(V2(x:-9,y:-5.7),half:V2(x:0.8,y:0.5),elevation:deck,height:0.65),ArenaObstacle(V2(x:9,y:0.2),half:V2(x:0.7,y:0.5),height:0.7)]
}
