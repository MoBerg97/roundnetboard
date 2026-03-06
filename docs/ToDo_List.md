# ToDo List for Features and Fixes

## Testing Debugging Guidelines

always test compilation using `flutter analyze`

clearing cache on a device/emulator:
`adb -s emulator-5554 shell pm clear com.moritzberg.roundnetboard` where "emulator-5554" is the device id (get it via `adb devices`)

fully clear app data on an android device/emulator:
`adb -s emulator-5554 shell pm clear com.moritzberg.roundnetboard; adb -s emulator-5554 shell run-as com.moritzberg.roundnetboard rm -rf /data/data/com.moritzberg.roundnetboard/files; adb -s emulator-5554 shell run-as com.moritzberg.roundnetboard rm -rf /data/data/com.moritzberg.roundnetboard/shared_prefs`

When finalizing an implementation or edit with large chunks of code changes, make sure to run `flutter analyze` and fix all warnings and errors that come up there.

## Current Implementation

## Design

### main aspects

less clutter
alignment of all icons, buttons and menus
intuitive usage

UI guidelines to follow:
UI elements with multiple options:
tap and hold on a tool extends a small rectangular chamfered edge window above the tool with one column of the three sizes. The user selects one of the sizes by dragging towards one of the size icons (small to mediumg to large circle) and releasing the hold (ACITON_UP). Upon releasing the hold, the selection menu disappers. If the user releases the hold outside of the selection menu, no size change is applied. If the user drags towards one of the size icons and releases the hold on top of it, the size of the tool is changed to the selected size.
When using a mouse (e.g. web app or windows app) the selection menu opens up by right clicking the tool and closes by selecting one of the sizes or by right clicking again on the tool or by clicking anywhere else on board.

menu bars with multiple tools:
the menu bar is horizontally scrollable when screen width is too small to show all tools at once. Scrolling is done by swiping left or right on touch devices and by mouse wheel scrolling on web and windows app.

### design ideas

- [ ] separate the annotation tools in two rows. One for the tools that create annotations (circle, lines, rectangles, circle sections) and one row for the tools that modify existing annotations (move, delete, duplicate, fore/background, line width, color).
- [x] selected objects (players and balls) should be highlighted on court (e.g. circular sonar waves around object)
- [ ] objects are only highlighted when their respective menu is open, not when dragged or long pressed. Tapping on an object opens its menu and highlights it, tapping elsewhere closes menu and removes highlight.
- [ ] hit marker in animation playback should fade out smoothly instead of disappearing instantly
- [ ] change the hit marker on the board screen to another icon (e.g. circle with bounce arrow inside)
- [ ] default color of ball should be white with black outline
- [x] default color of players should be red and blue (as is) with black outline
- [ ] make path control points invisible by default, only show them when a path is edited (more subtle design than current big circles)
- the objects (players and balls) should have a slight shadow below them to indicate that they are above the court.
- [ ] adjust the hit and set marker on the boardscreen during editing:
  - [ ] set: instead of a circle, the current path is displayed as a line getting thicker in size from start towards the middle and thinner again from middle to end. #n Alternative: show multiple circles along the path, getting bigger towards the middle and smaller again towards the end, make them very subtle (same color as ball but 30% opacity, always aligned with current ball color)
  - [ ] hit: the star icon should be more transparent and only grey color, no outline and a little bigger. it should slowly fade out during the animation playback instead of disappearing instantly.
- [x] the eraser tool icon should be an actual eraser icon (not trash can icon)
- [x] #n get rid of circular endpoints of annotation lines
- [ ] the annotations should fade in and fade out dynamically in animation playback.
- [ ] landscape mode orientation changes visual structure (right side is court, left side is controls including annotations and ball modifier menu)
- [ ] the insert frame thumbnail button should appear right next to the current frame in the timeline instead of below it, indicating that the next frame is created after the currently selected frame as a direct copy.
- [ ] produce the same preview radius indication for circle elements on court editor as it is implemented for circles in the annotation tools.
- [x] get rid of permanent center points for circle annotations.
- [ ] change annotation style to hand drawn style
  - [ ] circle annotations are not perfect circles but hand drawn style circles
  - [ ] annotations with varying stroke widths resembling hand drawn lines
  - [ ] sketchy arrowheads for line annotations
  - [ ] dashed lines with irregular dash lengths for line annotations
- [ ] add icons in settings menu to indicate certain settings (e.g. object scale, court size, playback speed, etc)

### help / tutorial

