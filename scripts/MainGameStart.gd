extends Node2D

# for loading data from files
var gameScenario = {}
var grammarTag = {}
var grammarRules = {}
var grammarSubtag = {}
var allGameFiles = {}
var buttonScript = {}
var languages = {}

# The encryption key for save files. You can set it to any string
var encryptionKey = '@theVeryLeast#SlackenTheMaize'

# if releasing/building the game in debug, it should be reading from the *.pck file, not the original files
var debugRelease = false

# enabling the debugger will decrease performance, but give more insight into the tags used in the *.kp files
# disable this if you are releasing/building the game
# TODO: this will actually not work how it is currently, since it is based on the old script loading system.
#       Please do not enable this. If you typed a tag incorrectly, 
#       Godot will most likely crash, so that can be the warning until I get this working again.
var enableDebugger = false

# for skip mode
var inSkipMode = false
# the text should display much faster if in skip mode
var skipTextSpeed = 0.009
var inAutoMode = false

# for laoding
var loadingSave = false
var forceLoad = false

# for testing
# TODO: add these to OS.set_window_title(), since they don't do anything anymore
var engineVersion = ''
var engineName = ''
var gameName = ''
var gameVersion = ''

# for saving the game
# TODO: rename these for better readability
var savePage = 1
var configSave = {'fullscreen': false, 'canLoad': true, 'autoSkip': false, 'textSpeed': 0.0007, 'language': 'en', 'autoSpeed': 7,
				'farthestProgress': [0, '*config'], 'extraCondition': '', 'finishedGame': 'false'}

var saveOptions = {'jump': '*config', 'line': 0, 'fgImages': {}, 'bgImage': '', 
					'menu': '', 'scriptVariables': {}, 'charName': '\n', 'currentLine': 0, 'currentDialogue': '',
					'dialogueBoxImage': '', 'dialogueBoxSize': ''}
					
var subtagStorage = {'mainTag': '', 'variableName': '', 'variableValue': '', 'storage': '', 
	'slot': '', 'pos': '', 'id': '', 'delay': '', 'sizeX': '', 
	'sizeY': '', 'parent': '', 'imgNormal': '', 'imgHover': '', 'instance': '', 'version': '',
	'locX': '', 'locY': '', 'imgPressed': '', 'wildcard': '', 'generic': ''}

# signals
signal vnDialogueNext
signal initLoadDone
signal dialogueEnd

# threads
# TODO: check this thread
onready var loadingThread = Thread.new()

onready var cancelDialogueAnimation = false
onready var nextDialogue = false
onready var setSignal = false
onready var inMenu = false

func _ready():
	# set viewport to the camera
	$MainCamera.make_current ( )
	# load initial data
	loadingThread.start(self, "loadData")
	yield(self,"initLoadDone")
	# on starting that game, go to the config jump location to initialize the system
	mainParserLoop('*config')
	
func _process(delta):
	OS.set_window_title("Koi Musibi Demo, Beta Build | fps: " + str(Engine.get_frames_per_second()) + ' | jump: ' + saveOptions['jump'] + ' | line: ' + str(saveOptions['currentLine']))
	if setSignal == true:
		emit_signal("vnDialogueNext")
		setSignal = false

func _input(event):
	# only check for input if there is no menu to be displayed and the game is not 'paused'
	if inMenu == false:
		if event is InputEventKey and (event.scancode == KEY_ENTER or event.scancode == KEY_KP_ENTER) and event.pressed:
			# pressing enter will take the game out of auto mode or skip mode
			if inAutoMode or inSkipMode:
				if inAutoMode:
					inAutoMode = false
				else:
					inSkipMode = false
			else:
				if cancelDialogueAnimation == false:
					cancelDialogueAnimation = true
				else:
					emit_signal("vnDialogueNext")


# =============================== parsing =====================================================
var loadingDone = false
var isBreak = false

