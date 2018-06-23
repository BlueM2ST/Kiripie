extends Node

var gameScenario = []
var config = []
var dialogueFile
var grammarTag = {}
var grammarRules = {}
var grammarSubtag = {}
var allGameFiles = {}

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
	# on starting that game, go to the config jump location to initialize the system
	mainParserLoop('*config')


func _input(event):
	# if left click, go to the next text
	if (event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed):
    	emit_signal("vnDialogueNext")
	# also go to the next text if either enter key is pressed
	if (event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER) and event.pressed):
		emit_signal("vnDialogueNext")


# =============================== parsing =====================================================
var loadingDone = false
var isBreak = false

# check which background layer is showing; a or b
var bgLayerIsA = true
var charRightIsA = true
# if the script should wait for an [endif]
var ifTrue = false
var inIf = false
var scriptVariables = {}  # when a variable is set in the script, it is stored in this dictionary
var fgSlots = {}  # tracks the shown image of a sprite. For crossfade
func mainParserLoop(jumpStart, startLine=0):
	
	#get_node("MainGame").show()
	# for now will always start at the beginning
	saveGame(true)
	currentJump = jumpStart
	var name = ''
	var foundJumpStart = false
	print(allGameFiles)
	
	# start the loop
	for value in gameScenario:
		
		# line counting actually works now
		currentLine += 1
		
		if isBreak == true:
			isBreak = false
			return
		if value.begins_with('#') or value == '':
			continue
		# currently, the parser will loop through the lines in the file until it finds the jump location
		if not foundJumpStart:
			if not jumpStart in value:
				continue
			else:
				foundJumpStart = true
				continue
		if '[endif]' in value:
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
			continue
		
		# check if the line is a tag
		if value.begins_with("["):
			var result = debugger(value)
			if 'error' in result:
				continue
			else:
				var clickToContinue = parser(result)
				if clickToContinue == true:
					pass
				else:
					continue
		
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
		continue
		
# TODO: add this to the main parser
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


func debugger(tag):
	var regex = RegEx.new()
	var checkedtags = []
	var mainTag = ''
	var foundNoValidSubtags = true
	var hasInvalidSubtag = false
	var usedSubtags = []
	var errorReturn = ['error']
	
	# remove the opening and closing square brackets, they are only used to tell the parser that this is a tag
	tag = tag.replace('[', '').replace(']', '')
	
	if ' ' in tag:
		mainTag = tag.split(' ')[0]
	else:
		mainTag = tag
	if not mainTag in grammarTag:
		print('ERROR: tag <'+mainTag+'> does not exist on line ' + str(currentLine))
		return errorReturn
	checkedtags.append(mainTag)
	
	var thisTagsGrammarList = grammarTag[mainTag]
	
	for expression in grammarTag[mainTag]:
		var thisSubtag = expression
		# if it is supposed to jump to a regex value
		if '@' in expression:
			# remove the @, it is only for visual
			expression = expression.replace('@', '')
			expression = grammarSubtag[expression].split(';')[2]
			# if the tag is not supposed to have any subtags
			if '--' in expression:
				foundNoValidSubtags = false
				usedSubtags.append(thisSubtag)
				break
		regex.compile(expression)
		# makes sure the regex is valid
		if regex.is_valid() == false:
			print('ERROR: bad regex value: ' + expression)
			return errorReturn
		# if the regex could not match anything
		if regex.search(tag) == null:
			continue
		# only pass valid tags to the parser
		checkedtags.append(regex.search(tag).get_string())
		foundNoValidSubtags = false
		usedSubtags.append(thisSubtag)
		continue
	if foundNoValidSubtags:
		print('ERROR: no valid subtags found for tag <' +mainTag+ '> on line '+str(currentLine)+' , skipping tag')
		return errorReturn
	
	# check if the tag has rules for the use of its subtags
	if not null in grammarRules[mainTag]:
		for ruleTag in grammarRules[mainTag]:
			if '*' in ruleTag:
				var requiredSubtag = ruleTag.split('*')
				if not requiredSubtag[1] in usedSubtags:
					print("ERROR: must use subtag <"+requiredSubtag[1]+"> for tag <"+mainTag+"> on line "+str(currentLine))
					return errorReturn
			if '--' in ruleTag:
				var unusableTogether = ruleTag.split('--')
				if unusableTogether[0] in usedSubtags and unusableTogether[1] in usedSubtags:
					print("ERROR: cannot use both subtags <"+unusableTogether[0]+"> and <"+unusableTogether[1]+ "> for tag <"+mainTag+"> on line "+str(currentLine))
					return errorReturn
			if '->' in ruleTag:
				var subtagRequire = ruleTag.split('->')
				if subtagRequire[0] in usedSubtags:
					if not subtagRequire[1] in usedSubtags:
						print("ERROR: to use subtag <"+subtagRequire[0]+"> you must also use subtag <"+subtagRequire[1]+"> for tag <"+mainTag+"> on line "+str(currentLine))
						return errorReturn
	# this will be for single subtag tags. The single tag should be required by default
	else:
		pass
	
	return checkedtags

	