- [ ] POSTPONED: create a interactive tutorial that comes up upon the first opening of the app on a device.
- [ ] create a tutorial button inside the helper screen, that opens the home screen and starts the tutorial all over again.

- add a helper screen that can be accessed from the home screen and the board screen via a question mark icon in the top right corner.
  - helper screen should contain:
    - [ ] short text explanations of all main features of the app (project creation, sharing, exporting)
    - [ ] POSTPONED: small images / gifs showing how to use certain features
    - [ ] POSTPONED: a link to a more detailed online documentation (e.g. github pages or similar)
    - [ ] a link to a contact email for feedback and bug reports
  - board screen helper screen should contain:
    - [ ] short text explanations of all main buttons and icons on the board screen (project settings, playback controls, timeline, annotation tools, ball modifier tools)
    - [ ] POSTPONED: small images / gifs showing how to use certain features on the board screen
  - court editor screen helper screen should contain:
    - [ ] short text explanations of all main buttons and icons on the court editor screen (court elements, court settings, court saving and loading)
    - [ ] POSTPONED: small images / gifs showing how to use certain features on the court editor screen

Quick tips to add to helper screen:

- [ ] "Want to emphasize a certain position? Copy the specific frame and increase the duration of the new frame for an obersevational pause in the animation" in quick tips
- [ ] "Use the annotation tools to highlight specific tactics or movements on the court"
- [ ] "Delete unwanted frames by double tapping the frame thumbnail in the timeline and tapping the trash can icon"
- [ ] "You can start a circle sector annotation outside of a circle element. This allows for a more precise placement of the sector start angle."

## Features

### project screen

- [x] users are not able to share or export projects in web version currently.
- [x] add two exemplary projects that are preloaded when the app is first installed, showcasing all features of the app (one play scenario, one training scenario)
- [ ] add missing project settings/features of the exemplary projects (e.g. annotation visibility)
- [ ] future: add a "community trainings" area with category filters (e.g. serve receive, defense, drills), starting with importable json packs before cloud hosting exists.

### intuitive actions

- [x] hide all current complex project settings (anything size on board related) in the board screen under "advanced settings"
- [ ] when a user drags an object and stays holding that object for more than 1sec on about the same location (within 50px), a magnifying window (1.5x) showing the object and its surrounding 10% of displaymin = min(screenwidth,screenheight) is shown hovering 20% of displaymin above the location that user is holding.
- [ ] the magnifying window is deactivated as soon as the user changed the position of the object over 50px in the last .5 seconds
- [x] court elements snap to corners and center points of other court elements when being dragged within 20px of such a point.
- [ ] automaticaaly snap annotations upon creation to annotation objects (e.g. line endpoints snap to circle circumference when created within 20px of it)
- [ ] add optional "magnet markers" for object positions: faint ghost markers of frame-start positions that dragged players/balls can snap back to within ~20px.
- [ ] add quick swap positioning: dragging a player/ball onto another same-type object and releasing near its center swaps both positions in the current frame.
- [ ] add alignment helpers for objects (horizontal/vertical/center guide lines + snap) to support precise layout without clutter.
- [ ] add multi-select align actions in advanced menu: align left/center/right/top/middle/bottom and distribute evenly.

### court

- [ ] the court should be zoomable with two states, first state is as it currently is, showing at least 1.2 times servezone_radius around the center of the court. second zoom stage should be the whole court towards the outer boundary at 850cm radius around the center of court.
- [x] #n make objects on court relate in size to court (player and ball circle radius, paths in width adjusted for size not in pixels but in relation to court size (cm))
- [ ] default starting position of player and ball should be editable in the global (home screen accesible) settings menu and then new projects start with objects in this position.
- [x] when a new project is created, the user can decide if he wants the play scenario (with all zones on default radii and 4 players in their default start position and one ball) or training scenario (with all zones deactivated and 1 player red and one player blue and one ball)
- [x] #n default width of circle elements when added to court in court editor should be 30cm radius.

### annotations