# check which background layer is showing; a or b
var bgLayerIsA = true
var charRightIsA = true
var diaAnimIsPlaying = false
# if the script should wait for an [endif]
var ifTrue = false
var inIf = false
var fgSlots = {}  # tracks the shown image of a sprite. For crossfade
func mainParserLoop(jumpStart, startLine=0, loadingFromSaveFile = false):
	
	saveOptions['jump'] = jumpStart
	saveOptions['currentLine'] = 0
	
	# start the loop
	for value in gameScenario[jumpStart]:
		
		# when loading a game, end this function and make a new one
		# TODO: when building, it will make a new mainParserLoop() function, but not end the old one
		#       However, in the editor it will work fine. 
		#       --> Make a new function to call this one, and end and start this loop
		if forceLoad:
			forceLoad = false
			return mainParserLoop(saveOptions['jump'])
			
		# line counting
		saveOptions['currentLine'] += 1
		
		# make sure the load gets to the correct line, don't overwrite the saved value
		if not loadingSave:
			saveOptions['line'] = saveOptions['currentLine']
		
		# TODO: maybe use something like this for loading
		if isBreak == true:
			isBreak = false
			return
		# don't read comments
		if value.begins_with('#') or value == '':
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
			continue
		
		# check if the line is a tag
		if value.begins_with("["):
			cancelDialogueAnimation = true
			# for a release of the game, remove the debugger:
			if enableDebugger:
				var result = debugger(value)
				if result == 'error':
					continue
			# TODO: maybe call the parser from the lexer?
			lexer(value)
			var clickToContinue = parser()
			subtagClear()
			if str(clickToContinue) == 'pass':
				pass
			else:
				continue
		# if loading a save, don't display the dialogue until the saved line is found
		if loadingSave:
			if saveOptions['line'] == saveOptions['currentLine']:
				loadingSave = false
				pass
			else:
				saveOptions['charName'] = '\n'
				continue
		
		cancelDialogueAnimation = false
		
		# for localization support
		if value.begins_with('%'):
			# make sure it's valid
			if value in languages[configSave['language']]['dialogue']:
				value = languages[configSave['language']]['dialogue'][value]
		
		saveOptions['currentDialogue'] = value
		var dialogueToShow = saveOptions['charName'] + value
		# reset the name value since not all text lines will have a name
		saveOptions['charName'] = '\n'
		# wait for a mouse click, enter key, etc.
		dialogue(dialogueToShow)
		# in auto mode, there is no need to wait for user input.
		# It just waits a few seconds after the dialoge is displayed before continuing.
		# TODO: auto mode doesn't work very well yet: it doesn't wait for the text to be finished showing
		if inAutoMode or inSkipMode:
			if inSkipMode:
				$AutoTimer.wait_time = 0.1
			else:
				$AutoTimer.wait_time = configSave['autoSpeed']
			$AutoTimer.start()
			yield($AutoTimer, "timeout")
		else:
			yield(self, "vnDialogueNext")
		cancelDialogueAnimation = false
		get_node("VoicePlayer").stop()
		get_node("VideoPlayer").stop()
		get_node("VideoPlayer").hide()
		continue


# displaying dialogue in the textbox.
# TODO: this is the main cause of fps drops (30 -> ~15 sometimes)
#       Maybe this function doesn't return properly when the next dialogue line is playing,
#       resulting in two or more instances running.
func dialogue(dialogue):
	var currentDialogue = ''
	if not inSkipMode:
		$Timer.wait_time = configSave['textSpeed']
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
	else:
		get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/Dialogue").set_text(dialogue)
		return
	cancelDialogueAnimation = true
	return


# TODO: fix the debugger for the current version
func debugger(tag):
	var regex = RegEx.new()
	var mainTag = ''
	var foundNoValidSubtags = true
	var usedSubtags = []
	var errorReturn = 'error'
	
	# remove the opening and closing square brackets, they are only used to tell the parser that this is a tag
	# also replace spaces around the equals sign, as it's not needed
	tag = tag.replace('[', '').replace(']', '').replace(' = ', '=')
	
	# subtags are split by a space character
	if ' ' in tag:
		var splitTag = tag.split(' ')
		mainTag = splitTag[0]
	# if there is no space character in the tag, then it must have no subtags
	else:
		mainTag = tag
		
	if not mainTag in grammarTag:
		print('ERROR: tag <'+mainTag+'> does not exist on line ' + str(saveOptions['currentLine']))
		return errorReturn
	
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
		foundNoValidSubtags = false
		usedSubtags.append(thisSubtag)
		continue
	if foundNoValidSubtags:
		print('ERROR: no valid subtags found for tag <' +mainTag+ '> on line '+str(saveOptions['currentLine'])+' , skipping tag')
		return errorReturn
	
	# check if the tag has rules for the use of its subtags
	if not null in grammarRules[mainTag]:
		for ruleTag in grammarRules[mainTag]:
			if '*' in ruleTag:
				var requiredSubtag = ruleTag.split('*')
				if not requiredSubtag[1] in usedSubtags:
					print("ERROR: must use subtag <"+requiredSubtag[1]+"> for tag <"+mainTag+"> on line "+str(saveOptions['currentLine']))
					return errorReturn
			if '--' in ruleTag:
				var unusableTogether = ruleTag.split('--')
				if unusableTogether[0] in usedSubtags and unusableTogether[1] in usedSubtags:
					print("ERROR: cannot use both subtags <"+unusableTogether[0]+"> and <"+unusableTogether[1]+ "> for tag <"+mainTag+"> on line "+str(saveOptions['currentLine']))
					return errorReturn
			if '->' in ruleTag:
				var subtagRequire = ruleTag.split('->')
				if subtagRequire[0] in usedSubtags:
					if not subtagRequire[1] in usedSubtags:
						print("ERROR: to use subtag <"+subtagRequire[0]+"> you must also use subtag <"+subtagRequire[1]+"> for tag <"+mainTag+"> on line "+str(saveOptions['currentLine']))
						return errorReturn
	# this will be for single subtag tags. The single tag should be required by default
	else:
		pass
	
	return


