# ToDo List for Features and Fixes

## Design

### main aspects: 
less clutter

### design ideas

- [ ] **make path control points less invisible, therefore the path editable from any point (snaps control point to current touched position of path if a path is touched). This means that instead of creating the ball path on double tap; the user should instantly drag the snapped path control point if a point on path (with 10cm buffer) is touched and hold.**
- [x] lines preview fade from end (alpha 0) to start position (alpha 0.5) of current path
- [x] lines of the previous frame should be less visible on default and fade from end position (alpha 0.75) to start position (alpha=1)
- [ ] adjust the hit and set symbols on the boardscreen (not the icons to toggle them):
  - [ ] set: instead of a circle, the current path is displayed as a line getting thicker in size from start towards the middle and thinner again from middle to end.
  - [ ] hit: the star icon should be more transparent and only grey color, no outline and a little bigger. it should slowly fade in the animation playback on its position after appearing under the ball.
- [ ] the ball path modifier menu should have no visible box container
- [x] the timeline can be a little lower in height.
- [ ] **the eraser tool icon should be an actual eraser icon (not trash can icon)**
- [ ] get rid of circle points at start and end points of lines
- [ ] the annotations should fade in and fade out dynamically in animation playback.
- [ ] landscape mode orientation changes visual structure (left side is court, right side is controls including annotations and ball modifier menu)

### Quick tips

- [ ] **create a interactive tutorial that comes up upon the first opening of the app on a device.**
- [ ] create a tutorial button inside the helper screen, that reopens that opens the home screen and starts the tutorial all over again.
- [ ] "Want to emphasize a certain position? Copy the specific frame and leave as is to provide an obersevational pause in the animation"

## Features

### project screen:

- [x] project should be able to be duplicated and then get a ascending numerated suffix when the project name already exists in ().
- [x] users should be able to share projects including all frames and project specific settings.

### intuitive actions:

- [ ] when a user drags an object and stays holding that object for more than 1sec on about the same location (within 50px), a magnifying window (1.5x) showing the object and its surrounding 10% of displaymin = min(screenwidth,screenheight) is shown hovering 20% of displaymin above the location that user is holding.
- [ ] the magnifying window is deactivated as soon as the user changed the position of the object over 50px in the last .5 seconds
- [x] standard playback speed (at 1x) should be lower and made possible to be reducable to a higher degree, therefore increase to a lesser degree
- [ ] start line point adding can also be drag and drop (create at position where ACTION_UP triggers) and then the end point is the drag and drop position after that (set the position where Action_UP triggers)

### court:

- [ ] the court should be zoomable with two states, first state is as it currently is, showing at least 1.2 times servezone_radius around the center of the court. second zoom stage should be the whole court towards the outer boundary at 850cm radius around the center of court.
- [ ] the user should be able to select standard court or empty court as a drop down menu setting when opening a new project.
- [ ] make objects on court relate in size to court (player and ball circle radius, paths in width adjusted for size)
- [ ] default starting position of player and ball should be editable in the global (home screen accesible) settings menu and then new projects start with objects in this position.
- [ ] user should be able to turn off zones and net in project settings
- [ ] when a new project is created, the user can decide if he wants the play scenario (with all zones on default radii and 4 players in their default start position and one ball) or training scenario (with all zones deactivated and 1 player red and one player blue and one ball)

### annotations:

- [x] there should be a foldable menu for annotations that provides frame specific annotations.
- [ ] the annotations should be selectable from a variety of icons indicating the annotation to add.
- [x] add a line annotation tool, that also is editable in color, user can manually edit the end points of the line.
- [ ] **annotations should be frame specific and also should be copyed along all other objects when a new frame is inserted.**
- [ ] annotations should only be permament (saved per frame) when added in the annotation mode in the editing board screen.
- [ ] annotations that are added in paused mode in the animation playback are only temporarely visible during this playback until the current playback is left (going back to the editing screen or back to project overview)
- [ ] **add a trash can icon to erase all annotations of a frame. this should pop up a user confirmation before deleting all annotations.**
- [ ] the trash confirmation should ask if all annotations (across all frames) or only for a single frame should be done

### statistics:

- [ ] user can toggle on footwork and in-system statistics in the project settings
- [ ] footwork statistics shows for each frame the amount of distance each player travels, as small bars on the top side of the screen.
- [ ] the maximum footwork distance is 850cm and the minimum is 0cm.
- [ ] if turned on, the footwork statistics will also be depicted in the animation playback with showing the footwork of a certain frame during the playback of this frame.
- [ ] during animation playback, when the playback is paused, the user can toggle full path revision of a player or the ball by tapping the player or ball and this shows the path that this object already moved (full line) and the upcoming path of this object (dashed line). toggles off when the object is tapped again.