func parser(validTags):
	# print(validTags) # for debug
	
	# maybe set these as a dictionary instead of variables?
	var p_variableName
	var p_variableValue
	var p_jump
	var p_source
	var p_storage
	var p_slot
	var p_pos
	var p_id
	var p_skipable
	var p_sizeX
	var p_sizeY
	var p_parent
	var p_imgNormal
	var p_imgHover
	var p_instance
	var p_version
	var p_locX
	var p_locY
	var p_any
	
	var skippedMainTag = false
	for subtag in validTags:
		# preload is special; bandage solution
		if 'preload' in validTags[0]:
			if 'parent' in validTags:
				p_parent = subtag.split('\"')[1]
			break
		# skip over the main tag, this is only for subtags
		if skippedMainTag == false:
			skippedMainTag = true
			continue
			
		if 'var ' in subtag and '=' in subtag:
			subtag = subtag.split('var')[1]
			p_variableName = subtag.split('=')[0]
			p_variableValue = subtag.split('=')[1]
			continue
		if '*' in subtag:
			p_jump = subtag
			continue
		if 'source' in subtag and '=' in subtag:
			p_source = subtag.split('=')[1]
			continue
		
		var subtagValue = ''
		if '\"' in subtag:
			subtagValue = subtag.split('\"')[1]
		
		if 'storage' in subtag:
			p_storage = subtagValue
			# some debugging here
			if not p_storage in allGameFiles:
				print('ERROR: could not find storage location \"'+p_storage+'\"')
				return
			p_storage = allGameFiles[p_storage][0]
			continue
		if 'slot' in subtag:
			p_slot = subtagValue
			continue
		if 'pos' in subtag:
			p_pos = subtagValue
			continue
		if 'skipable' in subtag:
			p_skipable = subtagValue
			continue
		if 'size' in subtag:
			p_sizeX = subtagValue.split('x')[0]
			p_sizeY = subtagValue.split('x')[1]
			continue
		if 'id' in subtag and '=' in subtag:
			p_id = subtagValue
			continue
		if 'parent' in subtag and '=' in subtag:
			p_parent = subtagValue
			continue
		if 'imgNormal' in subtag and '=' in subtag:
			p_imgNormal = subtagValue
			continue
		if 'imgHover' in subtag and '=' in subtag:
			p_imgHover = subtagValue
			continue
		if 'instance' in subtag and '=' in subtag:
			p_instance = subtagValue
			continue
		if 'version' in subtag and '=' in subtag:
			p_version = subtagValue
			continue
		if 'loc' in subtag and '=' in subtag:
			p_locX = subtagValue.split('x')[0]
			p_locY = subtagValue.split('x')[1]
			continue
		# else
		p_any = subtag.replace(' ', '')
	
	if 'call' in validTags[0]:
		print(p_any)
		if 'reloadSystem' in p_any:
			return get_tree().reload_current_scene()
		if 'reloadGame' in p_any:
			mainParserLoop('*splashscreen')
		if 'menuParser' in p_any:
			return menuParser( p_any.split(' ')[2])
		return
	
	# Print text from the game script in the game's console
	if 'print' in validTags[0]:
		print('DEBUG:  ' +  p_any)
		return
	
	# to set a variable from the script
	if 'set' in validTags[0]:
		scriptVariables[p_variableName] = p_variableValue
		return
	
	if 'if' in validTags[0]:
		inIf = true
		if 'var' in validTags:
			# if the condition is met
			if scriptVariables[p_variableName] == p_variableValue:
				ifTrue = true
			else:
				pass
		else:
			pass
		return
	
	# 'img' and 'bgimg' are very similar. In fact, they are using the same nodes
	# But 'img' will replace the background image *and* hides the dialogue box
	# if showing and hiding the dialogue box becomes a tag, this might not be needed
	# Instead, it can be for images that go overtop the entire scene
	if validTags[0] == 'img':
		get_node("MainGame/DialogueLayer").hide()
		get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load(p_storage)
		return true
	
	# This is for sprites
	# this handles everything to do with basic sprites
	if 'fgimg' in validTags[0]:
		# remove the image from a given slot
		if 'remove' in validTags:
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % p_slot).texture = null
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % p_slot).texture = null
			return
		var havePos = false
		if 'pos' in validTags:
			havePos = true
		get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % p_slot).playback_speed = 2
		# assign the position of the sprite slot
		if havePos == true:
			match p_pos:
				'right':
					get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % p_slot).rect_position = Vector2(450, 0)
					get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % p_slot).rect_position = Vector2(450, 0)
				'left':
					get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % p_slot).rect_position = Vector2(-450, 0)
					get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % p_slot).rect_position = Vector2(-450, 0)
				'center':
					get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % p_slot).rect_position = Vector2(0, 0)
					get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % p_slot).rect_position = Vector2(0, 0)
		# Every sprite slot has its ID assigned by its name
		# Every slot also has a 'background' and 'foreground' layer where only the foreground of the sprite is shown
		# This is done for crossfade animations
		if fgSlots['Sprite%s' % p_slot]:
			print(p_storage)
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % p_slot).texture = load(p_storage)
			get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % p_slot).play("crossfade")
			fgSlots['Sprite%s' % p_slot] = false
		else:
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % p_slot).texture = load(p_storage)
			get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % p_slot).play_backwards("crossfade")
			fgSlots['Sprite%s' % p_slot] = true
		return
		
	# Works similarly to the fgimg slots for crossfade, but is simpler since there is nothing
	#    behind the bgimage and there is only one background
	if 'bgimg' in validTags[0]:
		
		### keep this for bug fixing; it checks for childen of a node