# reads the tag and adds the data to a dictionary for the parser to read
func lexer(tag):
	var modifiedTag = tag.replace('[', '').replace(']', '')
	
	# if there is no space character in the tag, then it must have no subtags
	if not ' ' in modifiedTag:
		# set it as the main tag, then send it directly to the parser
		subtagStorage['mainTag'] = modifiedTag
		return
		
	var splitTag = modifiedTag.split(' ')
	subtagStorage['mainTag'] = splitTag[0]
	var isMainTag = true
	for subtag in splitTag:
		if isMainTag:
			isMainTag = false
			continue
		# handles the 'remove' in tags like [fgimg remove slot = "1"] and the name in [name SomeName]
		# also handles variable 'if' and 'set'
		if not '=' in subtag:
			subtagStorage['wildcard'] = subtag
			if 'var' in subtag or 'conf' in subtag:
				var variableTag = splitTag[2].split('=')
				subtagStorage['variableName'] = variableTag[0]
				subtagStorage['variableValue'] = variableTag[1]
				return
			if not '=' in tag:
				return
			continue
		var subtagName = subtag.split('=')[0]
		var subtagValue = subtag.split('=')[1]
		# matching all subtags and assigning their values
		match subtagName:
			'storage': 
				subtagValue = allGameFiles[subtagValue]
				subtagStorage['storage'] = subtagValue
			'id': 
				subtagStorage['id'] = subtagValue
			'slot':
				subtagStorage['slot'] = subtagValue
			'pos':
				subtagStorage['pos'] = subtagValue
			'loc':
				subtagValue = subtagValue.split('x')
				subtagStorage['locX'] = subtagValue[0]
				subtagStorage['locY'] = subtagValue[1]
			'size':
				subtagValue = subtagValue.split('x')
				subtagStorage['sizeX'] = subtagValue[0]
				subtagStorage['sizeY'] = subtagValue[1]
			'imgNormal':
				subtagValue = allGameFiles[subtagValue]
				subtagStorage['imgNormal'] = subtagValue
			'imgHover':
				subtagValue = allGameFiles[subtagValue]
				subtagStorage['imgHover'] = subtagValue
			'imgPressed':
				subtagValue = allGameFiles[subtagValue]
				subtagStorage['imgPressed'] = subtagValue
			'delay':
				subtagStorage['delay'] = subtagValue
			'parent':
				subtagStorage['parent'] = subtagValue
			'instance':
				subtagStorage['instance'] = subtagValue
			_:
				subtagStorage['generic'] = subtagValue
	
	return


# clears all values of the subtag storage dictionary
func subtagClear():
	for value in subtagStorage:
		subtagStorage[value] = ''
		

# a function to shake the camera
func shakeScreen():
	if loadingSave:
		return
	# the amount of shake wanted
	var shakeAmount = 20
	# how fast to shake the screen
	$ExtraTimer.wait_time = 0.0007
	# move the screen this many times
	for shake in range(30):
		$ExtraTimer.start()
		yield($Timer, "timeout")
		$MainCamera.set_offset(Vector2(rand_range(-1.0, 1.0) * shakeAmount, rand_range(-1.0, 1.0) * shakeAmount))
	# reset the camera
	$MainCamera.set_offset(Vector2(0, 0))