- [x] annotation menu should be horizontally scrollable when screen width is too small to show all annotation tools at once.
- [x] #n add a drag and drop tool, that allows to move annotations around on the court, as it is currently implemented in the court editor screen.
- [x] there should be a foldable menu for annotations that provides frame specific annotations.
- [x] add a line annotation tool, that also is editable in color, user can manually edit the end points of the line.
- [x] annotations should be frame specific and also should be copyed along all other objects when a new frame is inserted.
- [ ] temporary annotations can be added in animation playback mode, that are not frame specific and are deleted when the user stops playback. annotations should only be permament (saved per frame) when added in the annotation mode in the editing board screen.
- [x] add a text annotation tool, that allows to add text labels on the court. (fixed font color, size adjustable via pop-up menu, draggable position, editable text content (double tap to edit text))
- [x] default width for circles when only tapping once should be 30cm radius.
- [x] right click or long tap on annotation tools should open a small menu to select default color and default size for this annotation tool (line width/stroke size in 3 steps, indicated by small preview icons, for circle and rectangles: filled or outline only, for text: font size in 3 steps)
- [ ] add a pop-up menu for the line tool to select between straight line, arrowed line and dashed line.
- [ ] annotations that are added in paused mode in the animation playback are only temporarely visible during this playback until the current playback is left (going back to the editing screen or back to project overview)
- [x] add a trash can icon to erase all annotations of the current frame
- [x] circle sector annotation tool (like a pie chart slice) to highlight certain areas on the court. the sector is defined for the last selected circle element. first touch position defines the start of the sector angle and dragging the finger around the circle defines the end angle of the sector. the sector is filled with the selected color. Circle sector annotation are filled shapes only, no outline only option.
  - [x] sector start angle follows the initial touch (no rightward offset)
  - [ ] add a pop-up menu for the circle sector tool to select to which object or court element it should be attached (center point can be ball, player or zone court element)
  - [ ] for ball or player attachment, the sector is not moving with the object during animation playback, it is only attached to the object in the frame it is created in at the end position of the object in this frame. the sector radius is fixed to 260cm for ball or player attachment.
  - [ ] for zone attachment, the sector radius is equal to the zone radius.
  - [ ] the sector does not snap onto the zero coordinate point of the court, but to the center point of the respective zone court element or player or ball object at that frames end position.
- [ ] automatically snap annotation objects to court element corners and center points when being dragged within 20px of such a point.
- [x] Circle sectors should apply to one specific court zone element or ball object. Therefore, when the user taps on the circle sector tool, all possible zone court elements and the ball objects are highlighted with pulsing glow.
      As soon as the user then taps on of the zone elements outline, this zone is selected to have a sector be drawn for, for all consecutive drag and drop actions as long as the circle sector tools stays active. For those circle sectors created after selecting the according court zone element, the court zone elements center point and radius is taken as the variables for the circle sector.
      If the user instead selects a ball by tapping on its area, this ball is selected to have a sector be drawn for, for all consecutive drag and drop actions as long as the circle sector tools stays active. For those circle sectors created after selecting the according ball element, the balls center point is chosen as the variable for the circle sector with a standard radius of 260cm.
- [ ] move the foreground/background button for annotations into the project settings menu under "advanced settings" to reduce clutter on the main board screen.

### statistics

- [ ] user can toggle on footwork and in-system statistics in the board_screen settings
- [ ] footwork statistics shows for each frame the amount of distance each player travels, as small bars on the top side of the screen.
- [ ] the maximum footwork distance is 850cm and the minimum is 0cm.
- [ ] if turned on, the footwork statistics will also be depicted in the animation playback with showing the footwork of a certain frame during the playback of this frame.
- [x] during animation playback, the user can toggle full path revision of a player or the ball by tapping the player or ball and this shows the path that this object already moved (full line) and the upcoming path of this object (dashed line). toggles off when the object is tapped again.

### sharing

- [ ] users can export each frame as a single image, or all frames as images appended to each other, to form a left to right or top to bottom succession.
- [ ] users can export the animation as a video file. the speed of the exported animation should match the last selected playback speed of the animation.
- [ ] add direct animation export presets: mp4 (preferred) and gif (fallback/quick share), with simple quality presets to keep UX intuitive.
- [ ] for export, the screen view should be captured as it is, meaning that if the user has zoomed in on the court, the export should also be zoomed in on the court. If the user has changed the background color of the court, this should also be reflected in the export. Be aware of the screen size of the animation used to edit the project and use this as the export size to avoid misalignment of objects in the export.
- [ ] for gif export, add loop settings (once / infinite / custom loop count).
- [x] users can share projects as a json file and import shared json files

### players

