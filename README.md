# Kiripie Visual Novel Development Tool v0.6.1 for Godot 3.0

Use the power of the Godot Game Engine to make and port Visual Novels.


# What it does

Taking inspiration from a number of newer tools made in Unity as well as engines like Kirikiri and Ren'py, 
this tool is designed to make it as simple as possible to develop a Visual Novel with our custom script while 
being simple enough to modify yourself and add the features and functionality you need for your specific project.

**The tool is still in early development and many basic features have not been implemented yet.** 

Feel free to offer suggestions.


# How to use it

Drop the files into a Godot project, set 'mainGameStart.tscn' as the launching scene, and assign the script to its root node.

All game resources will also have to be imported by Godot.

The file structure for the project should look something like:
```
-.import
-art
   -bgimage
   -fgimage
   -image
   -system
-audio
   -bgm
   -sound
   -video
   -voice
-font
-scenario
-scenes
-scripts
project.godot
```

# How it works

Following in the footsteps of Kirikiri (it was actually initially designed to port Kirikiri games), 
Visual Novels are developed in a separate script file with a tag-based scripting language.

Unlike many newer engines, it does not use a CSV file.

For example, a splashscreen leading to a main menu might look something like:

```

*splashscreen

# display the splashscreen
[video storage = "audio/video/logo2.ogv", skip = "false"]
[img storage = "art/system/logoimg.jpg"]

# Display the main menu
[bgimg storage = "title.png"]
[menu jump *mainMenu]
[bgm storage = "01.wav"]
[break]

```

As can be seen, the splashscreen, main menu, and game are not really separate from each other. They are all part of the Visual Novel.
In fact, the entire game is run through this scripting language.

Overall, it is designed so that you barely have to use the Godot Editor at all.


# Main features to add for version 1.0
- Dialogue with support for tags within the lines (ex. italics)
- Text speed
- Sprite fade-out
- Sprite sliding movements
- Support for 4:3 as well as 16:9 aspect ratios
- Saving and loading
- GD Script tag
- Choices
- Script patches similar to Kirikiri


# Existing Features
- ADV and basic NVL support
- Sprite positioning, fade-in, and crossfade
- Background fade and crossfade
- Time-based dialogue text animation (to be replaced for v1.0)
- Basic tag-based GUI scripting
- Script jump and jump location tags
- Support for background music, sound effects, voice, and ambient sounds
- Basic localization support (will continue to be improved for v1.0)
- Basic GUI-creation tag system


# Proposed features for version 2.0
- Support for 3D backgrounds and existing game overlay
- Support for 3D sprites
- Replacing the Godot Animation Player with a code-based solution
- Camera zooming
- Responsive screen resizing