# The parser for all non-menu tags
# TODO: see if it can be made more efficient (although it's not too bad now)
func parser():
	
	var mainTag = subtagStorage['mainTag']
	
	if mainTag == 'call':
		# 'reloadsystem' doesn't work currently, use 'reloadgame'
		if 'reloadSystem' in subtagStorage['wildcard']:
			return get_tree().reload_current_scene()
		elif 'reloadGame' in subtagStorage['wildcard']:
			return mainParserLoop('*splashscreen')
	
	# Print text from the game script in the game's console
	# do not use a space when writing the output in the script!
	elif mainTag == 'print':
		print('DEBUG:  ' +  subtagStorage['wildcard'])
		
	elif mainTag == 'menu':
		saveOptions['menu'] = subtagStorage['wildcard']
		return menuParser(subtagStorage['wildcard'])
	
	# to set a variable from the script
	elif mainTag == 'set':
		saveOptions[subtagStorage['variableName']] = subtagStorage['variableValue']
		
	elif mainTag == 'shake':
		return shakeScreen()
	
	elif mainTag == 'if':
		inIf = true
		if subtagStorage['wildcard'] == 'var':
			# if the condition is met
			if saveOptions[subtagStorage['variableName']] == subtagStorage['variableValue']:
				ifTrue = true
	
	# 'img' and 'bgimg' are very similar. In fact, they are using the same nodes
	# But 'img' will replace the background image *and* hides the dialogue box
	# if showing and hiding the dialogue box becomes a tag, this might not be needed
	# Instead, it can be for images that go overtop the entire scene
	elif mainTag == 'img':
		get_node("MainGame/DialogueLayer").hide()
		get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load(subtagStorage['storage'])
		return 'pass'
	
	# This is for sprites
	# this handles everything to do with basic sprites
	elif mainTag == 'fgimg':
		# remove the image from a given slot
		if subtagStorage['wildcard'] == 'remove':
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % subtagStorage['slot']).texture = null
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % subtagStorage['slot']).texture = null
			return
		get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % subtagStorage['slot']).playback_speed = 2
		
		# assign the position of the sprite slot
		match subtagStorage['pos']:
			'right':
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % subtagStorage['slot']).rect_position = Vector2(450, 0)
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % subtagStorage['slot']).rect_position = Vector2(450, 0)
			'left':
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % subtagStorage['slot']).rect_position = Vector2(-450, 0)
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % subtagStorage['slot']).rect_position = Vector2(-450, 0)
			'center':
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % subtagStorage['slot']).rect_position = Vector2(0, 0)
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % subtagStorage['slot']).rect_position = Vector2(0, 0)
		# Every sprite slot has its ID assigned by its name
		# Every slot also has a 'background' and 'foreground' layer where only the foreground of the sprite is shown
		# This is done for crossfade animations
		if fgSlots['Sprite%s' % subtagStorage['slot']]:
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % subtagStorage['slot']).texture = load(subtagStorage['storage'])
			get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % subtagStorage['slot']).play("crossfade")
			fgSlots['Sprite%s' % subtagStorage['slot']] = false
		else:
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % subtagStorage['slot']).texture = load(subtagStorage['storage'])
			get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % subtagStorage['slot']).play_backwards("crossfade")
			fgSlots['Sprite%s' % subtagStorage['slot']] = true
		
	# Works similarly to the fgimg slots for crossfade, but is simpler since there is nothing
	#    behind the bgimage and there is only one background
	elif mainTag == 'bgimg':
		
		### keep this for bug fixing; it checks for childen of a node
