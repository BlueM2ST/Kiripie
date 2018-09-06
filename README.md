# Kiripie Visual Novel Development Tool v0.9.0 for Godot 3.0.x

Use the power of the Godot Game Engine to make and port Visual Novels and Point-and-Click games!

# What it does

Taking inspiration from a number of newer tools made in Unity as well as engines like Kirikiri and Ren'py, 
this tool is designed to make it as simple as possible to develop a Visual Novel with our scripting system while 
being simple enough to modify yourself and add the features and functionality you need for your specific project.

**Please note that this tool is still in early development** 

Feel free to offer suggestions.

# How to set it up

Download and import it as a project in Godot. Some file names may be invalid in the sample scripts 
(you might not have the files), so please add your own.

You will also need the PCKManager addon/plugin, which can be found here: https://github.com/MrJustreborn/godot_PCKManager or 
on the Godot AssetLib.

# How it works

Following in the footsteps of Kirikiri (it was actually initially designed to port Kirikiri games), 
Visual Novels are developed in a separate script file with a tag-based scripting language.

Unlike many newer engines, it does not use a CSV file. It is designed to be edited in a text editor.

To run the game, for example, a splashscreen leading to a main menu might look something like:

```

*splashscreen

[menu @@Init]
[video storage = "logo.webm"]

[img storage = "logoimg.jpg"]

[bgm storage = "01.wav"]

[bgimg storage = "title.png"]

[menu @@MainMenu]

[break]

```

And the `@@MainMenu` might look like:

```

*menu

@@MainMenu
[button delall]
[button id = "##ClickButton", slot = "0", loc = "0x0", size = "1920x1080", imgNormal = "TP.png", imgHover = "TP.png"]
[button id = "##StartButton", slot = "1", loc = "1500x500", size = "300x100", imgNormal = "start_n.png", imgHover = "start_o.png"]
[button id = "##ConfigButton", slot = "2", loc = "1500x650", size = "300x100", imgNormal = "config_n.png", imgHover = "config_o.png"]
[button id = "##LoadButton", slot = "3", loc = "1500x800", size = "300x100", imgNormal = "load_n.png", imgHover = "load_o.png"]
[if conf "finishedGame" = "true"]
[button id = "##ExtraButton", slot = "4", loc = "1500x950", size = "300x100", imgNormal = "extra_n.png", imgHover = "extra_o.png"]
[endif]
[button id = "##ExitButton", slot = "4", loc = "1500x950", size = "300x100", imgNormal = "exit_n.png", imgHover = "exit_o.png"]

```

To display a sprite, play a voice file, display a name, and display text, you might use something like this:

```

[fgimg storage = "fg001.webp", slot = "1", pos = "center"]
[voice storage = "VO010001.wav"]
[name Yuki]
Hello, my name is Yuki~~!

```

Overall, it is designed so that you barely have to use the Godot Editor at all (except for setting music to loop and a few other things).


# Can I make a NVL game using this tool?

Sure, there is a dialogue tag that lets you set the text to display wherever on the screen you want:

```

[dialogue box storage = "msgframe.png", loc = "0x800", size = "1920x270"]
[dialogue text loc = "250x50", size = "1600x330"]

```


# Can I make a point-and-click game using this tool?

Sure, but it may not be as simple as other tools. Using the menu system shown above, you can specify transparent (or with an image) 
buttons for each scene and code them using a separate script (scripts.kps) like:

```

##StartButton
extends TextureButton

func _pressed():
	get_tree().get_root().get_node('MainNode/MainGame/DialogueLayer/DialogueNode/DialogueBox').show()
	return get_tree().get_root().get_node('MainNode').mainParserLoop('*start')


##ConfigButton
extends TextureButton

func _process(delta):
    self.focus_mode = 0

func _pressed():
	return get_tree().get_root().get_node('MainNode').menuParser('@@ConfigMenu')

```

Or:

```

##ToggleFullscreenButton
extends TextureButton

func _process(delta):
	if OS.window_fullscreen:
		self.disabled = true
	else:
		self.disabled = false

func _pressed():
	OS.window_fullscreen = true
	get_tree().get_root().get_node('MainNode').configSave['fullscreen'] = true
	return get_tree().get_root().get_node('MainNode').saveGame('cf')

```

It uses GDScript, but it is in a separate file for easier editing. With this system, you can do a lot with buttons.

# What about having my game translated?

Sure, the tool has localization support, but it requires a bit of setup. It uses a json file (called *.lang) to store the dialogue, 
but both languages must use it if you want two or more languages to run on the same build.

```

{
  dialogue:{
    "%lang1": "some text here",
    "%lang2": "some more text"
  },
  
  names:{
    "%name1": "SomeName"
  }

}

```

The key value (ex. %lang1) should be written in place of the line in the *.kp script. The name of the file (ex. en.lang, ch.lang) will 
specify which language will need to be set to use the file. You will need to make buttons to set the current language like:

```

##ToggleLanguageButton_en
extends TextureButton

func _process(delta):
	if get_tree().get_root().get_node('MainNode').configSave['language'] == 'en':
		self.disabled = true
	else:
		self.disabled = false

func _pressed():
	get_tree().get_root().get_node('MainNode').configSave['language'] = 'en'
	get_tree().get_root().get_node('MainNode').saveGame('cf')
	# reload the config menu for the new language
	return get_tree().get_root().get_node('MainNode').menuParser('@@ConfigMenu')


##ToggleLanguageButton_ch
extends TextureButton

func _process(delta):
	if get_tree().get_root().get_node('MainNode').configSave['language'] == 'ch':
		self.disabled = true
	else:
		self.disabled = false

```

The _process() functions are necessary since the button (or any button made through the *.kp file) cannot directly connect or signal the main node. 
This system will ensure the buttons are linked and only one can be active at once (Buttongroups are not yet implemented). The language specified by 
the script must match the name of the *.lang file. 


You can also go a step further and localize the entire menu system:

```

@@ConfigMenu
[button delall]
[setfront]
[if conf "language" = "en"]
[menuimg storage = "sys_windows_01a_en.png"]
[endif]
[if conf "language" = "ch"]
[menuimg storage = "sys_windows_01a.png"]
[endif]

```

This will display a menu image based on the language set.

# What about playing videos?

Currently, Godot is hit-and-miss when it comes to playing video files. I've played OGV files using the editor fine, but in a build they crash the game. 
I haven't had much luck with WEBM either. In short, it depends on how the video is encoded and what version it's using (as far as I know). 
This should be fixed with Godot 3.1.

# How efficient is the tool when playing games?

It runs pretty well overall, but it hasn't been extensively tested. 
This version (0.9.0) does suffer from fps drops (see 'known major bugs' below), but it should be fixed for version 1.0.


# What's left to add for version 1.0?

These are the features to add for version 1.0. Some features will require Godot 3.1 to implement, so it might take longer for some of them than others.

- Dialogue with support for tags within the lines (ex. italics) (may not make it for version 1.0)
- Sprite fade-out
- Sprite sliding movements
- Support for 4:3 aspect ratios (may not make it for version 1.0)
- Patches similar to Kirikiri
- GUI sliders (may not make it for version 1.0)


# Known major bugs in this version

- While saving works, loading will only work (properly) if the game is running through the editor.
- The dialogue() function causes some slowdowns if the dialogue progresses too quickly (like during skip).
- The script debugger is currently not working for this version. Please do not enable it.


