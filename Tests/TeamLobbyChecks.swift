import Foundation

@main struct TeamLobbyChecks {
    static func main() {
        var checks=0
        func expect(_ value:Bool,_ message:String){precondition(value,message);checks+=1;print("PASS \(message)")}
        func open(_ keyboard:Bool,_ pads:Int)->GameMenu {
            var m=GameMenu()
            _=m.handle(Controls(accept:true,menuRow:2),phase:.title,allowKeyboard:keyboard,availableControllers:pads)
            return m
        }
        var mac=open(true,1)
        expect(mac.teamOpen && mac.teamCount==2 && mac.teamKeyboard && mac.count==6,"one-pad Mac lobby reserves keyboard player one")
        expect(mac.handle(Controls(accept:true),phase:.title) == .startTeam(2,true),"confirmation emits the selected two-player route")
        _=mac.handle(Controls(menuX:-1,menuRow:1),phase:.title)
        expect(mac.teamCount==4 && mac.count==8 && mac.teamBackRow==7,"left wraps directly from two to four players and exposes four colors")
        expect(mac.handle(Controls(menuX:-1,menuRow:6),phase:.title) == .teamColor(3,-1),"fourth player's color action keeps its owner")
        _=mac.handle(Controls(accept:true,menuRow:2),phase:.title)
        expect(!mac.teamKeyboard && mac.handle(Controls(accept:true,menuRow:0),phase:.title) == .startTeam(4,false),"keyboard can be disabled without changing team size")
        _=mac.handle(Controls(accept:true,menuRow:1),phase:.title)
        expect(mac.teamCount==2 && mac.count==6,"right wraps four to two and removes hidden player rows")
        expect(mac.handle(Controls(accept:true,menuRow:7),phase:.title) == .none && mac.selected==1,"a hidden row cannot reuse the last selection")
        _=mac.handle(Controls(back:true),phase:.title)
        expect(!mac.teamOpen && mac.selected==2 && mac.count==3,"Back restores the highlighted setup entry")
        var many=open(true,3)
        expect(!many.teamKeyboard,"two or more Mac controllers default to a controller per player")
        _=many.handle(Controls(openSettings:true),phase:.title)
        expect(many.settingsOpen && !many.teamOpen,"the global settings command closes setup")
        many.sync(.playing)
        expect(!many.settingsOpen && !many.teamOpen && many.selected==0,"starting a run clears menu pages")
        var tv=open(false,1)
        expect(tv.teamOpen && !tv.teamKeyboard && !tv.teamAllowsKeyboard && tv.count==5,"Apple TV setup has no keyboard option")
        expect(tv.handle(Controls(accept:true,menuRow:2),phase:.title) == .teamColor(0,1),"Apple TV's first color is at its own visible row")
        _=tv.handle(Controls(menuX:1,menuRow:1),phase:.title)
        expect(tv.teamCount==3 && tv.count==6,"Apple TV can choose three players")
        _=tv.handle(Controls(menuX:1,menuRow:1),phase:.title)
        expect(tv.teamCount==4 && tv.count==7,"Apple TV can choose four players")
        expect(tv.handle(Controls(accept:true,menuRow:0),phase:.title) == .startTeam(4,false),"Apple TV always emits a controller-only start")
        _=tv.handle(Controls(accept:true,menuRow:6),phase:.title)
        expect(!tv.teamOpen && tv.selected==2,"Apple TV's last visible row returns to the title")
        var paused=GameMenu();paused.sync(.paused)
        expect(paused.count==2 && paused.handle(Controls(accept:true,menuRow:2),phase:.paused) == .none,"a paused run cannot be overwritten by team setup")
        expect(paused.handle(Controls(back:true),phase:.paused) == .resume,"Back still resumes a paused run")
        var mouse=GameMenu()
        _=mouse.handle(Controls(menuPoint:V2(x:400,y:352)),phase:.title,allowKeyboard:true,availableControllers:1)
        expect(mouse.teamOpen,"mouse positions are interpreted on the menu-owning thread")
        _=mouse.handle(Controls(menuPoint:V2(x:400,y:410)),phase:.title)
        expect(mouse.teamCount==3,"setup mouse rows use the tighter spacing")
        expect(mouse.handle(Controls(menuPoint:V2(x:400,y:242)),phase:.title) == .teamColor(2,1),"mouse can reach the third color without selecting a neighbor")
        let selected=mouse.selected
        expect(mouse.handle(Controls(menuPoint:V2(x:0,y:452)),phase:.title) == .none && mouse.selected==selected,"clicks outside visible rows have no action")
        expect(mouse.handle(Controls(menuPoint:V2(x:400,y:Double.nan)),phase:.title) == .none,"nonfinite mouse input is ignored")
        let box=FrameInputMailbox(),point=V2(x:400,y:410)
        box.publish(players:[Controls()],devices:[],size:CGSize(width:1280,height:720),operatorControls:Controls(menuPoint:point))
        let first=box.take(),second=box.take()
        expect(first.operatorControls.menuPoint==point && second.operatorControls.menuPoint==nil,"mailbox delivers a mouse click once")
        expect(InputMenu.merge([Controls()],operatorControls:first.operatorControls).menuPoint==point,"operator mouse input reaches menu controls without acting on a player")
        print("\(checks) team lobby checks passed")
    }
}