#		for N in self.get_children():
#			if N.get_child_count() > 0:
#				print("["+N.get_name()+"]")
#				# getallnodes(N)
#			else:
#				# Do something
#				print("- "+N.get_name())

		# save the current background
		saveOptions['bgimage'] = subtagStorage['storage']
		
		# Background will always fade, even without 'fadein'
		# I don't think there is any reason for background images to not fade, but it is easy to add in here
		
		if bgLayerIsA:
			get_node("MainGame/BgLayer/BgImage/BgImage_b").texture = load(subtagStorage['storage'])
			if subtagStorage['delay']:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = float(subtagStorage['delay'])
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play("fade")
			else:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = 1
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play("fade")
			bgLayerIsA = false
		else:
			get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load(subtagStorage['storage'])
			if subtagStorage['delay']:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = float(subtagStorage['delay'])
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play_backwards("fade")
			else:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = 1
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play_backwards("fade")
				
			bgLayerIsA = true
	
	# This sets the character name in the text box
	elif mainTag == 'name':
		get_node("MainGame/DialogueLayer").show()
		if subtagStorage['wildcard'].begins_with('%'):
			saveOptions['charName'] = '【%s】\n' % languages[configSave['language']]['names'][subtagStorage['wildcard']]
		else:
			saveOptions['charName'] = '【%s】\n' % subtagStorage['wildcard']
	
	# Every 'type' of sound has its own node
	
	# This is for short sounds that do not repeat, like a door closing
	elif mainTag == 'se':
		if loadingSave:
			return
		$SoundPlayer.stream = load(subtagStorage['storage'])
		$SoundPlayer.volume_db = -5
		$SoundPlayer.play()
		
	# This is for repeating background noise, like the buzzing of cicadas
	elif mainTag == 'amb':
		if loadingSave:
			return
		if subtagStorage['wildcard'] == 'stop':
			$AmbiencePlayer.stop()
		else:
			$AmbiencePlayer.stream = load(subtagStorage['storage'])
			$AmbiencePlayer.volume_db = -5
			$AmbiencePlayer.play()
		
	# This is for standard background music
	# remember looping of music has to be done in the Godot editor under import settings
	elif mainTag == 'bgm':
		if loadingSave:
			return
		if subtagStorage['wildcard'] == 'stop':
			$BgmPlayer.stop()
		else:
			$BgmPlayer.stream = load(subtagStorage['storage'])
			$BgmPlayer.volume_db = -9
			$BgmPlayer.play()
		
	# A quick way to stop all sounds
	elif mainTag == 'allsoundstop':
		$BgmPlayer.stop()
		$VoicePlayer.stop()
		$AmbiencePlayer.stop()
		$SoundPlayer.stop()
		
	# Plays a voice, very similar to 'se'
	# The voice will stop when the dialogue moves forward
	elif mainTag == 'voice':
		if loadingSave:
			return
		$VoicePlayer.stream = load(subtagStorage['storage'])
		$VoicePlayer.volume_db = -5
		$VoicePlayer.play()
		
	# Plays a video
	# Will play overtop of everything(?) and waits for a mouse click to continue
	# TODO
	# BUG: If there is no mouse click and the video ends, it will display a blank screen/whatever was behind it before
	#      and will still wait for a a signal. Will fix once 'video end' signals are implemented in Godot 3.1
	elif mainTag == 'video':
		if loadingSave:
			return
		if not subtagStorage['storage']:
			print('ERROR: Could not find video file')
			return
		get_node("MainGame/DialogueLayer").hide()
		# stop all other music
		get_node("BgmPlayer").stop()
		# $VoicePlayer.stop()
		get_node("AmbiencePlayer").stop()
		get_node("SoundPlayer").stop()
		get_node("VideoPlayer").show()
		
		get_node("VideoPlayer").stream = load(subtagStorage['storage'])
		get_node("VideoPlayer").volume_db = -5
		get_node("VideoPlayer").play()
		return 'pass'

	# sets the dialogue box image, position, and size
	# This allows to use the same text box and dialogue label for NVL style VNs
	# It also allows for more customized text boxes and text positioning
	# TODO: this should have the options 'show' and 'hide' with animations to match.
	# the tag should also be cleaned up a bit
	elif mainTag == 'dialogue':
		if subtagStorage['wildcard'] == 'box':
			#saveOptions['dialogueBoxImage'] = '%s,%s,%s,%s' %[subtagStorage['locX'], subtagStorage['locY'] ]
			var dialogueBox = get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox")
			dialogueBox.rect_position = Vector2(subtagStorage['locX'], subtagStorage['locY'])
			dialogueBox.rect_size = Vector2(subtagStorage['sizeX'], subtagStorage['sizeY'])
			dialogueBox.texture = load(subtagStorage['storage'])
		if subtagStorage['wildcard'] == 'text':
			var textBox = get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/Dialogue")
			textBox.rect_position = Vector2(subtagStorage['locX'], subtagStorage['locY'])
			textBox.rect_size = Vector2(subtagStorage['sizeX'], subtagStorage['sizeY'])
		
	# jumps to a jump location
	elif mainTag == 'jump':
		saveOptions['jump'] = subtagStorage['wildcard']
		return mainParserLoop(subtagStorage['wildcard'])
	
	# another way to end a section
	# shouldn't be used in most games, but can allow for very specific scenes
	elif mainTag == 'sec':
		pass
		
	# this should rarely need to be used directly, only as a fallback or for testing
	elif mainTag == 'break':
		isBreak = true
	
	# go through the config file and create the GUI items
	# this is being done here to make sure they are already created by the time the splashscreen appears
	# this also makes the config file seperate from the other files
	elif mainTag == 'engine':
		engineVersion = subtagStorage['version']
		engineName = subtagStorage['id']
	
	elif mainTag == 'game':
		gameVersion = subtagStorage['version']
		gameName = subtagStorage['id']
	
	# make... slots for stuff
	elif mainTag == 'preload':
		if subtagStorage['wildcard'] == 'fg':
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
		elif subtagStorage['wildcard'] == 'buttons':
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
		elif subtagStorage['wildcard'] == 'sound':
			var names = ['BgmPlayer', 'AmbiencePlayer', 'VoicePlayer', 'SoundPlayer']
			for name in names:
				var this = AudioStreamPlayer.new()
				this.name = name
				self.add_child(this)
		elif subtagStorage['wildcard'] == 'video':
			var this = VideoPlayer.new()
			this.name = 'VideoPlayer'
			# make sure it is fullscreen
			this.rect_size =  Vector2(1920, 1080)
			self.add_child(this)
		elif subtagStorage['wildcard'] == 'menu':
			var this = TextureRect.new()
			this.rect_position = Vector2(80, 80)
			this.expand = true
			this.STRETCH_SCALE_ON_EXPAND
			this.rect_size = Vector2(1760, 920)
			this.name = 'MenuImage'
			this.hide()
			get_node('MainGame/OptionsLayer').add_child(this)
			var numberOfSlots = 6
			var num = 0
			while true:
				# seems to work well
				var thisLabel = Label.new()
				thisLabel.name = "Label" + str(num)
				thisLabel.hide()
				get_node('MainGame/OptionsLayer').add_child(thisLabel)
				num += 1
				if num > numberOfSlots:
					return
	elif mainTag == 'container':
		if subtagStorage['parent'] == 'MainNode':
			var MainContainer = Container.new()
			MainContainer.name = subtagStorage['id']
			self.add_child(MainContainer)
		else:
			var subContainer = Container.new()
			subContainer.name = subtagStorage['id']
			get_node(subtagStorage['parent']).add_child(subContainer)
	elif mainTag == 'instantiate':
		var inst = load("res://scenes/%s.tscn" % subtagStorage['instance']).instance()
		get_node(subtagStorage['parent']).add_child(inst)
		
	return