#		for N in self.get_children():
#			if N.get_child_count() > 0:
#				print("["+N.get_name()+"]")
#				# getallnodes(N)
#			else:
#				# Do something
#				print("- "+N.get_name())
		
		# Background will always fade, even without 'fadein'
		# I don't think there is any reason for background images to not fade, but it is easy to add in here
		
		#if 'fadein' in value:
		if bgLayerIsA:
			get_node("MainGame/BgLayer/BgImage/BgImage_b").texture = load(p_storage)
			get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play("fade")
			bgLayerIsA = false
		else:
			get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load(p_storage)
			get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play_backwards("fade")
			bgLayerIsA = true
#			else:
#				get_node("MainGame/BgImage/BgImage_a").texture = load("res://art/bgimage/%s" % imgPath)
		return
	
	# This sets the character name in the text box
	if 'name' in validTags[0]:
		get_node("MainGame/DialogueLayer").show()
		name = '【%s】\n' % p_any
		return
	
	# Every 'type' of sound has its own node
	
	# This is for short sounds that do not repeat, like a door closing
	if 'se' in validTags[0]:
		$SoundPlayer.stream = load(p_storage)
		$SoundPlayer.volume_db = -5
		$SoundPlayer.play()
		return
		
	# This is for repeating background noise, like the buzzing of cicadas
	if 'amb' in validTags[0]:
		if 'stop' in validTags:
			$AmbiencePlayer.stop()
			return
		$AmbiencePlayer.stream = load(p_storage)
		$AmbiencePlayer.volume_db = -5
		$AmbiencePlayer.play()
		return
		
	# This is for standard background music
	# remember looping of music has to be done in the Godot editor under import settings
	if 'bgm' in validTags:
		if 'stop' in validTags:
			$BgmPlayer.stop()
			return
		$BgmPlayer.stream = load(p_storage)
		$BgmPlayer.volume_db = -9
		$BgmPlayer.play()
		return
		
	# A quick way to stop all sounds
	if 'allsoundstop' in validTags:
		$BgmPlayer.stop()
		$VoicePlayer.stop()
		$AmbiencePlayer.stop()
		$SoundPlayer.stop()
		return
		
	# Plays a voice, very similar to 'se'
	# The voice will stop when the dialogue moves forward
	if 'voice' in validTags[0]:
		$VoicePlayer.stream = load(p_storage)
		$VoicePlayer.volume_db = -5
		$VoicePlayer.play()
		return
		
	# Plays a video
	# Will play overtop of everything(?) and waits for a mouse click to continue
	# TODO
	# BUG: If there is no mouse click and the video ends, it will display a blank screen/whatever was behind it before
	#      and will still wait for a a signal. Will fix once 'video end' signals are implemented in Godot
	if 'video' in validTags[0]:
		if p_storage == null:
			print('ERROR: Could not find video file')
			return
		get_node("MainGame/DialogueLayer").hide()
		# stop all other music
		get_node("BgmPlayer").stop()
		# $VoicePlayer.stop()
		get_node("AmbiencePlayer").stop()
		get_node("SoundPlayer").stop()
		get_node("VideoPlayer").show()
		
		get_node("VideoPlayer").stream = load(p_storage)
		get_node("VideoPlayer").volume_db = -5
		get_node("VideoPlayer").play()
		return true
		# commented out for proper video skipping
