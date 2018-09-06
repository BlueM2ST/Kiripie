extends Node2D

var gameScenario = {}
var config = []
var dialogueFile
var grammarTag = {}
var grammarRules = {}
var grammarSubtag = {}
var allGameFiles = {}

# for saving the game

# instead of saving the files that should be reloaded, reload the scene
#    from the sections and jumps. Display the images and text that would
#    show up at that point at the saved line.
# other things to save are the script variables, which are stored below.
# TODO: add section system for easier/quicker lookup
var saveLine = 0
var saveCharName = ''
var saveBGImage = ''
var save = ''

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
signal vnDialogueNext
signal initLoadDone
signal dialogueEnd

# threads
onready var loadingThread = Thread.new()
onready var dialogueThread = Thread.new()

onready var showCurrentLine = $ShowCurrentLine

onready var cancelDialogueAnimation = false
onready var inMenu = false

func _ready():
	loadingThread.start(self, "loadData")
	yield(self,"initLoadDone")
	# on starting that game, go to the config jump location to initialize the system
	mainParserLoop('*config')


func _input(event):
	# only check for input if there is no menu to be displayed and the game is not 'paused'
	if inMenu == false:
		# next text if enter keys or left click
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
			if cancelDialogueAnimation == false:
				cancelDialogueAnimation = true
			else:
				emit_signal("vnDialogueNext")
				
		if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER) and event.pressed:
			if cancelDialogueAnimation == false:
				cancelDialogueAnimation = true
			else:
				emit_signal("vnDialogueNext")
				
		else:
			pass


# =============================== parsing =====================================================
var loadingDone = false
var isBreak = false

# enable bebugger only if you are testing. Disable it for release
var enableDebugger = true

# check which background layer is showing; a or b
var bgLayerIsA = true
var charRightIsA = true
var diaAnimIsPlaying = false
# if the script should wait for an [endif]
var ifTrue = false
var inIf = false
var charName = ''
var scriptVariables = {}  # when a variable is set in the script, it is stored in this dictionary
var fgSlots = {}  # tracks the shown image of a sprite. For crossfade
func mainParserLoop(jumpStart, startLine=0):
	
	# for now will always start at the beginning
	saveGame(true)
	currentJump = jumpStart
	var foundJumpStart = false
	currentLine = 0
	
	# start the loop
	for value in gameScenario[jumpStart]:
		
		
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
			cancelDialogueAnimation = true
			var result = debugger(value)
			# for a release of the game, remove the debugger:
			# var result = value
			if 'error' in result:
				continue
			else:
				var clickToContinue = parser(result)
				if clickToContinue == true:
					pass
				else:
					continue
		cancelDialogueAnimation = false
		var dialogueToShow = charName + value
		showCurrentLine.set_text(engineName + '  :  ' + engineVersion + '  :  ' + gameName + '  :  ' + gameVersion + '  :  ' + currentJump + '  :  ' + str(currentLine))
		# reset the name value since not all text lines will have a name
		charName = ''
		# wait for a mouse click, enter key, etc.
		dialogue(dialogueToShow)
		yield(self, "vnDialogueNext")
		cancelDialogueAnimation = false
		get_node("VoicePlayer").stop()
		get_node("VideoPlayer").stop()
		get_node("VideoPlayer").hide()
		continue


