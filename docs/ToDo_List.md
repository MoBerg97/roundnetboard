# ToDo List for Features and Fixes

## Design

### main aspects

less clutter
alignment of all icons, buttons and menus
intuitive usage

### design ideas

- [ ] #n selected objects (players and balls) should be highlighted on court (e.g. circular sonar waves around object)
- [ ] hit marker in animation playback should fade out smoothly instead of disappearing instantly
- [ ] change the hit marker on the board screen to another icon (e.g. circle with bounce arrow inside)
- [ ] #n default color of ball should be white with black outline
- [ ] #n default color of players should be red and blue (as is) with black outline
- [ ] make path control points invisible by default, only show them when a path is edited (more subtle design than current big circles)
- [ ] #n the objects (players and balls) should have a slight shadow below them to indicate that they are above the court.
- [ ] adjust the hit and set marker on the boardscreen during editing:
  - [ ] set: instead of a circle, the current path is displayed as a line getting thicker in size from start towards the middle and thinner again from middle to end. #n Alternative: show multiple circles along the path, getting bigger towards the middle and smaller again towards the end, make them very subtle (same color as ball but 30% opacity, always aligned with current ball color)
  - [ ] hit: the star icon should be more transparent and only grey color, no outline and a little bigger. it should slowly fade out during the animation playback instead of disappearing instantly.
- [x] the eraser tool icon should be an actual eraser icon (not trash can icon)
- [ ] #n get rid of circular endpoints of annotation lines
- [ ] the annotations should fade in and fade out dynamically in animation playback.
- [ ] landscape mode orientation changes visual structure (left side is court, right side is controls including annotations and ball modifier menu)
- [ ] the insert frame thumbnail button should appear right next to the current frame in the timeline instead of below it, indicating that the next frame is created after the currently selected frame as a direct copy.
- [ ] produce the same preview radius indication for circle elements on court editor as it is implemented for circles in the annotation tools.
- [ ] get rid of permanent center points for circle annotations.

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

## Features

### project screen

- [ ] users are not able to share or export projects in web version currently.
- [ ] check if all properties of a project (court type, court elements, objects, annotations, settings)
- [ ] add two exemplary projects that are preloaded when the app is first installed, showcasing all features of the app (one play scenario, one training scenario)

### intuitive actions

- [ ] #n hide all current complex project settings (anything size on board related) in the board screen under "advanced settings"
- [ ] when a user drags an object and stays holding that object for more than 1sec on about the same location (within 50px), a magnifying window (1.5x) showing the object and its surrounding 10% of displaymin = min(screenwidth,screenheight) is shown hovering 20% of displaymin above the location that user is holding.
- [ ] the magnifying window is deactivated as soon as the user changed the position of the object over 50px in the last .5 seconds
- [ ] #n court elements snap to corners and center points of other court elements when being dragged within 20px of such a point.

### court

- [ ] the court should be zoomable with two states, first state is as it currently is, showing at least 1.2 times servezone_radius around the center of the court. second zoom stage should be the whole court towards the outer boundary at 850cm radius around the center of court.
- [ ] #n make objects on court relate in size to court (player and ball circle radius, paths in width adjusted for size not in pixels but in relation to court size (cm))
- [ ] default starting position of player and ball should be editable in the global (home screen accesible) settings menu and then new projects start with objects in this position.
- [x] when a new project is created, the user can decide if he wants the play scenario (with all zones on default radii and 4 players in their default start position and one ball) or training scenario (with all zones deactivated and 1 player red and one player blue and one ball)
- [ ] #n default width of circle elements when added to court in court editor should be 30cm radius.

### annotations

- [ ] #n add a drag and drop tool, that allows to move annotations around on the court, as it is currently implemented in the court editor screen.
- [x] there should be a foldable menu for annotations that provides frame specific annotations.
- [x] add a line annotation tool, that also is editable in color, user can manually edit the end points of the line.
- [x] annotations should be frame specific and also should be copyed along all other objects when a new frame is inserted.
- [ ] annotations should only be permament (saved per frame) when added in the annotation mode in the editing board screen.
- [ ] add a text annotation tool, that allows to add text labels on the court. (fixed font color, size adjustable, draggable position, editable text content)
- [ ] #n default width for circles when only tapping once should be 30cm radius.
- [ ] right click or long tap on annotation tools should open a small menu to select default color and default size for this annotation tool (line width/stroke size in 3 steps, indicated by small preview icons, for circle and rectangles: filled or outline only, for text: font size in 3 steps)
- [ ] annotations that are added in paused mode in the animation playback are only temporarely visible during this playback until the current playback is left (going back to the editing screen or back to project overview)
- [x] add a trash can icon to erase all annotations of the current frame

