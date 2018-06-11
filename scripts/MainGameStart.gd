extends Node

var gameScenario = []
var config = []
var dialogueFile

# for loading from save file and testing
var canLoad = false
var isFirstPlay = true
var startLine = 0
var currentLine = 0
var currentJump = ''
var engineVersion = ''
var engineName = ''
var gameName = ''
var gameVersion = ''

# signals
# signal mouse_click # unused
signal vnDialogueNext
signal initLoadDone

# threads
onready var loadingThread = Thread.new()

onready var showCurrentLine = $ShowCurrentLine

func _ready():
	loadingThread.start(self, "loadData")
	yield(self,"initLoadDone")
	#loadingThread.wait_to_finish()
	# show the splashScreen as the first thing on loading the game
	mainParserLoop('*splashscreen')


func _input(event):
	# if left click, go to the next text
	if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed):
    	emit_signal("vnDialogueNext")
	# also go to the next text if either enter key is pressed
	if (event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER) and event.pressed):
		emit_signal("vnDialogueNext")


# =============================== parsing =====================================================

var scriptVariables = {}  # when a variable is set in the script, it is stored in this dictionary
var fgSlots = {}  # tracks the shown image of a sprite. For crossfade
func mainParserLoop(jumpStart, startLine=0):
	
	get_node("MainGame").show()
	# for now will always start at the beginning
	saveGame(true)
	currentJump = jumpStart
	var name = ''
	var foundJumpStart = false
	
	# if the script should wait for an [endif]
	var ifTrue = false
	var inIf = false
	
	# check which background layer is showing; a or b
	var bgLayerIsA = true
	var charRightIsA = true
	
	# start the loop
	for value in gameScenario:
		
		currentLine += 1
		
		# currently, the parser will loop through the lines in the file until it finds the jump location
		if not foundJumpStart:
			if not jumpStart in value:
				continue
			else:
				foundJumpStart = true
				continue
		
		if '[endif' in value:
			inIf = false
			ifTrue = false
			continue
		
		if inIf:
			# if the condition was not met, skip the lines
			if ifTrue == false:
				continue
		
		if value.begins_with('*'):
			# this functionality might not be desired in the long-term
			# It might be better to force a jump tag before every jump location tag
			# even if the script would continue onto the next jump location
			# So, this might eventually be 'break' instead of 'continue'
			continue
		
		if value.begins_with('#'):  # this line would be a comment
			continue
		
		# =========== don't add any tag parsing above this ==========
		
		# should be used for calling existing functions in the script
		if '[call' in value:
			if 'reloadSystem' in value:
				return get_tree().reload_current_scene()
			if 'reloadGame' in value:
				return mainParserLoop('*splashscreen')
			if 'menuParser' in value:
				return menuParser(value.split(' ')[2].split(']')[0])
			continue
			
		if '[menu' in value:
			if 'jump' in value:
				menuParser(value.split(' ')[2].split(']')[0])
			continue
		
		# Print text from the game script in the game's console
		if 'print' in value:
			print('DEBUG:  ' + value.split('\"')[1])
			continue
		
		# to set a variable from the script
		if '[setvar' in value:
			value = value.split(' ')
			scriptVariables[value[1]] = value[3].split(']')[0]
			continue
		
		if '[if' in value:
			inIf = true
			if '[if var' in value:
				# if the condition is met
				value = value.split(' ')
				if scriptVariables[value[2]] == value[4].split(']')[0]:
					ifTrue = true
				else:
					pass
			else:
				pass
			continue
		
		# 'img' and 'bgimg' are very similar. In fact, they are using the same nodes
		# But 'img' will replace the background image *and* hides the dialogue box
		# if showing and hiding the dialogue box becomes a tag, this might not be needed
		# Instead, it can be for images that go overtop the entire scene
		if '[img' in value:
			var splitValue = value.split("\"")
			var imgPath = splitValue[1]
			get_node("MainGame/DialogueLayer").hide()
			get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load("res://%s" % imgPath)
		
		# This is for sprites
		# this handles everything to do with basic sprites
		if '[fgimg' in value:
			var splitValue = value.split("\"")
			# remove the image from a given slot
			if '[fgimg remove' in value:
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % splitValue[1]).texture = null
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % splitValue[1]).texture = null
				continue
			var storage = splitValue[1]
			var slot = splitValue[3]
			
			# terrible exception handling, but this is Godot
			var havePos = false
			var pos
			if 'pos' in value:
				pos = splitValue[5]
				havePos = true
			get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % slot).playback_speed = 2
			# assign the position of the sprite slot
			if havePos == true:
				match pos:
					'right':
						get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % slot).rect_position = Vector2(450, 0)
						get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % slot).rect_position = Vector2(450, 0)
					'left':
						get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % slot).rect_position = Vector2(-450, 0)
						get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % slot).rect_position = Vector2(-450, 0)
					'center':
						get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % slot).rect_position = Vector2(0, 0)
						get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % slot).rect_position = Vector2(0, 0)
			# Every sprite slot has its ID assigned by its name
			# Every slot also has a 'background' and 'foreground' layer where only the foreground of the sprite is shown
			# This is done for crossfade animations
			if fgSlots['Sprite%s' % slot]:
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % slot).texture = load("res://art/fgimage/%s" % storage)
				get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % slot).play("crossfade")
				fgSlots['Sprite%s' % slot] = false
			else:
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % slot).texture = load("res://art/fgimage/%s" % storage)
				get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % slot).play_backwards("crossfade")
				fgSlots['Sprite%s' % slot] = true
			continue
			
		# Works similarly to the fgimg slots for crossfade, but is simpler since there is nothing
		#    behind the bgimage and there is only one background
		if '[bgimg' in value:
			
			### keep this for bug fixing; it checks for childen of a node
