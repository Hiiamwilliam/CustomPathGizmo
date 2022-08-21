# CustomPathGizmo for Path Nodes
Before: 

![github_img_before](https://raw.githubusercontent.com/Hiiamwilliam/CustomPathGizmo/main/images/github_img_before.png)

After: 

![github_img](https://raw.githubusercontent.com/Hiiamwilliam/CustomPathGizmo/main/images/github_img.png)


Improvements to Godot 3.x Path Node:
- A new CMYK colored three axis translation gizmo that works for both curve points and handles;
    - C, for Cyan: the three translation gizmos;
    - M, for Magenta: curve points;
    - Y, for Yellow: in and out handles of the currently selected curve point;
    - K, for Kcalb (Black): also a curve point, but it's always the first one (index zero).
- Adds a field to change curve point's tilt in the top menu. Only appears when the currently selected point is a curve point;
- Closed loop editing (editing the first point also edits the last if the loop is closed);
    - Closes loop if you either use the top menu "Close Curve" or translate the first curve point to the same position of the last;
    - Adds a button to the top menu to Open Loop. Only appears when the loop is closed.
- Prints point position when double-clicked;
- `Control` while translating: translations will snap to steps of 1 (the default step value is 0.1);
- `Control + Shift + Left click`: snaps a curve point to a collider, based on camera perspective. When snapping, ignores step value;
- `Shift + Left click`: creates in/out handles when applicable;
- `Spacebar` while translating:
    - Moves all curve points at the same time if the selected point is a curve point;
    - Moves in/out handles individually if the selected point is a handle.
- Ability to set the extents of the translation gizmos;
- Added Undo/Redo for: add handles, snap to collider, set tilt, and open loop. Default Undo/Redo like adding points still work as usual.

## Keep in mind
- Don't use the variable names "last_point" and "x" to set meta information on a Path's Curve3D, as they're used by this addon;
- This addon works by (kinda) overriding Godot's Path gizmos. This has some consequences:
    - Use Snap (default shortcut `Y`) and Translate Snap (Transform > Configure Snap...) have no effect;
    - The top menu "Delete Point" prints two Engine related errors when used. They don't seem harmful, but I'm no expert. In any case, deleting points with Right click when the current tool is "Select Points" works fine;
    - The top menu Options to Mirror Handles have no effect;
    - Deleting a curve point then Undoing will not restore its tilt value.
- I have no idea what will happen if you try to use other custom Path Node gizmos at the same time.

## Gizmos not appearing
- After activating this addon, switch scenes to make the gizmos appear on already created Path Nodes;
- Since Godot 3.5, clicking on a Node in the SceneTree while you're on the Script Editor doesn't switch to the 3D Editor. This makes the gizmos not appear correctly when you do switch to the 3D Editor. Select another Node then re-select the Path Node.

## Etc.
- Developed in Godot 3.4.4 and 3.5. Should work in other 3.x versions, but I didn't test;
- Shout out to Waterways (https://github.com/Arnklit/Waterways), as I inspected that code several times to understand stuff.
