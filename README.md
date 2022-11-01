# D2 Reconsidered

![D2R_Youtube_intro](https://user-images.githubusercontent.com/105103590/198849918-91a6d0a3-5b1b-41f7-aee6-fa9a69e90aa9.png)

*"Ah, welcome back, my friend."* - I am Bence and I love Diablo II.

D2 Reconsidered is an AutoHotkey script to reduce unnecessary mouse clicks and other repetitive actions in Diablo 2.

The script is able to function as a RunCounter.

--

**The script is mostly intended for learning purposes, I absolutely do not advocate cheating.**

**Cheating is lame!**

--

*I tried to complete the Holy Grail challenge a few years ago.*

*It was fun, but that's when I got the idea to mess with D2 and AutoHotkey.*

*If you're doing an offline challenge, it's up to you to make your own rules.*

*Personally, I'd rather run multiple MFs at the same time than move the mouse over the same routes over and over again.*

*Sometimes I'm also very disorganized, the available data helps me concentrate and do quicker runs.*

*Seeing progress towards your goals is always helpful for gaining morale.* :)

- 31.10.2022 - v0.1.2
- 29.10.2022 - first release, v.0.1.0

## Download

- currently optimized for using with AutoHotInterception: https://github.com/evilC/AutoHotInterception (thank you evilC!)
- Gdip_All.ahk is required
- only 2560x1440 is supported atm

## Features

![image](https://user-images.githubusercontent.com/105103590/198850180-7a503484-1aad-4c14-998d-52be2f061859.png)

- Capable of automating actions, e.g. automatically selecting waypoints by Name
- Detect free slots in Stash, Inventory, active StashTab
- Capable of moving items from the inventory to Stash
- Able to create games at the end of the MF runs automatically
- RunCounter function, logs each zones during the runs and stores it in a simple txt file
- GDI+ overlay GUI to display stats on the top of the screen ( total played run, total played today, total in hrs, last found item etc... )
- Does not read/write memory
- ...

--

*I suggest watching the following videos in full screen for a better understanding:*

## video Diablo 2 Resurrected MF Run Counter - update

[![D2Rethinked_video1](https://user-images.githubusercontent.com/105103590/198850686-3305c2c7-94be-4636-930e-c6926a8375cf.png)](https://www.youtube.com/watch?v=bJDbMRvM6TA)

Some more content from the previous version.

- New GUI, stash functions, active stash tab
- Selecting stash tabs with the mouse wheel
- Testing active stash tab's free space function
- Testing stash all free space function
- Move items from inventory to stash ( random order  )
- Detecting location, waypoint
- Auto setting players command after waypoint

## video Diablo 2 Resurrected: MF run counter

[![D2Rethinked_video2](https://user-images.githubusercontent.com/105103590/198850686-3305c2c7-94be-4636-930e-c6926a8375cf.png)](https://www.youtube.com/watch?v=BmXnzDqLQgc)

More content of D2R and the older script.

- Gui - left, center, right
- Add item to log
- Creating the first game, second & third run
- Checking the MF log file

## video Diablo 2 Resurrected - Stash and Inventory management

[![D2Rethinked_video3](https://user-images.githubusercontent.com/105103590/198850836-51ba0308-45a9-4281-bfde-53ddad967761.jpg)](https://www.youtube.com/watch?v=q3oGfzKmaHI)

This can give you a rough idea of how the stash and inventory management works, although it is an old video.

- The script debug window, testing the Waypoint function
- Cast on hotkey function, switching stash tabs with the mouse wheel
- Inventory and Stash, move items from inventory to stash ( row-col order )
- Move items from inventory to stash ( random order  ), stash information
- detecting NPCs, setting the setPlayers command with one Hotkey

## video First implementation in vanilla D2

[![D2Rethinked_video4](https://user-images.githubusercontent.com/105103590/198850820-3b31f226-d5e1-42aa-980c-8df31a2530f1.png)](https://www.youtube.com/watch?v=iihjuI51dBY)

The first version of D2LoD has some great ideas.

- Selecting stash in plugy
- Transfer items from stash to inventory
- Transfer item from inventory to stash
- AutoHotkey code in AHK Studio
- In-built Atlas ( useful for beginners )

# Bugs

- count(l)ess, in all seriousness it is quite playable and shows the capabilities