- [x] the color of player objects should be editable.
- [x] the user should be able to additionally add a single character (letter or number) shown on the player object always (project specific).
- [x] the user should be able to delete players and add players. The color of the added player object should match the color of the last tapped player object.
- [ ] support frame-specific player color changes with two scopes: "only this frame" and "from this frame to end".
- [ ] add an "advanced colors" picker (custom hue + recent colors + saved palette) behind a secondary button to avoid clutter.
- [ ] player objects can have frame specific body postures (resembled by changing greaphical representation) and introducing a rotational component of player objects
  - [ ] set (L/R): arm reaching out in front of player on of the side
  - [ ] hit (L/R): arm is with 90degree elbow bend on is going out of one of the sided of the player
    - [ ] animation of swinging arm right before the end of the frames duration and only starting when ball is within proximity of the player during a tick
  - [ ] half defense (L/R): (funnel) one arm reaching out a side of the playerwith 120 degree elbow bend
  - [ ] full defense (L/R): both arms reach out the sides of a player with 120 degree elbow bends.

### ball

- [x] the color of the ball object should be editable.
- [x] the user should be able to delete a ball and add balls. The color of the added ball object should match the color of the last tapped ball object.
- [ ] support frame-specific ball color changes with two scopes: "only this frame" and "from this frame to end".
- [ ] allow quick color transfer between objects (tap source color, then tap target object) for faster training scenario edits.

timeline:

- [ ] playback scrubber should be time related, taking frame duration into account. Currently the playback scrubber moves with equal speed through all frames, regardless of their duration setting.
- [x] the delete current frame button should only appear when a frame is double tapped if it is the currently selected frame and then disappears again if double tapped or any place else is tapped again.
- [ ] add playback loop toggle with 3 modes: no loop, loop full animation, loop selected frame range.
- [ ] allow setting loop in/out frame markers by long press on timeline thumbnails.

## Fixes

### HOTFIX

- [ ] animation playback automatically closes any open menus on the board screen when playback starts
- [ ] background color of the board screen should always match the court color in court editor and should be changeable via settings menu on board screen
- [ ] court editor should show the same court frame as the board screen. Court size in court editor should match court size in board screen (same hieght and width of container showing the court). The middle point of the court should always be in the center of the court container.
- [ ] standard zoom stage should be 1.0 times serve zone radius around center of court instead of 1.5 times
- [ ] make zoom stages larger and frame specific (saved on frames) and changeable in the board screen as a snapping slider with 5 stages
  - [ ] 1. zoom stage: show only 0.5 times serve zone radius around center of court
  - [ ] 2. zoom stage: show 1.0 times serve zone radius around center of court
  - [ ] 3. zoom stage: show 1.5 times serve zone radius around center of court (current default)
  - [ ] 4. zoom stage: show whole court towards outer boundary at 850cm radius around center of court
  - [ ] zoom is copied along when a new frame is created
  - [ ] during animation playback, zoom changes dynamically to show all objects on court at once, unless user has manually changed zoom during playback, then the user zoom is kept until playback is stopped.
- [x] account for virtual navigation bar on some android phones such as Redmi Note 13 Pro 5G by using a safe area
- [ ] test if safe area implementation works on the problematic devices (Redmi Note 13 Pro 5G) and does not break anything on other devices (iOS devices with notch, etc)
- [x] when playback is through, meaning the playback reached the end while playing, the timeline should only go back to the editing controls after the stop button is tapped, not automatically after playback reached the end
- [x] enlarge the hit box for catching the path control points on mobile devices
- [x] the buttons should not overflow on small screen devices, either scale them down or make them scrollable horizontally
- [x] the court should fit either 1.2 times the serve zone radius around the center of the court in width or height (which is smaller and based on orientation) instead of always fitting the whole court only in width (depending on screen width)
- [x] there is a small light grey section above the timeline section. this should be removed and the timeline should directly connect to the court area. when creating court elements, they overlap with this grey area which looks bad.
- [x] when undoing a path edit, the path control points of the edit remain. these should be removed when undoing the edit. when redoing the edit, the path control points should reappear. path control points should be part of the undo/redo history.

### Other fixes

- [x] after the animaiton reached the end, the scrubber is not accessible anymore (touching it leaves playback view) and the edit timeline instantly shows up. instead only the stop button should make the screen switch back to editing mode.
- [ ] the undo and redo history should also track annotation edits (creation, deletion, etc).
- [ ] the numerated suffix does not supply increasing numbers in brackets. Instead each copy gets another (1) suffix resulting in e.g. framename (1) (1) (1)
- [x] the annotations are not copied and displayed in a new frame when this is added.

## Else

- [x] setup a github repository, that contains all code, that should be accessible for public and keeps files that should not be public protected
- [ ] set icon for the app for web and windows applications
- [ ] setup a fallback warning message for unsupported browsers and a way to catch such errors during runtime on web platform
