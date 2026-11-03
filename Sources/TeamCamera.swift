import Foundation
import CoreGraphics

struct CameraSubject {
    var p:V2,elevation:Double,radius:Double=0.65,height:Double=1.65
}

/// Keep haze behind the complete gameplay envelope even when the overview camera moves
/// farther away for aspect, multiple players or airborne actors. Euclidean distance is
/// conservative for a view-depth fog implementation too. Retain the legacy fade width.
enum OverviewFog {
    static func range(cameraX:Double,cameraY:Double,cameraZ:Double,subjects:[CameraSubject])->(start:Double,end:Double) {
        var farthestSquared=0.0
        for s in subjects {for dx in [-s.radius,s.radius] {for dz in [-s.radius,s.radius] {for dy in [0.0,s.height] {
            let x=s.p.x+dx-cameraX,y=s.elevation+dy-cameraY,z=s.p.y+dz-cameraZ
            farthestSquared=max(farthestSquared,x*x+y*y+z*z)
        }}}}
        let start=max(48,sqrt(farthestSquared)+2.5)
        return (start,start+37)
    }
}

/// Logical HUD geometry shared with the visible cards. Camera fitting uses their actual occupied
/// rectangles instead of reserving the whole top band when playing solo.
enum PlayHUDLayout {
    static let cardWidth=280.0,cardHeight=120.0,cardY=576.0
    static func cardX(slot:Int,players:Int)->Double {players>1 ? 64+Double(slot)*288:24}
    static let roundRect=CGRect(x:756,y:652,width:500,height:44)
    static func soloObstacles(aspect:Double)->[CGRect] {
        let factor=min(aspect/1280,1.0/720)
        return [CGRect(x:24,y:cardY,width:cardWidth,height:cardHeight),roundRect].map {rect in
            let r=rect.insetBy(dx:-12,dy:-12)
            return CGRect(x:(Double(r.minX)-640)*2*factor/aspect,y:(Double(r.minY)-360)*2*factor,
                          width:Double(r.width)*2*factor/aspect,height:Double(r.height)*2*factor)
        }
    }
}

enum CenteredOverviewFrame {
    static func center(distance:Double,aspect:Double)->V2 {
        let fit=min(1,aspect/(16.0/9)),target = -0.04*fit,tangent=GameCameraProjection.tangent/aspect
        return V2(x:0,y:target*tangent*distance/(GameCameraProjection.ground-target*tangent*GameCameraProjection.up))
    }
    static func fits(_ subjects:[CameraSubject],center:V2,distance:Double,aspect:Double,orientation:ArenaViewOrientation)->Bool {
        let tangent=GameCameraProjection.tangent,vertical=tangent/aspect,fit=min(1,aspect/(16.0/9))
        let blocks=PlayHUDLayout.soloObstacles(aspect:aspect)
        for s in subjects {
            var left=Double.infinity,right = -Double.infinity,bottom=Double.infinity,top = -Double.infinity
            for dx in [-s.radius,s.radius] {for dz in [-s.radius,s.radius] {for dy in [0.0,s.height] {
                let x=(s.p.x+dx-center.x)*orientation.sign,z=(s.p.y+dz-center.y)*orientation.sign,h=s.elevation+dy
                let depth=distance-h*GameCameraProjection.ground-z*GameCameraProjection.up
                guard depth>0.2 else{return false}
                let u=x/(depth*tangent),v=(h*GameCameraProjection.up-z*GameCameraProjection.ground)/(depth*vertical)
                guard abs(u)<=0.92,v>=(-0.86*fit),v<=0.92*fit else{return false}
                left=min(left,u);right=max(right,u);bottom=min(bottom,v);top=max(top,v)
            }}}
            let bounds=CGRect(x:left,y:bottom,width:right-left,height:top-bottom)
            if blocks.contains(where:{$0.intersects(bounds)}) {return false}
        }
        return true
    }
}