#		if skippable != 'true':
#			continue
#		else:
#			continue

	# sets the dialogue box image, position, and size
	# This allows to use the same text box and dialogue label for NVL style VNs
	# It also allows for more customized text boxes and text positioning
	# TODO: this should have the options 'show' and 'hide' with animations to match.
	# the tag should also be cleaned up a bit
	if 'dialogue' in validTags[0]:
		if 'box' in validTags:
			var dialogueBox = get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox")
			dialogueBox.rect_position = Vector2(p_locX, p_locY)
			dialogueBox.rect_size = Vector2(p_sizeX, p_sizeY)
			dialogueBox.texture = load(p_storage)
		if 'text' in validTags:
			var textBox = get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/Dialogue")
			textBox.rect_position = Vector2(p_locX, p_locY)
			textBox.rect_size = Vector2(p_sizeX, p_sizeY)
		return
		
	# jumps to a jump location
	if 'jump' in validTags[0]:
		currentJump = p_jump
		return mainParserLoop(p_jump)
	
	# another way to end a section
	# shouldn't be used in most games, but can allow for very specific scenes
	if 'sec' in validTags:
		pass
		
	# this should rarely need to be used directly, only as a fallback or for testing
	if 'break' in validTags:
		isBreak = true
		return
	
	# go through the config file and create the GUI items
	# this is being done here to make sure they are already created by the time the splashscreen appears
	# this also makes the config file seperate from the other files
	if 'engine' in validTags[0]:
		engineVersion = p_version
		engineName = p_id
		return
	if 'game' in validTags[0]:
		gameVersion = p_version
		gameName = p_id
		return
	# make... slots for stuff
	if 'preload' in validTags[0]:
		if 'fg' in validTags:
			var numberOfSlots = 14
			var num = 1
			while true:
				# seems to work well
				var this = load("res://scenes/Sprite.tscn").instance()
				this.name = "Sprite" + str(num)
				get_node('MainGame/CharacterLayer').add_child(this)
				fgSlots[this.name] = true
				num += 1
				if num > numberOfSlots:
					return
		if 'buttons' in validTags:
			var numberOfSlots = 10
			var num = 1
			while true:
				# seems to work well
				var this = TextureButton.new()
				this.name = "Button" + str(num)
				this.hide()
				this.expand = true
				this.STRETCH_KEEP_ASPECT
				get_node(p_parent).add_child(this)
				num += 1
				if num > numberOfSlots:
					return
		if 'sound' in validTags:
			var names = ['BgmPlayer', 'AmbiencePlayer', 'VoicePlayer', 'SoundPlayer']
			for validTags in names:
				var this = AudioStreamPlayer.new()
				this.name = validTags
				self.add_child(this)
		if 'video' in validTags:
			var this = VideoPlayer.new()
			this.name = 'VideoPlayer'
			# make sure it is fullscreen
			this.rect_size =  Vector2(1920, 1080)
			self.add_child(this)
		return
	# containers currently do not work
	if 'container' in validTags[0]:
		if 'MainNode' in p_parent:
			var MainContainer = Container.new()
			MainContainer.name = p_id
			self.add_child(MainContainer)
		else:
			var subContainer = Container.new()
			subContainer.name = p_id
			get_node(p_parent).add_child(subContainer)
		return
	if 'instantiate' in validTags:
		var inst = load("res://scenes/%s.tscn" % p_instance).instance()
		get_node(p_parent).add_child(inst)
		return
		
	if 'menu' in validTags[0]:
		var this = TextureRect.new()
		this.name = p_id
		this.rect_position = Vector2(p_locX, p_locY)
		this.rect_size = Vector2(p_sizeX, p_sizeY)
		get_node(p_parent).add_child(this)
		return
		
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
	
	# saving the directories of all game files in memory
	# will only go two directories deep, deeper files will not be allowed by the debugger
	# TODO: allow files no matter how deep in the file directory they are
	# TODO: split the files up into sections ex. voice, bg for quicker debug lookup
	var allFiles = listAllFilesInDirectory("res://")
	for file in allFiles:
		if '.import' in file:
				continue
		allGameFiles[file] = ["res://"+file]
		if '.' in file:
			continue
		var subFiles = listAllFilesInDirectory("res://%s" %file)
		for sub in subFiles:
			if '.import' in sub:
				continue
			allGameFiles[sub] = ["res://"+file+"/"+sub]
			if '.' in file:
				continue
			var lastSubFiles = listAllFilesInDirectory("res://"+file+"/"+sub)
			for lastsub in lastSubFiles:
				if '.import' in lastsub:
					continue
				allGameFiles[lastsub] = ["res://"+file+"/"+sub+"/"+lastsub]
	
	# return a list of files in the directory
	var fileNames = listAllFilesInDirectory("res://scenario")
	print(fileNames)
	
	# save the file lines as lists
	# TODO: hook this up with the dictionary defined above of all the file paths
	for name in fileNames:
		# open the file
		var file = File.new()
		file.open('res://scenario/%s' % name, File.READ)
		var fileText = file.get_as_text()
		# check if it's a config file
		if name.ends_with('.kpcf'):
			for value in fileText.split('\n', false):
				# ignore the comments and empty lines since there is no debugger yet for the config file
				if value == '\n' or value.begins_with('#') or value.begins_with('@@'):
					continue
				# remove spaces
				value = value.replace(' ', '')
				var grammarList = value.split(';')
				if grammarList[0] == "tag":
					var canHave = []
					var rules = []
					# for what the tag can have
					if ',' in grammarList[2]:
						for value in grammarList[2].split(','):
							canHave.append(value)
					else:
						canHave.append(grammarList[2])
					# for the rules of using the subtags and what subtags the tag requires
					if grammarList.size() > 3:
						if ',' in grammarList[3]:
							for value in grammarList[3].split(','):
								rules.append(value)
						else:
							rules.append(grammarList[3])
					else:
						rules.append(null)
					# add the lists to the global-scope variables
					grammarTag[grammarList[1]] = canHave
					grammarRules[grammarList[1]] = rules
				else:
					grammarSubtag[grammarList[1]] = value
		# TODO: make localization happen as lines are needed
#		elif name.ends_with('.kpd'):
#			dialogueFile = parse_json(fileText)
#			if dialogueFile == null:
#				print('\n\nERROR: JSON FILE IS NONEXISTENT OR HAS A SYNTAX ERROR\n\n')
		else:
			# keep the newline, otherwise the value will not be saved in the list (for accurate line counting)
			for value in fileText.split('\n', true):
				# keep blank lines, they will be handled (skipped) by the parser, but the line counted
				if value == '\n':
					pass
				# remove newline characters like usual if it is dialogue or a tag
				else:
					value.replace('\n', '')
				# remove tabs, they don't serve any purpose (yet?)
				value = value.replace("\t", "")
				gameScenario.append(value)
		file.close()
	
	# insert the dialogue from the dialogue file into the script at runtime
#	for value in dialogueFile:
#		if value.begins_with('#'):
#			continue
#		var lineCount = 0
#		for line in gameScenario:
#			# print(line)
#			gameScenario[lineCount] = gameScenario[lineCount].replace(value, dialogueFile[value])
#			lineCount += 1
	
	print("done loading data")
	emit_signal("initLoadDone")
	return


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