#			for N in self.get_children():
#				if N.get_child_count() > 0:
#					print("["+N.get_name()+"]")
#					# getallnodes(N)
#				else:
#					# Do something
#					print("- "+N.get_name())
			
			var imgPath = value.split("\"")[1]
			
			# Background will always fade, even without 'fadein'
			# I don't think there is any reason for background images to not fade, but it is easy to add in here
			
			#if 'fadein' in value:
			if bgLayerIsA:
				get_node("MainGame/BgLayer/BgImage/BgImage_b").texture = load("res://art/bgimage/%s" % imgPath)
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play("fade")
				bgLayerIsA = false
			else:
				get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load("res://art/bgimage/%s" % imgPath)
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play_backwards("fade")
				bgLayerIsA = true
#			else:
#				get_node("MainGame/BgImage/BgImage_a").texture = load("res://art/bgimage/%s" % imgPath)
			continue
		
		# This sets the character name in the text box
		if '[name' in value:
			get_node("MainGame/DialogueLayer").show()
			name = '【%s】\n' % value.split("\"")[1]
			continue
		
		# Every sound has its own node
		
		# This is for short sounds that do not repeat, like a door closing
		if '[se' in value:
			var splitValue = value.split("\"")
			var sePath = splitValue[1]
			$SoundPlayer.stream = load("res://audio/sound/%s" % sePath)
			$SoundPlayer.volume_db = -5
			$SoundPlayer.play()
			continue
			
		# This is for repeating background noise, like the buzzing of cicadas
		if '[amb' in value:
			if '[amb stop' in value:
				$AmbiencePlayer.stop()
				continue
			var splitValue = value.split("\"")
			var ambPath = splitValue[1]
			$AmbiencePlayer.stream = load("res://audio/sound/%s" % ambPath)
			$AmbiencePlayer.volume_db = -5
			$AmbiencePlayer.play()
			continue
			
		# This is for standard background music
		# remember looping of music has to be done in the Godot editor under import settings
		if '[bgm' in value:
			if '[bgm stop' in value:
				$BgmPlayer.stop()
				continue
			var splitValue = value.split("\"")
			var bgmPath = splitValue[1]
			$BgmPlayer.stream = load("res://audio/bgm/%s" % bgmPath)
			$BgmPlayer.volume_db = -9
			$BgmPlayer.play()
			continue
			
		# A quick way to stop all sounds
		if '[allsoundstop' in value:
			$BgmPlayer.stop()
			$VoicePlayer.stop()
			$AmbiencePlayer.stop()
			$SoundPlayer.stop()
			continue
			
		# Plays a voice, very similar to 'se'
		# THe voice will stop when the dialogue moves forward
		if '[voice' in value:
			var splitValue = value.split("\"")
			var voicePath = splitValue[1]
			$VoicePlayer.stream = load("res://audio/voice/%s" % voicePath)
			$VoicePlayer.volume_db = -5
			$VoicePlayer.play()
			continue
			
		# Plays a video
		# Will play overtop of everything(?) and waits for a mouse click to continue
		# BUG: If there is no mouse click and the video ends, it will display a blank screen/whatever was behind it before
		#      and will still wait for a a signal. Will fix once 'video end' signals are implemented in Godot
		if '[video' in value:
			get_node("MainGame/DialogueLayer").hide()
			# stop all other music
			get_node("BgmPlayer").stop()
			# $VoicePlayer.stop()
			get_node("AmbiencePlayer").stop()
			get_node("SoundPlayer").stop()
			get_node("VideoPlayer").show()
			var splitValue = value.split("\"")
			var videoPath = splitValue[1]
			# check to see if there is a second arg
			var skippable = 'true'
			if ',' in value:
				skippable = splitValue[3]
			get_node("VideoPlayer").stream = load("res://%s" % videoPath)
			get_node("VideoPlayer").volume_db = -5
			get_node("VideoPlayer").play()
			# commented out for proper video skipping