/// Only the near part of an entrance belongs in the gameplay frame. Far spawn
/// shelters remain real simulation paths, but no longer dictate the zoom.
/// Clip the actual route segments instead of moving enemies or fabricating entry points.
enum NearEntranceFrame {
    static let outsideMargin=0.4
    static func points(_ route:EnemyArrival,width:Double,depth:Double)->[EnemyEntryPoint] {
        var result=[EnemyEntryPoint]()
        for (a,b) in zip(route.points,route.points.dropFirst()) {
            let delta=b.p-a.p
            var lo=0.0,hi=1.0
            for (start,change,extent) in [(a.p.x,delta.x,width+outsideMargin),(a.p.y,delta.y,depth+outsideMargin)] {
                if abs(change)<1e-12 {
                    if abs(start)>extent {lo=1;hi=0;break}
                }else{
                    let u=(-extent-start)/change,v=(extent-start)/change
                    lo=max(lo,min(u,v));hi=min(hi,max(u,v))
                }
            }
            guard lo<=hi else{continue}
            for t in [lo,hi] {
                let point=EnemyEntryPoint(p:a.p+delta*t,height:a.height+(b.height-a.height)*t)
                if result.last.map({($0.p-point.p).length<1e-8 && abs($0.height-point.height)<1e-8}) != true {result.append(point)}
            }
        }
        return result
    }
}

extension ArenaLayout {
    /// Complete playable ground plus a narrow, visible approach at each entrance.
    /// Fixed map data; far non-playable paths no longer force a distant camera.
    var overviewSubjects:[CameraSubject] {
        let w=kind == .cave ? CaveLayout.width:IslandLayout.width
        let d=kind == .cave ? CaveLayout.depth:IslandLayout.depth
        var points=[CameraSubject]()
        for x in [-w,w] {for z in [-d,d] {
            let p=V2(x:x,y:z)
            points.append(CameraSubject(p:p,elevation:height(p),radius:0.45,height:1.8))
        }}
        if bonusRoom != .fate {
            for entry in 0..<enemyEntranceCount {
                for point in NearEntranceFrame.points(enemyArrival(index:entry),width:w,depth:d) {
                    // Near approach cue; actual body/lane extremes are checked separately.
                    points.append(CameraSubject(p:point.p,elevation:max(0,point.height),radius:0.45,height:1.8))
                }
            }
        }
        return points
    }
}