# The parser for all menu tags
func menuParser(menujump):
	var foundMenu = false
	var ifTrue = false
	var inIf = false
	for value in gameScenario['*menu']:
		
		subtagClear()
		
		if value.begins_with('#'):
			continue
	
		if menujump in value:
			foundMenu = true
			continue
		
		# if it has reached another menu tag, don't read it as well
		if foundMenu == true and '@@' in value:
			return
		
		# if the menu was found
		if foundMenu == true:
			lexer(value)
		
			var mainTag = subtagStorage['mainTag']
			
			if mainTag == 'endif':
				inIf = false
				ifTrue = false
				continue
			
			if inIf:
				# if the condition was not met, skip the lines
				if ifTrue == false:
					continue
				
			if mainTag == 'if':
				inIf = true
				# if the condition is met
				if subtagStorage['wildcard'] == 'var':
					if saveOptions[subtagStorage['variableName']] == subtagStorage['variableValue']:
						ifTrue = true
				elif subtagStorage['wildcard'] == 'conf':
					if configSave[subtagStorage['variableName']] == subtagStorage['variableValue']:
						ifTrue = true
				continue
			
			if mainTag == 'setfront':
				inMenu = true
				continue
				
			if mainTag == 'menuimg':
				get_node("MainGame/DialogueLayer").hide()
				get_node("MainGame/OptionsLayer/MenuImage").texture = load(subtagStorage['storage'])
				get_node("MainGame/OptionsLayer/MenuImage").show()
				continue
			
			# TODO: unlike the main parser, this one doesn't go through a debugger (yet)
			# also, the subtags for the buttons are keywords that should not be used for any other purpose
			#    in the tag (such as for file names or custom script added in the script file)
			if mainTag == 'button':
				if subtagStorage['wildcard'] == 'delall':
					# destroy all buttons
					for button in get_node('MainGame/ButtonLayer').get_children():
						# set the buttons for deletion and remove them from the ButtonLayer
						# TODO: make sure this actually deletes the buttons, not just removes them
						button.queue_free()
						get_node('MainGame/ButtonLayer').remove_child(button)
					
					# recreate the buttons that were destroyed
					var numberOfSlots = 12
					# do not remake Button0, it should never be deleted
					var num = 0
					while true:
						var thisButton = TextureButton.new()
						thisButton.name = "Button" + str(num)
						thisButton.hide()
						thisButton.expand = true
						thisButton.STRETCH_KEEP_ASPECT
						get_node('MainGame/ButtonLayer').add_child(thisButton)
						num += 1
						if num > numberOfSlots:
							break
					continue
		
				# actually just removes the textures
				if subtagStorage['wildcard'] == 'remove':
					var thisButton = get_node("MainGame/ButtonLayer/Button%s" % value.split('\"')[3])
					thisButton.texture_normal = null
					thisButton.texture_hover = null
					continue
				
				if subtagStorage['wildcard'] == 'hideall':
					for button in get_node("MainGame/ButtonLayer").get_children():
						if button.get_child_count() > 0:
							pass
						else:
							var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
							if thisButton.is_visible():
								thisButton.hide()
					continue
				
				if subtagStorage['wildcard'] == 'showall':
					for button in get_node("MainGame/ButtonLayer").get_children():
						if button.get_child_count() > 0:
							pass
						else:
							var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
							thisButton.show()
					continue
				
				var s = GDScript.new()
				
				# setting the button script from file
				s.set_source_code(buttonScript[subtagStorage['id']])
				s.reload()
				
				var button = get_node("MainGame/ButtonLayer/Button%s" % subtagStorage['slot'])
				button.set_script(s)
				# for save and load buttons
				if subtagStorage['id'] == "##SaveGameButton" or subtagStorage['id'] == "##LoadGameButton":
					if subtagStorage['id'] == "##SaveGameButton":
						# wait to make sure the new png file exists when this is called
						$Timer.wait_time = 0.1
						$Timer.start()
						yield($Timer, "timeout")
					var allSaveFiles = listAllFilesInDirectory("user://")
					var existingImageFileName = ''
					for fileName in allSaveFiles:
						if fileName.begins_with('sc' + subtagStorage['slot']):
							existingImageFileName = fileName
					if existingImageFileName != '':
						var file = "user://%s" % existingImageFileName
						# ==  workaround for not importing the image in the user:// dir  == Thank you @LinuxUserGD, issue #18367 !!
						var png_file = File.new()
						png_file.open(file, File.READ)
						var bytes = png_file.get_buffer(png_file.get_len())
						var img = Image.new()
						var data = img.load_png_from_buffer(bytes)
						var imgtex = ImageTexture.new()
						imgtex.create_from_image(img)
						png_file.close()
						button.texture_normal = imgtex
					else:
						button.texture_normal = load(allGameFiles['auto_n.png'])
					button.rect_position = Vector2(int(subtagStorage['locX']), int(subtagStorage['locY']))
					# set the size of the button
					button.rect_size = Vector2(int(subtagStorage['sizeX']), int(subtagStorage['sizeY']))
					button.show()
					continue
				
				# set the normal button texture
				button.texture_normal = load(subtagStorage['imgNormal'])
				# if there is a hover texture, set it here
				button.texture_hover = load(subtagStorage['imgHover'])
				button.set_process(true)
				if subtagStorage['imgPressed']:
					button.texture_disabled = load(subtagStorage['imgPressed'])
				# get the position of the button
				button.rect_position = Vector2(int(subtagStorage['locX']), int(subtagStorage['locY']))
				# set the size of the button
				button.rect_size = Vector2(int(subtagStorage['sizeX']), int(subtagStorage['sizeY']))
				button.show()
				continue
		
	