#			if skippable != 'true':
#				continue
#			else:
#				continue

		# sets the dialogue box image, position, and size
		# This allows to use the same text box and dialogue label for NVL style VNs
		# It also allows for more customized text boxes and text positioning
		# later, this should have the options 'show' and 'hide' with animations to match.
		# the tag should also be cleaned up a bit
		if '[dialogue' in value:
			if 'box' in value:
				var dialogueBox = get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox")
				var diaSplit = value.split("\"")
				var imgPath = diaSplit[1]
				var pos = diaSplit[3].split(',')
				var size = diaSplit[5].split(',')
				dialogueBox.rect_position = Vector2(pos[0], pos[1])
				dialogueBox.rect_size = Vector2(size[0], size[1])
				dialogueBox.texture = load('res://%s' % imgPath)
			if 'text' in value:
				var diaSplit = value.split("\"")
				var textBox = get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/Dialogue")
				var pos = diaSplit[1].split(',')
				var size = diaSplit[3].split(',')
				textBox.rect_position = Vector2(pos[0], pos[1])
				textBox.rect_size = Vector2(size[0], size[1])
			continue
			
		# jumps to a jump location
		if '[jump' in value:
			var toJump = value.split(" ")
			return mainGameCall(toJump[1])
		
		# another way to end a section
		# shouldn't be used in most games, but can allow for very specific scenes
		if '[sec]' in value:
			pass
			
		# this should rarely need to be used directly, only as a fallback or for testing
		if '[break]' in value:
			break
		
		# controlling how fast the text animates
		# this works pretty well, the difference in speed is almost unnoticable
		# it's still a terrible way to do it though
		# TODO: replace this with a text parser that can format text at runtime and write one letter at a time
		# --> (on its own thread?)
		var playbackSpeed = 0.007
		var dialogueToShow = name + value
		var dialoguePlaybackFixedSpeed = playbackSpeed * (600 - dialogueToShow.length())
		get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/DialogueAnimation").playback_speed = dialoguePlaybackFixedSpeed
		get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/DialogueAnimation").play("dialogue_anim")
		
		get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/Dialogue").set_text(dialogueToShow)
		showCurrentLine.set_text(engineName + '  :  ' + engineVersion + '  :  ' + gameName + '  :  ' + gameVersion + '  :  ' + currentJump + '  :  ' + str(currentLine))
		# reset the name value since not all text lines will have a name
		name = ''
		# wait for a mouse click, enter key, etc.
		yield(self,"vnDialogueNext")
		get_node("VoicePlayer").stop()
		get_node("VideoPlayer").stop()
		get_node("VideoPlayer").hide()
		get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/DialogueAnimation").stop()