/// Standard gameplay camera: the entire arena is always visible, independent of player movement.
/// Solve a tight perspective frame below the HUD once per map/aspect/direction. Extra airborne
/// subjects may only widen it; they can never crop a map edge or move the map's center.
struct ArenaOverviewCamera {
    private(set) var center=V2.zero
    private(set) var baseScale=0.0
    private var envelope=CameraZoomEnvelope()
    var scale:Double {envelope.scale}
    private var kind:ArenaKind?,room:SideRoomKind?,ratio=0.0
    private var direction:ArenaViewOrientation = .normal
    private var hudPlayers=0,mapSubjects:[CameraSubject]=[]
    private(set) var usesCenteredFrame=false
    var atmosphereSubjects:[CameraSubject] {mapSubjects}
    static let horizontal=0.92,top=0.56,bottom=0.86
    mutating func update(layout:ArenaLayout,subjects:[CameraSubject],aspect rawAspect:Double,dt:Double,snap:Bool=false,orientation:ArenaViewOrientation = .normal,players:Int=1) {
        let aspect=GameCameraProjection.aspect(rawAspect)
        let changed=kind != layout.kind || room != layout.bonusRoom || ratio != aspect || direction != orientation || hudPlayers != players
        let fit=min(1,aspect/(16.0/9)),top=Self.top*fit,bottom=Self.bottom*fit
        if changed {
            let map=layout.overviewSubjects
            let minX=map.map{$0.p.x-$0.radius}.min()!,maxX=map.map{$0.p.x+$0.radius}.max()!
            let cx=(minX+maxX)/2,tangent=GameCameraProjection.tangent/aspect
            let ground=GameCameraProjection.ground,up=GameCameraProjection.up
            var corners=[(Double,Double,Double)]()
            for s in map {for dx in [-s.radius,s.radius] {for dz in [-s.radius,s.radius] {for dy in [0.0,s.height] {
                corners.append(((s.p.x+dx-cx)*orientation.sign,(s.p.y+dz)*orientation.sign,s.elevation+dy))
            }}}}
            func range(_ distance:Double)->(Double,Double) {
                var lo = -Double.infinity,hi=Double.infinity
                for (x,z,h) in corners {
                    lo=max(lo,z-(bottom*tangent*distance+h*(up-bottom*tangent*ground))/(ground+bottom*tangent*up))
                    hi=min(hi,z-(h*(up+top*tangent*ground)-top*tangent*distance)/(ground-top*tangent*up))
                    lo=max(lo,(abs(x)/(Self.horizontal*GameCameraProjection.tangent)-distance+h*ground+z*up)/up)
                    lo=max(lo,(0.2-distance+h*ground+z*up)/up)
                }
                return (lo,hi)
            }
            var low=0.0,high=16.0
            while range(high).0>range(high).1 {high*=2}
            for _ in 0..<40 {let mid=(low+high)/2,r=range(mid);if r.0<=r.1 {high=mid}else{low=mid}}
            let bounds=range(high)
            center=V2(x:cx,y:(bounds.0+bounds.1)/2*orientation.sign)
            baseScale=high*GameCameraProjection.tangent/aspect*1.002
            usesCenteredFrame=false;mapSubjects=map
            if players==1 && layout.bonusRoom != .fate {
                // Keep the entire playable map and near entrance envelope. Only reclaim the empty space
                // between the two solo HUD panels; no player following and clear approach mouths.
                let lower=high*0.5
                for index in 0...128 {
                    let d=lower+(high-lower)*Double(index)/128
                    let c=CenteredOverviewFrame.center(distance:d,aspect:aspect)*orientation.sign
                    if CenteredOverviewFrame.fits(map,center:c,distance:d,aspect:aspect,orientation:orientation) {
                        var lo=max(lower,d-(high-lower)/128),hi=d
                        for _ in 0..<18 {
                            let mid=(lo+hi)/2,m=CenteredOverviewFrame.center(distance:mid,aspect:aspect)*orientation.sign
                            if CenteredOverviewFrame.fits(map,center:m,distance:mid,aspect:aspect,orientation:orientation) {hi=mid}else{lo=mid}
                        }
                        let safe=hi*1.002,newCenter=CenteredOverviewFrame.center(distance:safe,aspect:aspect)*orientation.sign
                        if safe<high*0.985 && CenteredOverviewFrame.fits(map,center:newCenter,distance:safe,aspect:aspect,orientation:orientation) {
                            center=newCenter;baseScale=safe*GameCameraProjection.tangent/aspect;usesCenteredFrame=true
                        }
                        break
                    }
                }
            }
            kind=layout.kind;room=layout.bonusRoom;ratio=aspect;direction=orientation;hudPlayers=players
        }
        let finite=subjects.filter{$0.p.x.isFinite && $0.p.y.isFinite && $0.elevation.isFinite && $0.radius.isFinite && $0.height.isFinite}
        var needed=baseScale
        // A ground player that already fits between the solo HUD panels must not
        // trigger the older whole-top-band safety zoom. Check the actual footprint.
        let fitsBase=usesCenteredFrame && CenteredOverviewFrame.fits(finite,center:center,distance:baseScale*aspect/GameCameraProjection.tangent,aspect:aspect,orientation:orientation)
        if !fitsBase {
            needed=max(baseScale,GameCameraProjection.requiredScale(finite,center:center,elevation:0,aspect:aspect,horizontal:Self.horizontal,top:top,bottom:bottom,orientation:orientation))
            if usesCenteredFrame {
                for _ in 0..<64 {
                    if CenteredOverviewFrame.fits(mapSubjects+finite,center:center,distance:needed*aspect/GameCameraProjection.tangent,aspect:aspect,orientation:orientation) {break}
                    needed*=1.05
                }
            }
        }
        envelope.update(requiredScale:max(baseScale,needed),dt:dt,snap:changed || snap)
    }
}
/// Half-turns change the view, while simulation positions and routes remain in world coordinates.
enum ArenaViewOrientation:Int,CaseIterable {
    case normal=1,reversed = -1
    var sign:Double {Double(rawValue)}
    var opposite:Self {self == .normal ? .reversed:.normal}
    func transform(_ point:V2)->V2 {point*sign}
    func worldControls(_ screen:Controls)->Controls {
        var result=screen;result.move=transform(screen.move);result.aim=transform(screen.aim);return result
    }
    // Three intra-arena changes per four rounds; changing arenas keeps the current direction.
    static func combat(round:Int)->Self {
        let index=(max(1,round)-1)%8
        return [1,3,4,6].contains(index) ? .reversed:.normal
    }
    var exitEdge:String {self == .normal ? "UNTEN":"OBEN"}
    func sideEdge(_ worldX:Double)->String {worldX*sign<0 ? "LINKS":"RECHTS"}
}
extension GameCore {
    var viewOrientation:ArenaViewOrientation {
        let ordinaryRoom=sideRoom.map{$0.kind != .fate} ?? false
        let displayedRound=ordinaryRoom ? RoundRules.stage(round)%40+1:round
        let base=ArenaViewOrientation.combat(round:displayedRound)
        return bonusViewFlip ? base.opposite:base
    }
}
/// Archived setup uses pitch75, cg_fov65 and engine mode3.
/// Horizontal FOV convention, map scale and tracking remain our explicit interpretation.
enum GameCameraProjection {
    static let pitchDegrees=75.0,fieldOfView=65.0
    // Own framing values: preserve the archived angle, bring the world closer and track the player.
    // The old 0.42 tracking fraction left the player at the edge and forced the safety fit to zoom out.
    static let followingScale=5.0,overviewScale=9.0,followFraction=0.90
    static let up=cos(pitchDegrees*Double.pi/180),ground=sin(pitchDegrees*Double.pi/180)
    static let tangent=tan(fieldOfView*Double.pi/360)
    static func aspect(_ value:Double)->Double {value.isFinite ? max(0.5,value):16.0/9}
    static func distance(scale:Double,aspect value:Double)->Double {scale*aspect(value)/tangent}
    /// Fit every subject corner including its perspective depth, not just its flat silhouette.
    static func requiredScale(_ subjects:[CameraSubject],center:V2,elevation:Double,aspect value:Double,horizontal:Double=0.88,top:Double=0.56,bottom:Double=0.64,orientation:ArenaViewOrientation = .normal)->Double {
        let ratio=aspect(value),verticalTangent=tangent/ratio
        var required=0.0
        for subject in subjects {
            let radius=max(0,subject.radius)
            for x in [-radius,radius] {for z in [-radius,radius] {for y in [0.0,max(0,subject.height)] {
                let dx=(subject.p.x+x-center.x)*orientation.sign,dz=(subject.p.y+z-center.y)*orientation.sign,height=subject.elevation+y-elevation
                let depth=height*ground+dz*up,vertical=height*up-dz*ground
                required=max(required,depth+0.2,depth+abs(dx)/(tangent*horizontal),depth+vertical/(verticalTangent*top),depth-vertical/(verticalTangent*bottom))
            }}}
        }
        return required*verticalTangent
    }
}
/// Expand immediately for safety; hold the wider shot briefly before a damped return.
/// A small deadband prevents tiny framing changes from visibly pumping the zoom.
struct CameraZoomEnvelope {
    private(set) var scale=GameCameraProjection.followingScale
    private var hold=0.0
    mutating func update(requiredScale:Double,dt:Double,snap:Bool=false) {
        guard requiredScale.isFinite,requiredScale>0 else{return}
        let dt=dt.isFinite ? max(0,dt):0
        if snap {scale=requiredScale;hold=0;return}
        if requiredScale>scale {
            if requiredScale-scale>0.04 {hold=0.65}
            scale=requiredScale
        }else{
            let contractionTime=max(0,dt-hold)
            hold=max(0,hold-dt)
            if contractionTime>0 && scale-requiredScale>max(0.04,scale*0.02) {
                scale+=(requiredScale-scale)*(1-exp(-1.8*contractionTime))
            }
        }
    }
}
/// Same camera angle as solo, with a shared safe rectangle below the team HUD.
/// Subject bounds include airborne vehicles; enlargement is immediate, contraction is damped.
struct TeamCameraRig {
    private(set) var center=V2.zero,elevation=0.0
    private var zoomEnvelope=CameraZoomEnvelope()
    var scale:Double {zoomEnvelope.scale}
    private var initialized=false
    private var lastOrientation:ArenaViewOrientation = .normal
    static let up=GameCameraProjection.up,ground=GameCameraProjection.ground
    static let horizontal=0.88,top=0.56,bottom=0.64
    mutating func update(subjects:[CameraSubject],settings:GameSettings,aspect rawAspect:Double,floor:Double,dt:Double,snap:Bool=false,orientation:ArenaViewOrientation = .normal) {
        let subjects=subjects.filter{$0.p.x.isFinite && $0.p.y.isFinite && $0.elevation.isFinite && $0.radius.isFinite && $0.height.isFinite}
        guard !subjects.isEmpty else{return}
        let aspect=rawAspect.isFinite ? max(0.5,rawAspect):16.0/9
        let fit=min(1,aspect/(16.0/9)),top=Self.top*min(1,aspect/(16.0/9)),bottom=Self.bottom*min(1,aspect/(16.0/9))
        let follows=settings.cameraMode == .following,targetElevation=follows && floor.isFinite ? floor*0.8:0
        let left=subjects.map{$0.p.x*orientation.sign-max(0,$0.radius)}.min()!,right=subjects.map{$0.p.x*orientation.sign+max(0,$0.radius)}.max()!
        let low=subjects.map{$0.elevation*Self.up-$0.p.y*orientation.sign*Self.ground-max(0,$0.radius)*Self.ground}.min()!
        let high=subjects.map{($0.elevation+max(0,$0.height))*Self.up-$0.p.y*orientation.sign*Self.ground+max(0,$0.radius)*Self.ground}.max()!
        let base=(follows ? GameCameraProjection.followingScale:GameCameraProjection.overviewScale)*settings.zoom.factor*max(1,(16.0/9)/aspect)
        let desiredScale=max(base,(right-left)/2/(aspect*Self.horizontal),(high-low)/2/(0.60*fit))
        let target=follows ? orientation.transform(V2(x:(left+right)/2,y:(targetElevation*Self.up-(low+high)/2-desiredScale*0.04*fit)/Self.ground)):.zero
        let blend=dt.isFinite ? 1-exp(-6*max(0,dt)):0
        let snapZoom = !initialized || snap || orientation != lastOrientation
        if snapZoom {center=target;elevation=targetElevation;initialized=true}
        else {
            center=center+(target-center)*blend;elevation+=(targetElevation-elevation)*blend
        }
        lastOrientation=orientation
        let required=max(desiredScale,GameCameraProjection.requiredScale(subjects,center:center,elevation:elevation,aspect:aspect,horizontal:Self.horizontal,top:top,bottom:bottom,orientation:orientation))
        zoomEnvelope.update(requiredScale:required,dt:dt,snap:snapZoom)
    }
}