# TODO: this function for loading the game seems to work fine. 
#       Only the buttons and loop need to be modified for it to work on a built game
func loadGame(slot):
	var allSaveFiles = listAllFilesInDirectory("user://")
	var loadFileName = ''
	for fileName in allSaveFiles:
		if fileName.begins_with(slot):
			loadFileName = fileName
			break
	if loadFileName == '':
		return
	var saveFile = File.new()
	saveFile.open_encrypted_with_pass("user://%s" % loadFileName, File.READ, encryptionKey)
	var saveData = parse_json(saveFile.get_line())
	if slot == 'cf':
		configSave = saveData
		return configSave
	saveOptions = saveData
	loadingSave = true
	forceLoad = true
	return mainParserLoop(saveOptions['jump'])
	
		
# saving seems to work fine; it even encrypts the save file (but not the images)
func saveGame(slot):
	# get a list of all save files
	var allSaveFiles = listAllFilesInDirectory("user://")
	var existingSaveFileName = ''
	var existingImageFileName = ''
	for fileName in allSaveFiles:
		if fileName.begins_with(slot):
			existingSaveFileName = fileName
		if fileName.begins_with('sc' + slot):
			existingImageFileName = fileName
	var saveFile = File.new()
	# if the old save file was found
	if existingSaveFileName != '':
		# TODO: ask for confirmation before overwriting save file unless it is a 'cf' file
		# remove old save in the slot
		var dir = Directory.new()
		dir.remove("user://%s" % existingSaveFileName)
	if existingImageFileName != '':
		# remove old save screenshot
		var dir = Directory.new()
		dir.remove("user://%s" % existingImageFileName)
	if slot == 'cf':
		var newFileName = slot + '.cfsave'
		saveFile.open_encrypted_with_pass("user://%s" % newFileName, File.WRITE, encryptionKey)
		saveFile.store_line(to_json(configSave))
		saveFile.close()
		return
	else:
		var time = OS.get_datetime()
		time = "%s_%02d_%02d_%02d,%02d" % [time['year'], time['month'], time['day'], time['hour'], time['minute']]
		var newFileName = slot + ';' + time + '.kpsave'
		saveFile.open_encrypted_with_pass("user://%s" % newFileName, File.WRITE, encryptionKey)
		saveFile.store_line(to_json(saveOptions))
		saveFile.close()
		
		# take a screenshot
		# hide the menu and buttons so that they don't get in the screenshot, then show them again once it's taken
		get_tree().get_root().get_node('MainNode/MainGame/DialogueLayer').show()
		get_tree().get_root().get_node('MainNode/MainGame/OptionsLayer').hide()
		get_tree().get_root().get_node('MainNode/MainGame/ButtonLayer').hide()
		get_viewport().set_clear_mode(Viewport.CLEAR_MODE_ONLY_NEXT_FRAME)
		# Let two frames pass to make sure the screen was captured
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		get_tree().get_root().get_node('MainNode/MainGame/DialogueLayer').hide()
		get_tree().get_root().get_node('MainNode/MainGame/OptionsLayer').show()
		get_tree().get_root().get_node('MainNode/MainGame/ButtonLayer').show()
	
		# Retrieve the captured image
		var img = get_viewport().get_texture().get_data()
	  
		# Flip it on the y-axis (because it's flipped)
		img.flip_y()
		# save to a file
		img.save_png("user://%s.png" % ('sc' + slot + ';' + time))
	return