# Not a very good way to do this, will need to watch out for changes to the buttons in the main parser
func menuParser(jumpStart):
	var foundJumpStart = false
	for value in config:
		
		currentLine += 1
		
		# The parser will loop through the lines in the file until it finds the jump location
		if not foundJumpStart:
			if not jumpStart in value:
				continue
			else:
				foundJumpStart = true
				continue
				
		if value.begins_with('#'):
			continue
				
		if value.begins_with('*'):
			break
			
		if '[break' in value:
			break
				
		if '[button' in value:
			if 'removeall' in value or 'remove all' in value:
				for button in get_node('MainGame/ButtonLayer').get_children():
					if button.get_child_count() > 0:
						pass
					else:
						var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
						thisButton.texture_normal = null
						thisButton.texture_hover = null
						if thisButton.is_visible():
							thisButton.hide()
				continue
	
			# actually just removes the textures
			if 'remove' in value:
				var splitValue = value.split("\"")
				var thisButton = get_node("MainGame/ButtonLayer/Button%s" % splitValue[1])
				thisButton.texture_normal = null
				thisButton.texture_hover = null
				continue
			
			if 'hideall' in value or 'hide all' in value:
				for button in get_node("MainGame/ButtonLayer").get_children():
					if button.get_child_count() > 0:
						pass
					else:
						var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
						if thisButton.is_visible():
							thisButton.hide()
				continue
			
			if 'showall' in value or 'show all' in value:
				for button in get_node("MainGame/ButtonLayer").get_children():
					if button.get_child_count() > 0:
						pass
					else:
						var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
						thisButton.show()
				continue
			
			var s = GDScript.new()
			
			var subTag = value.split('\",')
			
			var buttonID = subTag[0].split("\"")[1]
			# setting the button script
			# Buttons that don't follow pre-made functionallity will have to add their ID here
			# maybe have functionallity to add button code from the script file?
			match buttonID:
				'StartButton': s.set_source_code("extends TextureButton\n\nfunc _pressed():\n\treturn get_tree().get_root().get_node(\"MainNode\").mainParserLoop('*start')")
				'LoadButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tprint(\"here\")")
				'ConfigButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tpass")
				'ExtraButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tpass")
				'ExitButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\treturn get_tree().quit()")
				'custom': s.set_source_code("extends TextureButton\nfunc _pressed():\n\t%s" % subTag[6].split('= ')[1].split(']')[0])
				_: s.set_source_code("extends TextureButton\nfunc _ready():\n\tpass")
			s.reload()
			
			var slot = subTag[1].split("\"")[1]
			var button = get_node("MainGame/ButtonLayer/Button%s" % slot)
			button.set_script(s)
			# set the normal button texture
			button.texture_normal = load("res://%s" %subTag[2].split("\"")[1])
			# if there is a hover texture, set it here
			button.texture_hover = load("res://%s" %subTag[3].split("\"")[1])
			# get the position of the button
			var pos = subTag[4].split("\"")[1].split(',')
			button.rect_position = Vector2(pos[0], pos[1])
			# set the size of the button
			var size = subTag[5].split("\"")[1].split(',')
			button.rect_size = Vector2(size[0], size[1])
			button.show()
			continue
			
		if '[menubg' in value:
			var node = get_node("MainGame/OptionsLayer/Menu")
			if 'remove' in value:
				node.texture = null
				continue
			var splitValue = value.split("\"")
			node.texture = load("res://art/system/%s" % splitValue[1])
			continue
		return
	
	
# saving and loading the game
# doesn't do anything yet
func loadGame(dir):
	var directory = Directory.new()
	if directory.file_exists("user://save/%s" % dir):
		var loadFile = File.new()
		loadFile.open("user://save/%s" % dir, File.READ)
	else:
		pass
		
# doesn't save anything yet
func saveGame(isNewDir):
	if isNewDir:
		var directory = Directory.new()
		directory.make_dir_recursive("user://save/")
		var saveFile = File.new()
		saveFile.open("user://save/save.sps", File.WRITE)
		saveFile.store_var(startLine)
	else:
		var saveFile = File.new()
		saveFile.open("user://save/save.sps", File.WRITE)
		saveFile.store_var(startLine)


# =============================== setting up all data from file ===============================