func dialogue(dialogue):
	var currentDialogue = ''
	$Timer.wait_time = 0.001
	for value in dialogue:
		currentDialogue = currentDialogue + value
		$Timer.start()
		yield($Timer, "timeout")
		if cancelDialogueAnimation == true:
			get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/Dialogue").set_text(dialogue)
			return
		else:
			get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/Dialogue").set_text(currentDialogue)
			continue
	cancelDialogueAnimation = true
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
	
	# if debugger is enabled, it will check for additional error info
	if enableDebugger == true:
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
	var subtagDict = {p_variableName = '', p_variableValue = '', p_jump = '', p_source = '', p_storage = '', 
	p_slot = '', p_pos = '', p_id = '', p_delay = '', p_time = '', p_skippable = '', p_sizeX = '', 
	p_sizeY = '', p_parent = '', p_imgNormal = '', p_imgHover = '', p_instance = '', p_version = '',
	p_locX = '', p_locY = '', p_any = ''}
	var p_variableName
	var p_variableValue
	var p_jump
	var p_source
	var p_storage
	var p_slot
	var p_pos
	var p_id
	var p_delay
	var p_time
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
				subtagDict[p_parent] = p_parent
			break
		# skip over the main tag, this is only for subtags
		if skippedMainTag == false:
			skippedMainTag = true
			continue
			
		if 'var ' in subtag and '=' in subtag:
			subtag = subtag.split('var')[1]
			p_variableName = subtag.split('=')[0]
			p_variableValue = subtag.split('=')[1]
			subtagDict[p_variableName] = p_variableName
			subtagDict[p_variableValue] = p_variableValue
			continue
		if '*' in subtag:
			p_jump = subtag
			continue
		if 'source' in subtag and '=' in subtag:
			p_source = subtag.split('=')[1]
			subtagDict[p_source] = p_source
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
			subtagDict[p_storage] = p_storage
			continue
		if 'slot' in subtag:
			p_slot = subtagValue
			subtagDict[p_slot] = p_slot
			continue
		if 'pos' in subtag:
			p_pos = subtagValue
			subtagDict[p_pos] = p_pos
			continue
		if 'skipable' in subtag:
			p_skipable = subtagValue
			subtagDict[p_skipable] = p_skipable
			continue
		if 'delay' in subtag or 'time' in subtag:
			p_delay = subtagValue
			p_time = subtagValue
			subtagDict[p_delay] = p_delay
			subtagDict[p_time] = p_time
			continue
		if 'size' in subtag:
			p_sizeX = subtagValue.split('x')[0]
			p_sizeY = subtagValue.split('x')[1]
			subtagDict[p_sizeX] = p_sizeX
			subtagDict[p_sizeY] = p_sizeY
			continue
		if 'id' in subtag and '=' in subtag:
			p_id = subtagValue
			subtagDict[p_id] = p_id
			continue
		if 'parent' in subtag and '=' in subtag:
			p_parent = subtagValue
			subtagDict[p_parent] = p_parent
			continue
		if 'imgNormal' in subtag and '=' in subtag:
			p_imgNormal = subtagValue
			if not p_imgNormal in allGameFiles:
				print('ERROR: could not find storage location \"'+p_imgNormal+'\"')
				return
			p_imgNormal = allGameFiles[p_imgNormal][0]
			subtagDict[p_imgNormal] = p_imgNormal
			continue
		if 'imgHover' in subtag and '=' in subtag:
			p_imgHover = subtagValue
			if not p_imgHover in allGameFiles:
				print('ERROR: could not find storage location \"'+p_imgHover+'\"')
				return
			p_imgHover = allGameFiles[p_imgHover][0]
			subtagDict[p_imgHover] = p_imgHover
			continue
		if 'instance' in subtag and '=' in subtag:
			p_instance = subtagValue
			subtagDict[p_instance] = p_instance
			continue
		if 'version' in subtag and '=' in subtag:
			p_version = subtagValue
			subtagDict[p_version] = p_version
			continue
		if 'loc' in subtag and '=' in subtag:
			p_locX = subtagValue.split('x')[0]
			p_locY = subtagValue.split('x')[1]
			subtagDict[p_locX] = p_locX
			subtagDict[p_locY] = p_locY
			continue
		# else
		p_any = subtag.replace(' ', '')
		subtagDict[p_any] = p_any
	
	if 'call' in validTags[0]:
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
		
	if 'menu' in validTags[0]:
		print(validTags[2].split(' ')[1])
		menuParser(validTags[2].split(' ')[1], validTags, subtagDict)
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
		
	if 'delay' in validTags[0]:
#		$Timer.wait_time = float(p_time)
#		$Timer.start()
#		yield($Timer, "timeout")
		return
	
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
			if p_delay:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = float(p_delay)
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play("fade")
			else:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = 1
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play("fade")
			bgLayerIsA = false
		else:
			get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load(p_storage)
			if p_delay:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = float(p_delay)
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play_backwards("fade")
			else:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = 1
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play_backwards("fade")
				
			bgLayerIsA = true
		return
	
	# This sets the character name in the text box
	if 'name' in validTags[0]:
		get_node("MainGame/DialogueLayer").show()
		charName = '【%s】\n' % p_any
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
	# for everything to do with buttons
	if 'button' in validTags[0]:
		
#		for N in get_node("MainGame/ButtonLayer").get_children():
#			if N.get_child_count() > 0:
#				print("["+N.get_name()+"]")
#				# getallnodes(N)
#			else:
#				# Do something
#				print("- "+N.get_name())
		
		if 'delall' in validTags:
			for button in get_node('MainGame/ButtonLayer').get_children():
				if button.get_child_count() > 0:
					pass
				else:
					var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
					thisButton.texture_normal = null
					thisButton.texture_hover = null
					if thisButton.is_visible():
						thisButton.hide()
			return

		# actually just removes the textures
		if 'remove' in validTags:
			var thisButton = get_node("MainGame/ButtonLayer/Button%s" % p_slot)
			thisButton.texture_normal = null
			thisButton.texture_hover = null
			return
		
		if 'hideall' in validTags:
			for button in get_node("MainGame/ButtonLayer").get_children():
				if button.get_child_count() > 0:
					pass
				else:
					var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
					if thisButton.is_visible():
						thisButton.hide()
			return
		
		if 'showall' in validTags:
			for button in get_node("MainGame/ButtonLayer").get_children():
				if button.get_child_count() > 0:
					pass
				else:
					var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
					thisButton.show()
			return
		
		var s = GDScript.new()
		
		# setting the button script
		# Buttons that don't follow pre-made functionallity will have to add their ID here
		# maybe have functionallity to add button code from the script file?
		match p_id:
			'StartButton': s.set_source_code("extends TextureButton\n\nfunc _pressed():\n\tself.hide()\n\treturn get_tree().get_root().get_node(\"MainNode\").mainParserLoop('*start')")
			'LoadButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tprint(\"here\")")
			'ConfigButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tpass")
			'ExtraButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tpass")
			'ExitButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\treturn get_tree().quit()")
			'custom': s.set_source_code("extends TextureButton\nfunc _pressed():\n\t%s" % p_source)
			_: s.set_source_code("extends TextureButton\nfunc _ready():\n\tpass")
		s.reload()
		
		var button = get_node("MainGame/ButtonLayer/Button%s" % p_slot)
		button.set_script(s)
		# set the normal button texture
		button.texture_normal = load(p_imgNormal)
		# if there is a hover texture, set it here
		button.texture_hover = load(p_imgHover)
		# get the position of the button
		button.rect_position = Vector2(p_locX, p_locY)
		# set the size of the button
		button.rect_size = Vector2(p_sizeX, p_sizeY)
		button.show()
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
			var numberOfSlots = 12
			var num = 0
			while true:
				# seems to work well
				var thisButton = TextureButton.new()
				thisButton.name = "Button" + str(num)
				thisButton.hide()
				thisButton.expand = true
				thisButton.STRETCH_KEEP_ASPECT
				get_node('MainGame/ButtonLayer').add_child(thisButton)
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
		
#	if 'menu' in validTags[0]:
#		var this = TextureRect.new()
#		this.name = p_id
#		this.rect_position = Vector2(p_locX, p_locY)
#		this.rect_size = Vector2(p_sizeX, p_sizeY)
#		get_node(p_parent).add_child(this)
#		return
		
	return
	