# =============================== setting up all data from file ===============================

# This is called as the game is run (before the splashscreen is even created)
func loadData(vars):
	
	# saving the directories of all game files in memory
	# will only go two directories deep, deeper files will not be allowed by the debugger
	# TODO: allow files no matter how deep in the file directory they are
	var allFiles = listAllFilesInDirectory("res://")
	
	# it will read uncompressed resources differently than those in a .pck file
	if OS.is_debug_build() and debugRelease == false:
		print('=========================DEBUG==========================')
		for file in allFiles:
			if '.import' in file:
				continue
			allGameFiles[file] = "res://"+file
			if '.' in file:
				continue
			var subFiles = listAllFilesInDirectory("res://%s" %file)
			for sub in subFiles:
				if '.import' in sub:
					continue
				allGameFiles[sub] = "res://"+file+"/"+sub
				if '.' in file:
					continue
				var lastSubFiles = listAllFilesInDirectory("res://"+file+"/"+sub)
				for lastsub in lastSubFiles:
					if '.import' in lastsub:
						continue
					allGameFiles[lastsub] = "res://"+file+"/"+sub+"/"+lastsub
	
	# reading files from a *.pck file
	# a bit more complicated since they are (almost) all *.import files, instead of the originals
	# will only go one directory deep
	else:
		print('==release==')
		for file in allFiles:
			if '.' in file:
				continue
			var subFiles = listAllFilesInDirectory("res://%s" %file)
			for sub in subFiles:
				allGameFiles[sub.replace('.import', '')] = "res://"+file+"/"+sub.replace('.import', '')
			
	# return a list of files in the directory
	var fileNames = listAllFilesInDirectory("res://scenario")
	# print(fileNames)
	
	# save the file lines as a list
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
		
		# for dialogue and tag files
		if name.ends_with('.kp'):
			# keep the newline, otherwise the value will not be saved in the list (for accurate line counting)
			var thisSectionJump = ''
			for value in fileText.split('\n', true):
				if value.begins_with('*'):
					thisSectionJump = value
					gameScenario[thisSectionJump] = []
					continue
				# keep blank lines, they will be handled (skipped) by the parser, but the line counted
				if value == '\n':
					pass
				# remove newline characters like usual if it is dialogue or a tag
				else:
					value.replace('\n', '')
				if value.begins_with('['):
					if enableDebugger:
						value = value.replace("\t", "")
					else:
						value = value.replace("\t", "").replace(' = ', '=').replace('\"', '').replace(',', '')
				gameScenario[thisSectionJump].append(value)
		# button scripts
		if name.ends_with('.kps'):
			var thisScriptJump = ''
			var thisFullScript = ''
			for value in fileText.split('\n', true):
				if value.begins_with('##'):
					buttonScript[thisScriptJump] = thisFullScript
					thisFullScript = ''
					thisScriptJump = value
					buttonScript[thisScriptJump] = ''
					continue
				thisFullScript += value + '\n'
		
		# localization scripts
		if name.ends_with('.lang'):
			languages[name.replace('.lang', '')] = JSON.parse(fileText).result
		else:
			pass
		file.close()
	
	# load the user config data when the game loads
	var loadConfig = loadGame('cf')
	if configSave['fullscreen'] == false:
		# set the window to centered
		OS.set_window_position(OS.get_screen_size()*0.5 - OS.get_window_size()*0.5)
	else:
		OS.window_fullscreen = true
	
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