# This is called as the game is run (before the splashscreen is even created)
# This reads the config.spcf file to create the game's nodes
func loadData(vars):
	
	# return a list of files in the directory
	var fileNames = listAllFilesInDirectory("res://scenario/")
	print(fileNames)
	
	# save the file lines as lists
	for name in fileNames:
		# open the file
		var file = File.new()
		file.open('res://scenario/%s' % name, File.READ)
		var fileText = file.get_as_text()
		# check if it's a config file
		if name.ends_with('.spcf'):
			for value in fileText.split('\n', false):
				config.append(value)
		elif name.ends_with('.spd'):
			dialogueFile = parse_json(fileText)
			if dialogueFile == null:
				print('\n\nERROR: JSON FILE IS NONEXISTENT OR HAS A SYNTAX ERROR\n\n')
		else:
			for value in fileText.split('\n', false):
				gameScenario.append(value)
		file.close()
	
	# insert the dialogue from the dialogue file into the script at runtime
	for value in dialogueFile:
		if value.begins_with('#'):
			continue
		var lineCount = 0
		for line in gameScenario:
			# print(line)
			gameScenario[lineCount] = gameScenario[lineCount].replace(value, dialogueFile[value])
			lineCount += 1
	
	preloadConfig(config)
	
	print("done loading data")
	emit_signal("initLoadDone")
	return


# go through the config file and create the GUI items
# this is being done here to make sure they are already created by the time the splashscreen appears
# this also makes the config file seperate from the other files
func preloadConfig(config):
	for value in config:
		if '[engine' in value:
			if '_version' in value:
				engineVersion = value.split('\"')[1]
			else:
				engineName = value.split('\"')[1]
			continue
		if '[game' in value:
			if '_version' in value:
				gameVersion = value.split('\"')[1]
			else:
				gameName = value.split('\"')[1]
			continue
		# make... slots for stuff
		if '[preload' in value:
			if 'fg' in value:
				var numberOfSlots = int(value.split(' ')[2].split(']')[0])
				var num = 1
				var splitValue = value.split("\"")
				while true:
					# seems to work well
					var this = load("res://scenes/Sprite.tscn").instance()
					this.name = "Sprite" + str(num)
					get_node(splitValue[1]).add_child(this)
					fgSlots[this.name] = true
					num += 1
					if num > numberOfSlots:
						break
			if 'buttons' in value:
				var numberOfSlots = int(value.split(' ')[2].split(']')[0])
				var num = 1
				var splitValue = value.split("\"")
				while true:
					# seems to work well
					var this = TextureButton.new()
					this.name = "Button" + str(num)
					this.hide()
					this.expand = true
					this.STRETCH_KEEP_ASPECT
					get_node(splitValue[1]).add_child(this)
					num += 1
					if num > numberOfSlots:
						break
			if 'sound' in value:
				var names = ['BgmPlayer', 'AmbiencePlayer', 'VoicePlayer', 'SoundPlayer']
				for value in names:
					var this = AudioStreamPlayer.new()
					this.name = value
					self.add_child(this)
			if 'video' in value:
				var this = VideoPlayer.new()
				this.name = 'VideoPlayer'
				# make sure it is fullscreen
				this.rect_size =  Vector2(1920, 1080)
				self.add_child(this)
			continue
		# containers currently do not work
		if '[container' in value:
			var splitValue = value.split("\"")
			if 'MainNode' in splitValue[3]:
				var MainContainer = Container.new()
				MainContainer.name = splitValue[1]
				self.add_child(MainContainer)
			else:
				var subContainer = Container.new()
				subContainer.name = splitValue[1]
				get_node(splitValue[3]).add_child(subContainer)
			continue
		if '[instantiate' in value:
			var splitValue = value.split("\"")
			get_node(splitValue[3]).call_deferred("add_child", load("res://scenes/%s.tscn" % splitValue[1]).instance())
			continue
			
		if 'menu' in value:
			var splitValue = value.split("\"")
			var this = TextureRect.new()
			this.name = splitValue[1]
			var pos = splitValue[3].split(',')
			var size = splitValue[5].split(',')
			this.rect_position = Vector2(pos[0], pos[1])
			this.rect_size = Vector2(size[0], size[1])
			get_node(splitValue[7]).add_child(this)
			continue


# lists all files in a given directory; used to find the dialogue and config files
func listAllFilesInDirectory(path):
    var files = []
    var dir = Directory.new()
    dir.open(path)
    dir.list_dir_begin()

    while true:
        var file = dir.get_next()
        if file == "":
            break
        elif not file.begins_with("."):
            files.append(file)

    dir.list_dir_end()
    return files


# file end