func menuParser(menujump, validTags, subtagDict):
	var foundMenu = false
	for value in gameScenario['*menu']:
		if menujump in value:
			foundMenu = true
			continue
		
		# if it has reached another menu tag, don't read it as well
		if foundMenu == true and '@@' in value:
			return
			
		if foundMenu == true:
			if 'setfront' in value:
				inMenu = true
				continue
				
			if 'menuimg' in value:
				get_node("MainGame/DialogueLayer").hide()
				get_node("MainGame/OptionsLayer/OptionsTexture").texture = load(value.split('\"')[1])
				continue
			
			# most of this is placeholder until I incorporate the menu system better
			if 'button' in value:
				if 'delall' in validTags:
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
				if 'remove' in validTags:
					var thisButton = get_node("MainGame/ButtonLayer/Button%s" % value.split('\"')[3])
					thisButton.texture_normal = null
					thisButton.texture_hover = null
					continue
				
				if 'hideall' in validTags:
					for button in get_node("MainGame/ButtonLayer").get_children():
						if button.get_child_count() > 0:
							pass
						else:
							var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
							if thisButton.is_visible():
								thisButton.hide()
					continue
				
				if 'showall' in validTags:
					for button in get_node("MainGame/ButtonLayer").get_children():
						if button.get_child_count() > 0:
							pass
						else:
							var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
							thisButton.show()
					continue
				
				var s = GDScript.new()
				
				# setting the button script
				# Buttons that don't follow pre-made functionallity will have to add their ID here
				# maybe have functionallity to add button code from the script file?
				match value.split('\"')[1]:
					'StartButton': s.set_source_code("extends TextureButton\n\nfunc _pressed():\n\tself.hide()\n\treturn get_tree().get_root().get_node(\"MainNode\").mainParserLoop('*start')")
					'LoadButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tprint(\"here\")")
					'ConfigButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tpass")
					'ExtraButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\tpass")
					'ExitButton': s.set_source_code("extends TextureButton\nfunc _pressed():\n\treturn get_tree().quit()")
					'custom': s.set_source_code("extends TextureButton\nfunc _pressed():\n\t%s" % value.split('\"')[13])
					_: s.set_source_code("extends TextureButton\nfunc _ready():\n\tpass")
				s.reload()
				
				var button = get_node("MainGame/ButtonLayer/Button%s" % value.split('\"')[3])
				button.set_script(s)
				# set the normal button texture
				button.texture_normal = load(allGameFiles[value.split('\"')[9]][0])
				# if there is a hover texture, set it here
				button.texture_hover = load(allGameFiles[value.split('\"')[11]][0])
				# get the position of the button
				button.rect_position = Vector2(int(value.split('\"')[5].split('x')[0]), int(value.split('\"')[5].split('x')[1]))
				# set the size of the button
				button.rect_size = Vector2(int(value.split('\"')[7].split('x')[0]), int(value.split('\"')[7].split('x')[1]))
				button.show()
				continue
		
			

	
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
#	get_viewport().queue_screen_capture()
#	yield(get_tree(), "idle_frame")
#	yield(get_tree(), "idle_frame")
#	var saveImage = get_viewport().get_screen_capture()
	var time = OS.get_datetime()
	time = "%s_%02d_%02d_%02d%02d%02d" % [time['year'], time['month'], time['day'], time['hour'], time['minute'], time['second']]
	if isNewDir:
		var directory = Directory.new()
		directory.make_dir_recursive("user://save/")
	var saveFile = File.new()
	saveFile.open("user://save/save.sps", File.WRITE)
	saveFile.store_var(startLine)
	saveFile.store_var(time)
#	saveImage.flip_y()
#	saveImage.save_png("user://save/save.png")
	return


# =============================== setting up all data from file ===============================

# This is called as the game is run (before the splashscreen is even created)
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
	# print(fileNames)
	
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
		if name.ends_with('.kp'):
			# keep the newline, otherwise the value will not be saved in the list (for accurate line counting)
			var thisSectionJump = ''
			for value in fileText.split('\n', true):
				if value.begins_with('*'):
					thisSectionJump = value
					gameScenario[thisSectionJump] = []
				# keep blank lines, they will be handled (skipped) by the parser, but the line counted
				if value == '\n':
					pass
				# remove newline characters like usual if it is dialogue or a tag
				else:
					value.replace('\n', '')
				# remove tabs, they don't serve any purpose (yet?)
				value = value.replace("\t", "")
				gameScenario[thisSectionJump].append(value)
		else:
			pass
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