### sharing:

- [ ] **users can export each frame as a single image, or all frames as images appended to each other, to form a left to right or top to bottom succession.**
- [ ] **users can export the animation as a video file. the speed of the exported animation should match the last selected playback speed of the animation.**
- [x] users can share projects as a json file and import shared json files

### players:

- [ ] the color of player objects should be editable.
- [ ] the user should be able to additionally add a single character (letter or number) shown on the player object always (project specific).
- [ ] **the user should be able to delete players and add players. The color of the added player object should match the color of the last tapped player object.**
- [ ] player objects can have frame specific body postures (resembled by changing greaphical representation) and introducing a rotational component of player objects
  - [ ] set (L/R): arm reaching out in front of player on of the side
  - [ ] hit (L/R): arm is with 90degree elbow bend on is going out of one of the sided of the player
    - [ ] animation of swinging arm right before the end of the frames duration and only starting when ball is within proximity of the player during a tick
  - [ ] half defense (L/R): (funnel) one arm reaching out a side of the playerwith 120 degree elbow bend
  - [ ] full defense (L/R): both arms reach out the sides of a player with 120 degree elbow bends.

### ball:

- [ ] the color of the ball object should be editable.
- [ ] **the user should be able to delete a ball and add balls. The color of the added ball object should match the color of the last tapped ball object.**

timeline:

- [ ] playback scrubber should be time related, taking frame duration into account. Currently the playback scrubber
- [ ] the insert frame thumbnail button should appear right next to the current frame in the timeline instead of below it, indicating that the next frame is created after the currently selected frame as a direct copy.
- [ ] the delete current frame button should only appear when a frame is tapped again if already selected and then disappears again if it is tapped again.
- [x] during playback a cursor should appear in the timeline visually indicating the current point in time of the playback. This should be checked to be in accordance with the timing of the frames.
- [x] the timeline should have a pause button.
- [x] the speed adjustment slider should be a slightly transparent slider without background box (only slider control point as dot and slider bar) sitting on top of the timeline with the bar in vertical direction.
- [x] the user should be able to select a duration of the animation of a frame during editing a project. duration is frame specific.

## Fixes

### HOTFIX

- [ ] **account for virtual navigation bar on some android phones such as Redmi Note 13 Pro 5G by using a safe area**
- [ ] **when playback is through, meaning the playback reached the end while playing, the timeline should only go back to the editing controls after the stop button is tapped, not automatically after playback reached the end**

### Other fixes

- [ ] **after the animaiton reached the end, the scrubber is not accessible anymore (touching it leaves playback view) and the edit timeline instantly shows up. instead only the stop button should make the screen switch back to editing mode.**
- [ ] the undo and redo history should also track annotation edits (creation, deletion, etc).
- [ ] **the eraser tool should show no preview of which annotations to delete, instead annotations touched during tapping or dragging of the eraser tool (10px radius) are instantly deleted.**
- [ ] the numerated suffix does not supply increasing numbers in brackets. Instead each copy gets another (1) suffix resulting in e.g. framename (1) (1) (1)
- [ ] the annotations are not copied and displayed in a new frame when this is added.
- [x] the playback timeline divides the frame thumbnail into n thumbnails as in the editing timeline. but the first frame has no duration, only giving the start positions. therefore the cursor of the thumbnail should start at time 0 at the left hand side of the thumbnail of frame 1
- [x] the ball path modifier menu buttons should be toggable to on and off (Iindicated by highlighted/non-highlighted button), not only on. MAke sure, that the ball path can be either set or hit, not both.
- [x] the go to previous and go to next frame in the boardscreen should be removed, since the user can already select the current frame directly from the timeline.
- [x] the hit animation is animated too short and is too small. It should be the size of the normal ball size times 0.3
- [x] instead of tap-and-holding the ball path to trigger the ball set hit icons to appear, the icons should appear when the ball at its current position is tapped.
- [x] the hit control point is only draggable once after creation. Instead i want the user to be able to drag it any time (triggers when tapped <30cm from middle point of star)
- [x] the hit control point is dragged by a user, but the actual point of the ball on the path is not corresponding to the tapped location.
- [x] the dragging od the hit control point is still not on the actual position of the hit control point on screen. There is a bug, showing that the dragging position is shifted vertically in y direciton by a fixed amount.
- [x] the hit can only be toggled on when the current frames ball path is of a distance greater than 30cm
- [x] when a frame is selected as current frame in the boardscreen, the timeline should automatically visually scroll to show the selected frame.
- [x] NOT FUNCTIONAL: older lines of previous frame can be set to be not displayed in current frame as a setting in the settings menu of the board screen (three dots in app bar)

## Else

- [x] setup a github repository, that contains all code, that should be accessible for public and keeps files that should not be public protected