### statistics

- [ ] user can toggle on footwork and in-system statistics in the board_screen settings
- [ ] footwork statistics shows for each frame the amount of distance each player travels, as small bars on the top side of the screen.
- [ ] the maximum footwork distance is 850cm and the minimum is 0cm.
- [ ] if turned on, the footwork statistics will also be depicted in the animation playback with showing the footwork of a certain frame during the playback of this frame.
- [ ] **during animation playback, when the playback is paused, the user can toggle full path revision of a player or the ball by tapping the player or ball and this shows the path that this object already moved (full line) and the upcoming path of this object (dashed line). toggles off when the object is tapped again.**

### sharing

- [ ] **users can export each frame as a single image, or all frames as images appended to each other, to form a left to right or top to bottom succession.**
- [ ] **users can export the animation as a video file. the speed of the exported animation should match the last selected playback speed of the animation.**
- [x] users can share projects as a json file and import shared json files

### players

- [ ] the color of player objects should be editable.
- [ ] the user should be able to additionally add a single character (letter or number) shown on the player object always (project specific).
- [x] the user should be able to delete players and add players. The color of the added player object should match the color of the last tapped player object.
- [ ] player objects can have frame specific body postures (resembled by changing greaphical representation) and introducing a rotational component of player objects
  - [ ] set (L/R): arm reaching out in front of player on of the side
  - [ ] hit (L/R): arm is with 90degree elbow bend on is going out of one of the sided of the player
    - [ ] animation of swinging arm right before the end of the frames duration and only starting when ball is within proximity of the player during a tick
  - [ ] half defense (L/R): (funnel) one arm reaching out a side of the playerwith 120 degree elbow bend
  - [ ] full defense (L/R): both arms reach out the sides of a player with 120 degree elbow bends.

### ball

- [x] the color of the ball object should be editable.
- [x] **the user should be able to delete a ball and add balls. The color of the added ball object should match the color of the last tapped ball object.**

timeline:

- [ ] playback scrubber should be time related, taking frame duration into account. Currently the playback scrubber moves with equal speed through all frames, regardless of their duration setting.
- [ ] the delete current frame button should only appear when a frame is tapped again if it is the currently selected frame and then disappears again if it is tapped again (toggle behavior).

## Fixes

### HOTFIX

- [ ] make the annotation tool menu centered for large screen devices (currently aligned to left side of screen, looks bad on large screens)
- [ ] change background color of project create window to something brighter so that the text is readable
- [ ] **account for virtual navigation bar on some android phones such as Redmi Note 13 Pro 5G by using a safe area**
- [ ] **when playback is through, meaning the playback reached the end while playing, the timeline should only go back to the editing controls after the stop button is tapped, not automatically after playback reached the end**
- [ ] **when exporting a project on web browser, the export project throws the error: Export failed: Failed to export project: UnimplementedError: saveFile() has not been implemented.**
- [ ] **when sharing a project on web browser, the share project throws the error:Share failed: MissingPluginException(No implementation found for method getApplicationDocumentsDirectory on channel plugins.flutter.io/path_proivider)**
- [ ] enlarge the hit box for catching the path control points on mobile devices (currently only about 10px radius, should be at least 30px radius)
- [ ] the buttons should not overflow on small screen devices, either scale them down or make them scrollable horizontally
- [ ] the court should fit either 1.5 times the serve zone radius around the center of the court in width or height (which is smaller and based on orientation) instead of always fitting the whole court only in width.

### Other fixes

- [ ] **after the animaiton reached the end, the scrubber is not accessible anymore (touching it leaves playback view) and the edit timeline instantly shows up. instead only the stop button should make the screen switch back to editing mode.**
- [ ] the undo and redo history should also track annotation edits (creation, deletion, etc).
- [ ] the numerated suffix does not supply increasing numbers in brackets. Instead each copy gets another (1) suffix resulting in e.g. framename (1) (1) (1)
- [ ] the annotations are not copied and displayed in a new frame when this is added.

## Else

- [x] setup a github repository, that contains all code, that should be accessible for public and keeps files that should not be public protected
- [ ] set icon for the app for web and windows applications
- [ ] setup a fallback warning message for unsupported browsers and a way to catch such errors during runtime on web platform
