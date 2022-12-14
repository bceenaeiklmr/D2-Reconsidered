; Script     D2 Reconsidered.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/D2-Reconsidered
; Date       31.10.2022
; Version    0.1.2

; Currently, it only works on 2560x1440 resolution. FHD support should be added asap.
; The pixel colors are 'hardcoded', I have ideas about implemeting a few functions to get the actual colors. (e.g. different game, brightness settings can cause errors)

#NoEnv
#Persistent
#SingleInstance, Force
;#Warn ; I have not checked it yet, I am sure there are a lot of problems
SendMode, Input
SetWorkingDir, %A_ScriptDir%
SetTitleMatchMode, 2
SetTitleMatchMode, Fast
SetBatchlines, -1
SetWinDelay, -1
ListLines, Off

; ##########################

; AutoHotInterception is used for input devices (sending hotkeys, mouse actions)
; Can AHI simulate human-like actions?
; In my understanding using AHI can make harder to detect the script
; A compiled and renamed AHK.exe could be used to 'hide' the script
global d2 := new D2R
if (d2.base.SendMode = "AHI") {
    global AHI := new AutoHotInterception()
    for k, v in AHI.GetDeviceList() {
        (v.IsMouse) ?   d2.base.mouseID := v.Id
                    : (!d2.base.keyboardId ? d2.base.keyboardID := v.Id : "" )
    }
}
; MF run sequence for NewRun method
D2.MFRun := ["Travincial", "Catacombs Level 2", "Frigid Highlands" ] ; "River of Flame"
return

; #######################################################################################################

; Gdip lib and AHI install and its files are required
; Alternatively the built in AutoHotkey sendmode can be used
#include Gdip_All.ahk
#include C:\Users\%A_userName%\OneDrive\Documents\Autohotkey\Lib\AutoHotInterception\Lib\AutoHotInterception.ahk

; #######################################################################################################

pause::pause

^Escape::ExitApp

F10::mouseGetPixel() ; only needed for checking some pixels

; Actions can be binded to states
; e.g it is convenient to use the same hotkeys to cycle through the stash tabs and use potions.
#if D2.State.Active && D2.State.Stash
    
    1::D2.Stash.TabSelect(1)
    2::D2.Stash.TabSelect(2)
    3::D2.Stash.TabSelect(3)
    4::D2.Stash.TabSelect(4)
    
    WheelDown::d2.Stash.TabScroll()
    WheelUp::d2.Stash.TabScroll()
    
    Tab::d2.Stash.TabScroll()
    
    F3::d2.Inventory.MoveToStash()

#if D2.State.Inventory

    F1::d2.Inventory.Identify()

#if D2.State.Active && D2.State.Ingame

    ^i::Gui.AddItemToRun()

    0::d2.EliteCounter()
    +0::d2.EliteCounter()

    ~+c::d2.AdvancedStats()
    
;#if D2.State.Active && D2.State.Waypoint
   ;

#if D2.State.Active && D2.State.MainMenu

    ; character selection with wheel in main menu 
    WheelDown::send("{Down}") 
    WheelUp::send("{Up}")

#if D2.State.Active

    XButton2::D2.NewRun()

#if D2.State.Exist

    #Up::d2.Show()
    #Down::d2.Minimize()

#if

;########################################################################################################

getPixelColors() {

    d2.Stop()
    ; config, detecting colors of the main states
    Ingame := "Please, go to game (ingame) and press F12."
    IngameOptions := "Ingame color detected." "`n`n" "Now press the Escape button and press F12 again."
    MainMenuOnline := "Ingame Menu color detected." "`n`n" "Now you can leave the game." "`n`n" "In the character screen please select the Online mode and press F12."
    MainMenuOffline := "Now switch to Offline mode and press F12.`n`n(do not hover the mouse over the create button)"

    pixels := {}
    for k, v in ["Ingame", "IngameOptions", "MainMenuOnline", "MainMenuOffline"] {
        Msgbox,, % " ", % %v%, 4
        KeyWait, F12, D
        pBitmap := Gdip_BitmapFromScreen(d2.ActiveMonitor)
        if ((pixels[v] := PixelSearch(1280, 1338, 0, pBitmap)) = 0x0) {
            Msgbox,, % " ", % "Error with bitmap.", 1
            ExitApp
        }    
        Gdip_DisposeImage(pBitmap)
    }
    Pixels.Loading := 0x0 ; this should be black
    ; do the rest, wp, search for PixelSearch()
    ; save to the ini file
    Msgbox,, % " ", % "Almost done, now you create a game and when it is loaded hit F12."
    d2.Start()
}

class D2R {

    ; The main timer method to detect the actual state of the game
    ; At first, only one pixel is searched at x1280 y1338.
    ; Checking the color here tells if the game is ingame, in menu, etc... Most important is to detect ingame state.
    ; unwrapped Gdip_CreateBitmapFromScreen() is used for improved speed
    getState() {
        
        Start := QPC()            
        
        if !WinExist("ahk_id" this.hWnd)
            return (this.State.Exist := 0, Gui.ShowHide())
        
        if !WinActive("ahk_id" this.hWnd)
            return (this.State.Active := 0, Gui.ShowHide())
        
        winGetPos, x, y, w, h, % "ahk_id" this.hWnd
        if (!x && !y && w != A_ScreenWidth && h != A_ScreenHeight)
            return (this.State.ScreenSize := 0, Gui.ShowHide())
        
        this.State.Exist := 1,
        this.State.Active := 1,
        ;this.State.ScreenSize := w " x " h, ; only for debugging purposes
        ;this.State.Position := x ", " y ""
        
        ; Create device context
        chdc := DllCall("CreateCompatibleDC", "UInt", hdc),
        VarSetCapacity(bi, 40, 0),
        NumPut(w,  bi,  4, "UInt"  ),
        NumPut(h,  bi,  8, "UInt"  ),
        NumPut(40, bi,  0, "UInt"  ),
        NumPut(1,  bi, 12, "UShort"),
        NumPut(0,  bi, 16, "UInt"  ),
        NumPut(32, bi, 14, "UShort"),
        
        ; Create device independent section
        hbm := DllCall("CreateDIBSection"
                	    , "Uint", chdc
                        , "Uint", &bi
                        , "uint", 0
                        , "uint*", 0 ;(ppvBits:=0)
                        , "Uint", 0
                        , "uint", 0, "Uint"),
        
        ; Select object
        obm := DllCall("SelectObject", "Uint", chdc, "Uint", hbm),
        
        ; Get handle for device context
        hhdc := DllCall("GetDC", "UInt", 0),
        
        ; Perform BitBlt
	    DllCall("gdi32\BitBlt"
                , "UInt", chdc
                , "int", 0
                , "int", 0
                , "int", w
                , "int", h
                , "UInt", hhdc
                , "int", 0
                , "int", 0
                , "uint", 0x00CC0020),
        
        ; Release device context
        DllCall("ReleaseDC", "UInt", 0, "UInt", hhdc),
        
        ; Create bitmap from Hbitmap
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "UInt", hbm, "UInt", 0, "uint*", pBitmap),
        
        ; Select bitmap object, handle                       
        DllCall("SelectObject", "Uint", chdc, "Uint", obm), 
        DllCall("DeleteObject", "UInt", hbm),
        
        ; Delete context device handle 
        DllCall("DeleteDC", "UInt", hhdc),
        
        ; Delete context device 
        DllCall("DeleteDC", "UInt", chdc)
        
        ; Copy a clone for PixelSeach
        this.base.pBitmap := pBitmap  
        
        ; Checking the color of the pixel at x1280 y1338 the main state of the game can be decided
        switch PixelSearch(1280, 1338, 0) {
            Case "0x2a2a26":
	    	; I had severe issues with the timer and references I guess, I have not found a better way to handle the states
                this.State.Ingame := 1, this.State.IngameOptions := 0, this.State.MainMenu := 0, this.State.MainMenuCreateButton := 0, this.State.Loading := 0, this.State.NoServer := 0, this.State.NoValidState := 0
                if (this.state.Inventory := this.Inventory.IsOpened()) {
                    this.Inventory.getFreeSpace(),
                    this.state.InventoryFree := this.Inventory.Free,
                    this.state.InventoryUsed := this.Inventory.Used
                    if (this.state.Stash := this.Stash.isOpened()) {
                        this.Stash.getFreeSpace(),
                        this.state.StashTab := this.Stash.ActiveTab,
                        this.state.StashFree := this.Stash.Free,
                        this.state.StashUsed := this.Stash.Used
                    } else
                        this.state.stash := 0
                } else if !this.IsCharacterPanelOpened() && this.Waypoint.isOpened() {
                    this.state.Inventory := 0, this.state.Stash := 0, this.state.SkillTree := 0, this.state.CharacterPanel := 0,
                    this.state.Waypoint := 1,
                    this.state.Act := this.Waypoint.Act,
                    this.state.Zone := this.Waypoint.Zone,
                    this.state.Location := this.Waypoint.Name
                } else {
                    this.state.SkillTree := this.IsSkillTreeOpened(), ; -> can be opened both at the same time
                    this.state.CharacterPanel := this.IsCharacterPanelOpened(),
                    this.state.Waypoint := 0, this.state.Inventory := 0, this.state.Stash := 0
                }   
            ; Ingame options
            Case "0x151513":
                this.State.IngameOptions := 1
            ; Main menu (Online,Offline)
            Case "0x4c4844", "0x685733":
                this.State.MainMenu := 1,
                this.State.GameMode := this.MainMenu.DetectGameMode()
            ; Loading screen
            Case "0x0":
                this.State.Loading := 1
                Sleep 50
            ; No valid state
            Case "":
                ( PixelSearch(1681, 548, 0x414340) ? this.State.NoServer := 1 : this.State.NoValidState := 1 )
        }
        this.TopGui.UpdateTop(),
        this.DebugGui.UpdateBot(),
        Gui.ShowHide()
        DllCall("gdiplus\GdipDisposeImage", "UInt", pBitmap),
        this.base.pBitmap := pBitmap := "",
        this.Runtime := format("{:.2f}", (QPC()-Start)*1000)
        return 
    }

    ; After activating newRun it starts the MFRun sequence, e.g. ["Travincial", "Durance Of Hate Level 2", "River of Flame"]
    ; It starts the active zone timer, and the total timer and selects automatically the waypoint.
    ; At the end of the MF run it appends the data to the log file and creates a new game with the same sequence.
    ; The code is quite quirky, but the idea works very well. It speed ups the runs by a lot.
    newRun() {

        static Area, Timer ; zone counter and timer
        this.Stop()
        
        if !Area { ; init or new run
            if this.State.MainMenu
                this.CreateNewGame()
            Area := 1,
            Timer := [],
            this.ZoneTotal := A_tickCount,
            Timer.push(A_tickcount)
        }
        this.timeAFK := 0
        ;msgbox % "GameMode " this.State.GameMode "`n" "Ingame " this.State.Ingame "`n" "Mainmenu " this.State.Mainmenu  "`n" "MFRun.Count " d2.MFRun.Count()
        ; basically the same run
        if !(Area > d2.MFRun.count()) {
            ; wait for the wp, select the destination
            if !inStr(this.MFRun[Area], "|") {
                zone := d2.MFRun[Area]
            } else {
                zone := strSplit(this.MFRun[Area], "|"), ; e.g. Cold Plains|7 -> players 7
                this.difficulty := diff := zone.2,
                zone := zone.1,
            }
            ;while (this.state.Location!=zone) ; Manual mode, it is possible to detect the states without sending any inputs, maybe later it is a good idea to revert the functionalities
            while (this.state.Waypoint != 1)   ; AutoSelect
                this.getState()
            this.Waypoint.Select(zone),
            this.Start()
            this.MF_Progress := [Area, this.MFRun.count()],
            ; zone start for right gui timer
            Timer.push(A_tickcount),
            ;this.GUILoc := Area "/" d2.MFRun.count() A_space d2.State.Location
            Area++
        } else if (Area > d2.MFRun.count()) {
            ; refresh the log after each completed zone on every hotkey keypress
            this.getLog()
            this.MF_total += 1
            ; the last timestamp
            Timer.push(A_tickCount) 
            ; enum on timer to count the total time of the run
            TotalTimer := 0
            for k, val in Timer {
                if (Timer.Count() > k) {
                    TotalTimer += (timer[k+1]-timer[k]), ; sec
                    LogFile .= this.MF_total "`t"
                             . format("{:.2f}", (timer[k+1]-timer[k])/1000) "`t"
                             . "                 " "`t`t`t" ; date,char,items
                             . (k==1 ? "Town" : (k-1 "/" d2.MFRun.count() " " d2.MFRun[k-1])) "`n"
                }
            }
            characterName := "bceeN"
            LogFile .= this.MF_total "`t"
                    . format("{:.2f}", (A_tickCount - this.ZoneTotal)/1000) "`t"
                    . A_DD "-" A_MM "-" subStr(A_YYYY,3,2) " " A_Hour ":" A_Min ":" A_Sec "`t"
                    . characterName "`t"
                    . this.Items "`t"
                    . this.Elite "`n"
            fileAppend, % logFile, % "MF.txt"
            ; create a new game
            this.SaveAndExit()
            this.CreateNewGame()
            this.Start()
            Area := 0,
            this.MF_Progress := "" ;  [Area, this.MFRun.count()]
            this.Elite := 0
            this.Items := "",
            Timer := [],
            Timer.push(A_tickcount),
            this.ZoneTotal := A_tickCount
        }
        this.TimerStart := A_TickCount
    }

    ; old copied code but does the job at this very moment, implement FileOpen
    getLog() {
        fileRead, file, % A_scriptDir "\MF.txt" 
		this.MF_Today       := 0,
		this.MF_Total_Sec   := 0,
		this.MF_Total_Hours := 0,
		this.MF_Daily_Sec   := 0,
		this.MF_Daily_Hours := 0,
		this.MF_Total       := 0
		loop, parse, file, `n
        {
            if (3>StrLen(A_LoopField)) ; last \n
                continue
			Column := strSplit(A_loopfield, "`t"),
			DD := subStr(Column.3, 1, 2),
			MM := subStr(Column.3, 4, 2),
			YY := subStr(Column.3, 7, 2)
			if (inStr(A_loopfield, "bceeN") && DD = A_DD && MM = A_MM && YY = subStr(A_YYYY, 3, 2)) { ; count total mf today and today's playtime
				this.MF_Today     += 1,
				this.MF_Daily_Sec += Column.2
			}
			this.MF_Total     := Column.1 ; total mf runs and total playtime
			this.MF_Total_Sec += Column.2
            if (strLen(Column.5) > 3) {
                this.lastItem    := Column.5,
                this.lastItemAgo := Column.1
            }
		}
        this.lastItemAgo := this.MF_Total-this.lastItemAgo+1
		this.MF_Total_Hours := format("{:.2f}", this.MF_Total_Sec/3600), ; consider renaming, playtime?
		this.MF_Daily_Hours := format("{:.2f}", this.MF_Daily_Sec/3600),
		this.MF_Total_Sec   := format("{:d}"  , this.MF_Total_Sec),
		this.MF_Daily_Sec   := format("{:d}"  , this.MF_Daily_Sec)
	}

    class Player {
    
        __New() {

            ; chickening can be achieved, but that is a cheat
            this.Health := ""
            this.Mana := ""
            this.Experience := ""

        }    

        class Items {
            ; not really sure if I need it
        }

        class Belt {
            ; there is a hotkey to show the belt, this way the slots can be detected
        }

        class Mercenary {
            ; will copy some old code here, there are only 3 colors for the mercenary healt bar (green, yellow, red)
            ; notification can be triggered if Emilio is being *****
            ; easy to give potion to the Merc with shift + 1-4
        }

    }

    class Inventory {

        __New() {
            
            this.Slot := [],
            this.Slot.SetCapacity(4),
            this.Slot.push([],[],[],[])
            for k, Row in this.Slot {
                this.Slot.setCapacity(10)
                loop 10
                    this.Slot[k][A_index] := ""
            }
            
            iniRead, Inventory, D2.ini, Inventory ; ini file path global
            this.Reserved := []
            for k, v in StrSplit(Inventory, "`n") {
                ; todo, a user can use another delimchar -> use regex, strsplit
                this.Reserved[k] := StrSplit(StrSplit(v, "=")[2]," ")  
            }

            this.TomeOfIdentify := []
            for Row, Rows in this.Reserved {
                for Column, Columns in Rows {
                    if (Columns = "I")
                        this.TomeOfIdentify.push([Row,Column])
                }
            }

            this.Free := ""
            this.Used := ""           
            this.Opened := ""
        }

        ; I played around with detecting colors in another way, this approach is a bit overkill for this task, size can be reduced
        ; 24+24 pixels are checked vertically and horizontally, the inventory colors are similar
        getFreeSpace() {
            static SearchAreaSize := 1
            static Regex := "0x80707|0x60607|0x60605|0x60506|0x50505|0x50504|0x50405|0x50404|"
                          . "0x40405|0x40404|0x40304|0x40303|0x30404|0x30304|0x30303|0x30203"
            Free := 0, Used := 0
            for Row, Rows in this.Slot {
                for Column, Columns in Rows {
                    c := this.getCoord(Row, Column)
                    loop % SearchAreaSize {
                        if ( e := ( ( PixelSearch( -SearchAreaSize//2+A_index+c.x, c.y ) ~= Regex )
                                 && ( PixelSearch(  c.x, c.y-SearchAreaSize//2+A_index ) ~= Regex ) ) ? 0 : 1 )
                            break
                    }
                    this.Slot[Row][Column] := e,
                    Used += e, Free += !e
                }
            }
            this.Used := Used, this.Free := Free
        }

        ; right click on the tome, then left click on the item
        Identify() {
            this.Stop()
            MouseGetPos, x, y
            ; select a random pos
            Random, R, 1, 2
            c := this.getCoord(this.TomeOfIdentify[R][1], this.TomeOfIdentify[R][2])
            click(c.x+Random(-5,5), c.y+Random(-5,5), 1, "Rbutton")
            click(x, y)
            this.Start()
        }

        ; moves only the not protected items to the active stash
        ; atm does not calculate the free space in stash
        MoveToStash() {
            this.Stop()
            ; check if cursor is in the inventory area
            MouseGetPos, x, y
            if (x >= 1693 && 2342 >= x && y >= 738 && 996 >= y) 
                Click(2300, 1025, 0)
            for Row, Rows in this.Slot {
                for Column, Slot in Rows {
                    if this.Reserved[Row,Column] || !this.Slot[Row,Column]
                        Continue
                    c := this.getCoord(Row, Column)
                    Click(c.x, c.y, 0) ; just move
                    Send("{Ctrl Down}", "sleep{25,50}")
                    Click("", "", 1)
                    Send("{Ctrl Up}", "sleep{25,50}")
                }
            }
            this.Start()
        }

        getCoord(Row := 0, Col := 0) {
            static x1 := 1693, y1 := 738, ; ^
                   x2 := 2342, y2 := 996, ; $
                   dx := (x2-x1)/10,
                   dy := (y2-y1)/4
            return { x : ceil(x1+((!Col?Random(1,10):Col)-1)*dx+dx/2)
                   , y : ceil(y1+((!Row?Random(1,10):Row)-1)*dy+dy/2) }
        }
        
        isOpened() {
            return this.Opened := PixelSearch(1699, 1026, 0xb0b0c)
        }

    }

    class Stash {

        __New() {
            
            ; one stash tab contains 10x10 slots in D2R
            this.Tab := [[],[],[],[]]
            for each, Tab in this.Tab {
                loop 10 {
                    Tab[(i:=A_index)] := [],
                    loop 10
                        Tab[i][A_index] := 0
                }
            }

            this.Free := ""
            this.Used := ""
            this.Reserved  := ""
            this.ActiveTab := ""
            this.Opened := ""

        }

        ; detects if stash is opened, then gets the active tab
        isOpened() {
            if !PixelSearch(860, 1027, 0xd0c0f)
                return this.Opened := 0
            static x := 235, y := 270, dx := 165, Colors := [0x2e2e32,0x313335,0x2c2d30,0x2d2f31]
            for k, v in Colors
                if PixelSearch(x+(A_index-1)*dx,y,Colors[A_index])
                    return (this.Opened := 1, this.ActiveTab := A_index)
        }

        ; select a stash tab
        TabSelect(Tab) {
            this.Stop()
            if (Tab > 0) || (5 > Tab)
                Click(--Tab*165+250+Random(-15,+15), 270+Random(-5,5), 1)
            this.Start()
        }

        ; scroll trough the tabs
        TabScroll() {
            this.Stop()
            if !d2.State.Stash
                return this.Start()
            Tab := this.ActiveTab
            if (A_thisHotkey ~= "Up|Tab" )
                (++Tab = 5) ? Tab := 1 : ""
            else if (A_thisHotkey ~= "Down")
                (--Tab == 0) ? Tab := 4 : "" 
            Click(--Tab*165+250+Random(-15,+15), 270+Random(-5,5), 1)
            this.Start()
        }

        ; would be a lot nicer to use color distance I think
        getFreeSpace() {
            static Regex := "0xf0f10|0xf0e0f|0xf0d0f|0xf0c10|0xf0c0f|0xe0d0f|0xe0d0e|0xe0c0d|0xd0b0e|0xd0b0d|0xc0c0c|0xc0a0e|0xb090b|"
                          . "0x161516|0x161416|0x151515|0x151415|0x151414|0x151214|0x141414|0x141314|0x141313|0x141214|0x141212|0x141113|"
                          . "0x131313|0x131213|0x131113|0x131112|0x131013|0x131012|0x130f11|0x130e13|0x121213|0x121212|0x121112|0x121111|"
                          . "0x121012|0x121011|0x120f10|0x111111|0x111013|0x111012|0x111011|0x111010|0x110f12|0x110f11|0x101111|0x101010|"
                          . "0x100f10|0x100f0f|0x100e12|0x100e11|0x100e10|0x100d10|0x100c0f"
            Free := 0, Used := 0           
            for Row, Rows in this.Tab[this.ActiveTab] {
                for Column, Columns in Rows {
                    c := this.getCoord(Row, Column)
                    e := ( (PixelSearch(c.x, c.y) ~= Regex)
                        && (PixelSearch(c.x, c.y) ~= Regex) ? 0 : 1 )
                    this.Tab[this.ActiveTab][Row][Column] := e,
                    Used += e, Free += !e
                }
            }
            this.Free := Free, this.Used := Used
        }

        ; the area start and end points are used for the calculations
        getCoord(Row := 0, Col := 0) {
            static x1 := 218, y1 := 297, x2 := 868, y2 := 947, dx := (x2-x1)/10, dy := (y2-y1)/10,
            return { x : ceil(x1+((!Col?random(1,10):Col)-1)*dx+dx/2)
                   , y : ceil(y1+((!Row?random(1, 4):Row)-1)*dy+dy/2) }
        }

    }

    class Waypoint {

        static Zones := [ [ "Rouge Encampment"  , "Lut Gholein"               , "Kurast Docks"            , "The Pandemonium Fortress" , "Harrogath"               ]
                        , [ "Cold Plains"       , "Sewers Level 2"            , "Spider Forest"           , "City Of The Damned"       , "Frigid Highlands"        ]
                        , [ "Stony Field"       , "Dry Hills"                 , "Great Marsh"             , "River Of Flame"           , "Arreat Plateau"          ]
                        , [ "Dark Wood"         , "Halls Of The Dead Level 2" , "Flayer Jungle"           ,                            , "Crystalline Passage"     ]
                        , [ "Black Marsh"       , "Far Oasis"                 , "Lower Kurast"            ,                            , "Glacial Trail"           ]
                        , [ "Outer Cloister"    , "Lost City"                 , "Kurast Bazaar"           ,                            , "Halls Of Pain"           ]
                        , [ "Jail Level 1"      , "Palace Cellar Level 1"     , "Upper Kurast"            ,                            , "Frozen Tundra"           ]
                        , [ "Inner Cloister"    , "Arcane Sanctuary"          , "Travincial"              ,                            , "The Ancients Way"        ]
                        , [ "Catacombs Level 2" , "Canyon Of The Magi"        , "Durance Of Hate Level 2" ,                            , "Worldstone Keep Level 2" ] ]

        __New() {
            this.Act  := "", this.Zone := "", this.Name := "", this.Opened := ""
        }

        ; just a sketch, would be good to scrool trough the waypoints
        ; a modifier could be used to switch between Acts
        Scroll() {
            this.Stop()
            Zone := this.Zone
            if (A_thisHotkey ~= "Up")
                (++Zone = 10) ? Zone := 1 : ""
            else if (A_thisHotkey ~= "Down")
                (--Zone == 0) ? Zone := 9 : ""
            this.Select(this.Act,Zone)    
            this.Start()
        }

        ; a new waypoint can be called by name or an Act-Zone pair (5,1 -> Harrogath)
        Select(Name, id := "") {
            this.Stop()
            ; else the same place
            if (Name = this.Act) && (id = this.Zone) ; called by id, 2,1
            || (Name = Zones[this.Zone][this.Act] && id == "") ; called by name Harrogath = 5,1   
                return (-1, this.Start())
            ; call by random, zone name or Act, Zone in digits
            else if (Name ~= "^[1-5]$" && id ~= "^[1-9]$") {
                this.Zone := Name, this.Act := id
            } else if (Name ~= "i)^Random$" && Zone == "") {
                this.Zone := Random(2, this.Zones.count()), ; 2 = exclude town
                this.Act  := Random(1, this.Zones[this.Zone].count()),
            } else if (id=="") {
                for e, Zone in this.Zones {
                    for k, _Name in Zone {
                        if (Name=_Name) {
                            this.Act := k,
                            this.Zone := e ; act
                            break
                        }
                    }
                }
            }
            if (this.Act != this.before) {
                x1 := 257, x2 := 371, dx := 114
                Random, x, % x1+(this.Act-1)*dx+10, % x1+(this.Act)*dx-10
                y1 := 279+5, y2 := 309-5,
                Random, y, % y1+20 , % y2-20
                click(x, y)
                sleep(100,200)
            }
            ; this is only for the zone part
            x1 := 380, x2 := 800
            Random, x, % x1, % x2
            y1 := 319+(this.Zone-1)*78+35, y2 := 319+78*this.Zone-35
            Random, y, % y1, % y2
            Click(x, y, 0)
            sleep(100,200)
            AHI.SendMouseButtonEvent(d2.base.mouseID, 0,  1)
            ; sometimes the selected waypoint location is not detected ( buggy )
            while (d2.state.Location!=Name)
                d2.getState()
            sleep(100,200)
            this.Start()
            AHI.SendMouseButtonEvent(d2.base.mouseID, 0, 0)             
            ; continue the state
        }

        Close() {
		    if this.State.Waypoint {
			    Send("{Escape}", "sleep{25,50}")
                this.State.Waypoint := 0
            }
	    }

        ; also detects the active and selected waypoint
        isOpened() {

            static Act := { 1 : [ 287, 295, 0x201e1a ]   
                          , 2 : [ 395, 294, 0x1d1b16 ]
                          , 3 : [ 513, 294, 0x1f1d19 ]
                          , 4 : [ 628, 296, 0x201e1a ] 
                          , 5 : [ 746, 294, 0x1f1d19 ] }

                  , BlueColors := "0x94cbff|0x92caff|0x90c9ff|0x909090"
                  , SelectedColors :=  "0xc0c0c|0xb0c0c|0xd0d0e|0xe0e0f"
                  , x := 319, y1 := 315, y2 := 1057, z := 9, dy := (y2-y1)/9

            ; waypoint is not opened
            if !this.Opened := PixelSearch(523, 205, 0xc7b377)
                return 0
            ; get the state of the wp
            for k, v in Act {
                if PixelSearch(v.1,v.2,v.3) {
                    this.Act := this.before := k
                    break
                }
            }
            ; get active waypoint
            loop 9 {
                if (PixelSearch(x,ceil(y1+dy/2+(A_index-1)*dy)) ~= BlueColors) {
                    this.Zone := A_index
                    break
                }
            }
            
            ; get selected waypoint
            loop 9 {
                if (PixelSearch(x,ceil(y1+dy/2+(A_index-1)*dy)) ~= SelectedColors) {
                    this.Zone := A_index
                    break
                }
            }
            this.Name := this.Zones[this.Zone][this.Act]
            return this.Opened := 1
        }

    }

    ; not really sure if another class is needed
    class MainMenu {

        DetectGameMode() {
            if PixelSearch(2320, 69, 0x272629)
                Mode := "Offline"
            else if PixelSearch(2264, 70, 0x2b2c2f)
                Mode := "Online" 
            return Mode
        }

        OpenLobby() {
            click(Random(1297, 1692), Random(1247, 1333))
        }

        SelectDifficulty(Difficulty := "Normal") {
            static Difficulties := {Normal : "R", NightMare : "N", Hell : "H"}
            Send(Difficulties[Difficulty])           
        }

    }

    IsSkillTreeOpened() {
        return PixelSearch(1722, 1078, 0xa0a0b)
    } 

    IsCharacterpanelOpened() {
        return PixelSearch(734, 950, 0xbfbfbf)
    }

    ; a quick way to open the advanced stats
    AdvancedStats() {
        this.Stop()
        AHI.MoveCursor(907, 633, "Window", D2R.mouseID)
        AHI.SendMouseButtonEvent(D2R.mouseID, 0, 1)
        AHI.SendMouseButtonEvent(D2R.mouseID, 0, 0)
        this.Start()
    }

    ; just another idea, a way to count elites manually
    EliteCounter() {
        if !this.Elite
            this.Elite := 0
        (!inStr(A_thisHotkey,"+")) ? ++this.Elite : --this.Elite
    }

    ; currently created a game with the active gamemode
    CreateNewGame() {
        this.Stop()
        static coords := { Online : [865,1248,1261,1331], Offline : [1080,1270,1476,1358] }
        click(Random( coords[this.state.GameMode].1, coords[this.state.GameMode].3), Random(coords[this.state.GameMode].2, coords[this.state.GameMode].4))
        sleep(200, 500)
        this.MainMenu.SelectDifficulty("Hell")
        t := A_TickCount
        while (this.state.Ingame!=1) {
            this.getState()
            if (A_tickCount-t>10000)
                return (0, this.Start())
            Sleep 200
        }
        this.Start()
    }

    SelectCharacter() {
        ; the character name can be selected, a group of pixels can identify it the character name
    }

    SelectGameMode(Mode := "") {
        static Coord := { Online : [2075,47,2287,85], Offline : [2296, 47, 2509, 85] }
        if (Mode = this.State.GameMode)
            return
        else if (Mode = "")
            Mode := (this.State.GameMode = "Online" ? "Offline" : "Online" )
        else if (Mode ~= "i)Online|Offline" )
            Mode := this.State.GameMode
        Random, x, % Coord[Mode].1, % Coord[Mode].3
        Random, y, % Coord[Mode].2, % Coord[Mode].4
        Click(x, y)
        return this.Gamemode := Mode
    }

    SaveAndExit() {
        this.Stop()
        ; sometimes an extra escape is needed
		if this.State.Waypoint || this.State.Stash || this.State.Inventory || this.State.Skilltree || this.State.CharacterPanel
			Send("{Escape}", "sleep{299,499}")
        ; mouse cursor can interfere with the menu ( cursor position can 'autoselect' a submenu e.g. options )
        ; only 3 submenus exist when you press the escape
        Random, UpDn, 0, 1
	Send( "{Escape}", "sleep{99,150}" 
	    , "{" (UpDn ? "Down" : "Up") " 2}"
	    , "{" (UpDn ? "Up"   : "Down") "}",
	    , "{Enter}" )
        while (this.state.MainMenu != 1)
            this.getState(), sleep(200)
        this.Start()    
	}

    Start(Period := 10) {
        fn := this.fn
        setTimer, % fn, % Period
    }

    Stop() {
        fn := this.fn
        setTimer, % fn, Off
    }

    Run(Mode := "Offline") {
        if !FileExist(this.ExePath this.ExeName)
            return 0
        if !WinExist(this.WinTitle)
            Startup := 1
        if (Mode = "Online"){
            Exe := this.ExeLauncher ; currently needed to run manually
            ;if !Launcher.exist()
            ;    new Launcher()
        } else if (Mode = "Offline") {
            Run, % this.ExePath this.ExeName
            WinWaitActive, % this.WinTitle,, 2
        }
        if ErrorLevel
            MsgBox,, % " ", % "Failure on D2R.exe startup."
        ; bypass the intros until main menu appears
        if StartUp {
            loop 4 {
                (A_index ~= "1|3") ? Sleep(1000) : ""
                this.getState()
                if this.State.MainMenu
                    return
                Click()
            }
        }
    }

    Close() {
        WinClose, % "ahk_id" winExist(this.WinTitle)
        WinWaitClose, % "ahk_id" winExist(this.WinTitle),, 5
    }

    Restart() {
        this.Close(), this.Run()
    }

    Activate() {
        if !WinActive("ahk_id" this.hWnd) {
            WinActivate, % "ahk_id" this.hWnd
            WinWaitActive, % "ahk_id" this.hWnd,, 3
            return ErrorLevel ? 0 : 1   
        }
    }

    Minimize() {
        WinMinimize, % "ahk_id" this.hWnd
    }

    Show() {
        winRestore, % "ahk_id" this.hWnd
    }

    ; in case of you changed the contrast or gamma settings
    RestoreDefaultSettings() {
        if !FileExist((File := "C:\Users\" A_UserName "\Saved Games\Diablo II Resurrected\Settings.JSON"))
            Msgbox,, % " ", % "...\Settings.JSON file is not found."
        FileMove, File, % subStr(File, 1, -5) "_" A_DD A_MM subStr(A_YYYY, 3, 2) ".JSON"
        FileDelete, File
    }

    getProgramPath() {
        loop, files, % A_programFiles (!inStr(A_programFiles,"(x86)") ? " (x86)" : "") . "\*", D ; almost instant
            if inStr(A_loopFileName,"Diablo II Resurrected") {
                this.base.filePath := A_loopfileFullPath
                break
            }
        if !this.FilePath { ; try RegRead
            loop, Reg, % "HKLM\SOFTWARE\", KR
            {
                if (A_LoopRegName = "Diablo II Resurrected") {
                    RegRead, Path, % A_LoopRegKey "\" A_LoopRegSubKey "\" A_loopRegName, % "InstallLocation" ; ~1200 ms
                    this.base.FilePath := Path
                    break
                }   
            }
        }
        if fileExist(this.filePath "\Diablo II Resurrected Launcher.exe")
            this.base.LauncherPath := this.filePath "\Diablo II Resurrected Launcher.exe"
        if fileExist(this.filePath "\D2R.exe")
            this.base.FilePath := this.filePath "\D2R.exe"
        return (this.FilePath && this.LauncherPath) ? 1 : 0
    }

    ; Unfortunately, Gdip_BitmapFromScreen(:hWnd) does not work
    ; it is important to know which screen is used for the game
    getActiveMonitor() {
        WingetPos, x, y, w, h, % "ahk_id" this.hWnd
	SysGet, MonitorCount, 80
	loop, % MonitorCount {
	    SysGet, MonitorWorkArea, MonitorWorkArea, % A_Index
            if (x = MonitorWorkAreaLeft)
                return A_index
	}		
    }
	
    __New() {
       
        this.base.WinTitle := "Diablo II: Resurrected" 
        . " ahk_class" this.base.WinClass:= "OsWindow"
        . " ahk_exe"   this.base.ExeName :=  "D2R.exe"
        
        this.base.ExePath := "C:\Program Files (x86)\Diablo II Resurrected\"
        this.base.ExeLauncher := "Diablo II Resurrected Launcher.exe"
        this.base.SendMode := "AHI"
        this.base.Autorun := 1
        if !this.getProgramPath()
               return
        
        this.base.pGdipToken := Gdip_Startup()
        this.base.hWnd := winExist(this.WinTitle)
        this.base.ActiveMonitor := this.getActiveMonitor()
        ; anything higher than AboveNormal is unnecessary
        process, priority, % DllCall("GetCurrentProcessId"), AboveNormal 
        
        ; create screenshot folder
        if !inStr(fileExist((this.base.ScreenPath := A_scriptDir "\" "screenshots")),"D")
            fileCreateDir, % this.ScreenPath
        
        this.DebugGui  := new Gui(7, 320, 175, 600, "DebugGui")
        this.TopGui    := new Gui(0, 0, 2560, 40, "TopGui")      
        this.Inventory := new this.Inventory
        this.Stash     := new this.Stash
        this.Waypoint  := new this.Waypoint
        this.State := {}
        this.getLog()
        
        ; the easiest way just join to a running instance of d2
        if this.base.Autorun
            this.Run("Offline")
        fn := ObjBindmethod(this, "getState")
        this.fn := fn
        ; bind start, stop methods to subclasses
        for k, cls in ["Inventory", "Waypoint", "Stash"]
            for e, v in ["Start", "Stop"]
                this[cls][v] := objBindMethod(this, v)
        ; start the state timer
        setTimer, % fn, 10
        ; shutdown Gdip
        OnExit(ObjBindMethod(this, "ShutDown"))
    }

    Shutdown() {
        if this.pBitmap {
            Gdip_disposeImage(this.pBitmap)
            this.base.pBitmap := ""
        }
        GDIP_Shutdown(this.pGdipToken)
    }

    version() {
        return "0.1.2"
    }

}

; ####################################################################################

class GUI {

    __New(x, y, Width, Height, Name) {
        
        Gui, New
		Gui, %Name%:Default
		Gui, +E0x80000 -Caption +AlwaysOnTop +ToolWindow +hWndhWnd ; +E0x20
		Gui, Show, NA

        this.x := x
        this.y := y
        this.w := Width
        this.h := Height
        this.hWnd := hWnd
    }

    ; Again old code, but does the job, the top GUI shows data to the user about previous runs and measures the active run
    UpdateTop() {
        
        static OptionCenter :=     "Centre vCentre cFFFF0000 R1 S12"
             , OptionLeft   := "x10 Left   vCentre cFF8C8C8C R1 S12"
             , OptionRight  := "x10 Right  vCentre cFF7C7C7C R1 S12"
             , Background := 0x8C000000
             , Font := "Tahoma"
                
        ; create the texts
	Time := A_TickCount-d2.TimerStart-d2.TimeAFK,
	Sec := Time//1000,
	Ms := Format("{:03}", mod(Time, 1000)),
	if !(1000 > Time)
	    time := Sec " s " Ms " ms "
	if !D2.state.ingame
	    time := "zZz" ;, D2.TimeAFK += RefreshRate -> should be fixed
        if D2.state.Location {
	    Loc    := " [ " D2.State.Location " ] ",
	    Zone   := (D2.ZoneTotal)   ? " [ " format("{:.1f}", (A_tickCount-D2.ZoneTotal)/1000) " ] " : "",
	    Mfprog := (D2.MF_Progress) ? " [ " D2.mf_progress.1 " / " D2.mf_progress.2 " ] " : "",
	    Loc    := Loc Zone Mfprog
	}
        if D2.state.InventoryFree
            Inv := " [ I " d2.State.InventoryFree " ]"
        if D2.State.StashFree
	    Stash := " [ S" d2.State.StashTab " " D2.State.StashFree " ]"  ;. "[ tabs free " . D2.stash.free.1 . " " . D2.stash.free.2 . " " . D2.stash.free.3 . " " . D2.stash.free.4 . " ]"
		
        txtCenter := " [ " A_Hour " " A_Min " " A_Sec " ] " "  " time,
	txtLeft := "[ ?? " D2.MF_total " ] [ Today " D2.MF_today " ] [ " "bceeN" " ] [ Last Item " D2.LastItem " " D2.LastItemAgo " runs ago ]" Inv Stash,
	txtRight := Loc "[ ?? " D2.MF_Total_Hours " h" " | ?? daily " D2.MF_Daily_Hours " h | RPAWR.com ]",
       
        ; base bitmap
	hbm := CreateDIBSection(this.w, this.h),
	hdc := CreateCompatibleDC(),
	obm := SelectObject(hdc, hbm),
	G := Gdip_GraphicsFromHDC(hdc),
	Gdip_SetSmoothingMode(G, 4),
	; create the background
	pBrush := Gdip_BrushCreateSolid(Background),
	Gdip_FillRoundedRectangle(G, pBrush, 0, 0, this.w, this.h, 0),
	Gdip_TextToGraphics2(G, txtCenter, OptionCenter, Font, this.w, this.h),
	Gdip_TextToGraphics2(G, txtLeft,   OptionLeft,   Font, this.w, this.h),
	Gdip_TextToGraphics2(G, txtRight,  OptionRight,  Font, this.w-10, this.h),
	; update the gui window
	UpdateLayeredWindow(this.hWnd, hdc, this.x, this.y-1, this.w, this.h),
	; delete resources
	Gdip_DeleteBrush(pBrush),
	SelectObject(hdc, obm),
	DeleteObject(hbm),
	DeleteDC(hdc),
	Gdip_DeleteGraphics(G)
    }
	
    ShowHide() {
        static GuiState
        if !GuiState && (d2.state.active || winActive("ahk_id" d2.TopGui.Hwnd) || winActive("ahk_id" d2.DebugGui.Hwnd)) {
            WinShow, % "ahk_id" d2.TopGui.Hwnd
            WinShow, % "ahk_id" d2.DebugGui.Hwnd
            GuiState := 1
	}
	else if GuiState && (!d2.state.active && !winActive("ahk_id" d2.TopGui.Hwnd) && !winActive("ahk_id" d2.DebugGui.Hwnd)) {
            winHide, % "ahk_id" d2.TopGui.Hwnd
            winHide, % "ahk_id" d2.DebugGui.Hwnd
            GuiState := 0
	}
    }
	
    AddItemToRun() {
	InputBox, Item, % " ", % "Items: ",, 320, 125
	(!d2.Items) ? d2.Items := Item : d2.Items .= ", " Item
	d2.Activate()
    }

    UpdateBot() {    

        static OptionTitle := "y15        Centre cFFFFFFFF R1 S12"
             , OptionKey   := "x10 vCentre  Left cFF8C8C8C R1 S12"
             , OptionValue :=     "vCentre Right cFF32CD32 R1 S12"  
             , OptionFont  := "Tahoma"

        static BackgroundColor := 0x7C000000
        txt := [ [ "Exist"     , d2.state.Exist               ]
               , [ "Active"    , d2.state.Active              ], [ ]
               ;, [ "Screen"    , d2.state.ScreenSize          ]
               ;, [ "Pos"       , d2.state.Position            ]
               , [ "Ingame"    , d2.state.Ingame              ], [ ]
               , [ "CharPanel" , d2.state.CharacterPanel      ]
               , [ "Skilltree" , d2.state.Skilltree           ], [ ]
               , [ "Inventory" , d2.state.Inventory           ]
               , [ "Inv. free" , d2.state.InventoryFree       ], [ ]
               , [ "Stash"     , d2.state.Stash               ]
               , [ "Active Tab", d2.state.StashTab            ]
               , [ "Stash free", d2.state.StashFree           ], [ ]
               , [ "Waypoint"  , d2.state.Waypoint            ]
               , [ "Act"       , d2.state.Act                 ]
               , [ "Zone"      , d2.state.Zone                ]
               , [ "Loc"       , d2.state.Location            ], [ ]
               , [ "Options"   , d2.state.IngameOptions       ]
               , [ "Main menu" , d2.state.MainMenu            ]
               , [ "Game mode" , d2.state.GameMode            ]
               , [ "Loading"   , d2.state.Loading             ]
               , [ "No server" , d2.state.NoServer            ]
               , [ "No state"  , d2.state.NoValidState        ] , [ ]
               , [ "Runtime"   , d2.RunTime " ms"             ]
               , [ "Script"    , getMemoryUsage("Script") " MB"] ] 
               ;, [ "Application", getMemoryUsage("ahk_exe D2R.exe")   ] ]
        for k, v in txt
                txt1 .= v.1 "`n", txt2 .= v.2 "`n"
        txt1 := subStr(txt1, 1, -1), txt2 := subStr(txt2, 1, -1)
        ; base bitmap
        hbm := CreateDIBSection(this.w, this.h),
        hdc := CreateCompatibleDC(),
        obm := SelectObject(hdc, hbm),
        G := Gdip_GraphicsFromHDC(hdc),
        Gdip_SetSmoothingMode(G, 4),
	; create the background
        pBrush := Gdip_BrushCreateSolid(BackgroundColor),
        Gdip_FillRoundedRectangle(G, pBrush, 0, 0, this.w, this.h, 0),
        Gdip_TextToGraphics2(G, "RPAWR", OptionTitle, OptionFont, this.w, this.h),
        Gdip_TextToGraphics2(G, txt1,    OptionKey,   OptionFont, this.w, this.h),
        Gdip_TextToGraphics2(G, txt2,    OptionValue, OptionFont, this.w-15, this.h),
        ; update the gui window
        UpdateLayeredWindow(this.hWnd, hdc, this.x, this.y, this.w, this.h),
        ; delete resources
        Gdip_DeleteBrush(pBrush),
        SelectObject(hdc, obm),
        DeleteObject(hbm),
        DeleteDC(hdc),
        Gdip_DeleteGraphics(G)
        return
    }
    
}

; ####################################################################################

PixelSearch(x, y, Compare := 0, pBitmap := 0) {
    DllCall("gdiplus\GdipBitmapGetPixel", "UInt", (!pBitmap?d2.pBitmap:pBitmap), "int", x, "int", y, "uint*", ARGB)
    SetFormat, IntegerFast, Hex 
    Hex := ARGB & 0x00ffffff, Hex .= ""
    SetFormat, IntegerFast, D
    return (Compare == 0 ? Hex : ( Compare = Hex ? 1 : 0 ))
}

; #####################################################################################

; AHI Mouse and keyboard wrapper, easier to use multiple actions
; e.g. Send("{LeftButton 2}","sleep{200,500}", "{Enter}", "MouseMove x200 y200")
Send(commands*) {

    static keypressDelay := [ 25, 50 ]
    static keypressDur   := [  1, 10 ]
    static mouseDelay    := [ 25, 50 ]
    static mouseDur      := [ 25, 50 ]
    static mouseSpeed    := [ 20, 50 ]

    for k, cmd in commands {
		; if the command is sleep
        if (cmd ~= "i)^s(leep)?{?\d+(,\d+)?}?") { ; allows using sleep{\d}
            RegExMatch(cmd, "\d+(,\d+)?", ms)
			sleep((ms := StrSplit(ms, ","))[1], ms[2])
        } else {
            if (d2.state.SendMode = "AHI") { 
                ; if the key contains an event {}, removes it, and parse forward the cmd
                if (cmd ~= "^\{.+\}$") {
                    RegexMatch(cmd, "[^\{]\w+(\s?(\w+|\d+)?)[^\}]", cmd)
                    Key := RegExReplace(cmd, "\s?(D(ow)?n|Up|1|0|\d+)$")
                    Event := ((cmd ~= "i)\s?D(ow)?n$|\|1$") ? 1
                           :  (cmd ~= "i)\s?Up$|\|0$")      ? 0 : "")
                    E := !(Event == "") ? 1 : 0 
                    (cmd ~= "\s?\d+$") ? RegExMatch(cmd, "\d+", Repeats) : Repeats := 1
                    ;msgbox % "1 " cmd "`n" "2 " key "`n" "3 " event "`n" "4 " repeats
                } else {
                    Key := cmd ; standard chr
                    Chrs := (strLen(cmd) > 1) ? StrSplit(cmd) : [cmd]
                }
                
                ; Mouse buttons
                if (Key ~= "i)^(L(eft)?|R(ight)?|M(iddle)?)\s*(Click|button)$|^(Xbutton|Side)\d$") {
                    Key := (Key ~= "i)L((eft)?\s*(Click|button))|Click\s?L(eft)?")      ? "0"
                         : (Key ~= "i)R((ight)?\s*(Click|button))|Click\s?R(ight)?" )   ? 1
                         : (Key ~= "i)M((iddle)?\s*(Click|button))|Click\s?M(iddle)?" ) ? 2
                         : (Key ~= "i)(X(button)?|side)1|Click\s?X1?" )                 ? 3 ; UP/DOWN?
                         : (Key ~= "i)(X(button)?|side)2|Click\s?X2?" )                 ? 4 
                         : (Key ~= "i)(M(ouse)?)?\s*WheelUp?" )                         ? 5 ; 5: Wheel (Vert), 6: Wheel (Horiz)
                         : (Key ~= "i)(M(ouse)?)?\s*WheelD(own|n)?")                    ? 6 : ""
                    sendMouse := (Key ~= "[0-6]") ? 1 : 0
                }
                else if ( key ~= "i)(Click|(Mouse)?(Move)?)\s?(x?\d{1,4}.?)?(y?\d{1,4})" ) {
                        RegExMatch(key, "i)x\s?\d{1,4}", x)
                        RegExMatch(key, "i)y\s?\d{1,4}", y)
                        x := RegExReplace(x, "x")
                        y := RegExReplace(y, "y")
                        WinGetPos,,, w, h, A
                        if (x > w || y > h)
                            return
                        AHI.MoveCursor(x, y, "Window", d2.state.mouseID)
                        sleep(mouseSpeed.1, mouseSpeed.2)
                        ; only move
                        if !(key ~= "i)Click")
                            continue
                }

                Method := sendMouse ? "SendMouseButtonEvent" : "SendKeyEvent",
                Device := sendMouse ? d2.MouseID : d2.KeyboardID
 
                ; ugly loop for wrapping the two devices
                loop % (!Repeats ? 1 : Repeats) {
                    for i, val in (!Chrs ? [key] : Chrs) { ; AHI can send only 1 char/call
                        Key := sendMouse ? Key : getKeySC(val)
                        loop % (!E ? 2 : 1) {
                            AHI[Method](Device,Key,(!E?(A_index==1?1:0):Event)),
                            (!sendMouse)? sleep(keypressDur.1, keypressDur.2)
                                        : sleep(mouseDur.1, mouseDur.2)
                        }
                        ;(!sendMouse)?sleep(keypressDelay.1,keypressDelay.2) ; a bit of extra delay
                        ;            :sleep(mouseDelay.1,mouseDelay.2)
                    }
                }
            }
            else ; use the standard sendmode
                send, % cmd
        }
    }
}

;#####################################################################################

; AHI Mouse Click wrapper
Click(x := "", y := "", Clicks := 1, MButton := 0) {
    static buttons := { ""
        . 0 : "L(button|eft)?"
        , 1 : "R(button|ight)?"
        , 2 : "M(button|iddle)?"
        , 3 : "(X(button)?|side)1"
        , 4 : "(X(button)?|side)2" }
        ;, 5 : "M?(ouse)?WheelUp?" ; 5: Wheel (Vert), 6: Wheel (Horiz)
        ;, 6 : "M?(ouse)?WheelD(own|n)?" }
    if !buttons.Haskey(Mbutton) {
        for k, regex in buttons
            if RegexMatch(Mbutton,"i)" regex)
                Mbutton := k
    }    
    if (x && y)
	AHI.MoveCursor(x, y, "Window", D2R.mouseID)
    else if (x > 1 && y == "")
        Clicks := x   
	loop % Clicks {
	    AHI.SendMouseButtonEvent(D2R.mouseID, Mbutton, 1)
	    Sleep(25, 50)
	    AHI.SendMouseButtonEvent(D2R.mouseID, Mbutton, 0)
	    if (Clicks > 1)
	        Sleep(25, 50)
	}
}

;#####################################################################################

; would be handy to select another stash tab from the inventory
MouseMoveBack(mousex := "", mousey := "", timer := "") {
    if !mousex && !mousey
        MouseGetPos, mousex, mousey
    mousex += Random(-50, 50),
    mousey += Random(-25, 25),
    fn := func("Click").bind(mousex,mousey,0)
    setTimer, % fn, % - (!timer) ? random(333, 666) : timer
}

;#####################################################################################

; for checking colors
MouseGetPixel(x := "", y := "", folderPath := "", dbg := 1) {	
    scrn := Gdip_BitmapFromScreen(1)
    if (x == "" && y == "")
        mousegetpos, x, y,,, A
    out .= x ", " y ", " ARGBtoRGB(GDIP_getPixel(scrn,x,y)) 
    if dbg {
	if !folderPath
	    folderPath := A_scriptDir . "\screenshots"
	if !inStr( fileExist( folderPath ), "D" )
	    fileCreateDir, % folderPath
	loop, files, % folderPath "\" "*.png"
	    fileName := A_index
	Gdip_SaveBitmapToFile(scrn, folderPath "\" ( !fileName ? 1 : ++fileName ) ".png", 100 )
    }
    Gdip_DisposeImage(scrn)
	if dbg
	    msgbox,,, % clipBoard := out, .74
	return out
}

; ####################################################################################

; currently the script eats 40+ MB which is a lot :(
GetMemoryUsage(processName := "Script") {
    ; credit: https://github.com/jNizM
    if (processName = "Script")
        PID := DllCall("GetCurrentProcessId")
    else        
        winGet, PID, PID, % processName
    hProcess := DllCall("OpenProcess", UInt, 0x10|0x400, Int, false, UInt, PID),
    PROCESS_MEMORY_COUNTERS_EX := VarSetCapacity(PMCE, 80, 0) ; 44 32bit
    DllCall("psapi.dll\GetProcessMemoryInfo", UInt, hProcess, UInt, &PMCE, UInt, PROCESS_MEMORY_COUNTERS_EX)
    DllCall("CloseHandle", UInt, hProcess)
    bytes := NumGet(PMCE, 72, "UInt") ; 32bit 56 || 72 64 bit
	return Format("{:.2f}", bytes/1024/1024) 
}

; ####################################################################################

ARGBtoRGB(ARGB) {
    ; credit should be added
    SetFormat, IntegerFast, Hex
    ARGB := ARGB & 0x00ffffff, ARGB .= ""
    SetFormat, IntegerFast, D
    return ARGB
}

;#####################################################################################

Sleep(Min := 0, Max := 0) {
    if Max
      Random, Min, % Min, % Max
    Sleep, % Min
}

;#####################################################################################

Random(x, y) {
    Random, r, % x, % y
    return r
}

;#####################################################################################

QPC() {
  ; credit: https://github.com/G33kDude
  VarSetCapacity(PerformanceCount, 8, 0)
  VarSetCapacity(PerformanceFreq, 8, 0)
  DllCall("QueryPerformanceCounter", "Ptr", &PerformanceCount)
  DllCall("QueryPerformanceFrequency", "Ptr", &PerformanceFreq)
  return NumGet(PerformanceCount, 0, "Int64") / NumGet(PerformanceFreq, 0, "Int64")
}

;#####################################################################################
