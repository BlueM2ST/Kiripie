extends Node2D
# ⑨

# for loading data from files
var gameScenario = {}
var debuggerRules = {}
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

# signals
signal vnDialogueNext
signal initLoadDone
signal dialogueEnd

# a thread to set up the game system
onready var loadingThread = Thread.new()
onready var mainLoopThread = Thread.new()

onready var cancelDialogueAnimation = false
onready var nextDialogue = false
onready var setSignal = false
onready var inMenu = false
onready var waitForClick = false

func _ready():
	# set viewport to the camera
	$MainCamera.make_current()
	# load initial data
	loadingThread.start(self, "loadData")
	yield(self,"initLoadDone")
	# on starting that game, go to the config jump location to initialize the system
	saveOptions['jump'] = '*config'
	
func _process(delta):
	OS.set_window_title("Demo, Beta Build | fps: " + str(Engine.get_frames_per_second()) + ' | jump: ' + saveOptions['jump'] + ' | line: ' + str(saveOptions['currentLine']))
	if setSignal == true:
		emit_signal("vnDialogueNext")
		setSignal = false
	# if this is true, then the game is waiting for input to move forward
	# ex. for a line of dialogue, splashscreen images
	# if it is false, then it will continue with the script, which does not need input
	if waitForClick:
		if inAutoMode or inSkipMode:
			if inSkipMode:
				$AutoTimer.wait_time = 0.1
			else:
				$AutoTimer.wait_time = configSave['autoSpeed']
			$AutoTimer.start()
			yield($AutoTimer, "timeout")
			waitForClick = false
			return
		else:
			yield(self, "vnDialogueNext")
			waitForClick = false
			get_node("VoicePlayer").stop()
			get_node("VideoPlayer").stop()
			get_node("VideoPlayer").hide()
	else:
		# in case the process starts before the dictionary is ready
		if not saveOptions['jump'] in gameScenario:
			return
		# continue going through the non-test lines
		saveOptions['currentLine'] += 1
		if not str(saveOptions['currentLine']) in gameScenario[saveOptions['jump']]:
			return
		var value = gameScenario[saveOptions['jump']][str(saveOptions['currentLine'])]
		mainLoop(value)
	

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
					waitForClick = false
					emit_signal("vnDialogueNext")


# =============================== running =====================================================
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
var endLoop = false


func mainLoop(value):
	
	if str(value).begins_with('*'):
		return
		
	# don't read comments or blank lines
	if value['mainTag'] == 'empty':
		return
	if value['mainTag'] == 'break':
		isBreak = true
		return
	if value['mainTag'] == 'endif':
		inIf = false
		ifTrue = false
		return
	if inIf:
		# if the condition was not met, skip the lines
		if ifTrue == false:
			return
	
	# check if the line is a tag
	if not value['mainTag'] == 'text':
		cancelDialogueAnimation = true
		interpreter(value)
		return
	# if loading a save, don't display the dialogue until the saved line is found
	if loadingSave:
		if saveOptions['line'] == saveOptions['currentLine']:
			loadingSave = false
		else:
			saveOptions['charName'] = '\n'
			return
	
	cancelDialogueAnimation = false
	
	# for localization support
	if value['text'].begins_with('%'):
		# make sure it's valid
		if value['text'] in languages[configSave['language']]['dialogue']:
			value = languages[configSave['language']]['dialogue'][value['text']]
		else:
			# if it's not valid, then it should be language-specific.
			return
	else:
		value = value['text']
	
	saveOptions['currentDialogue'] = value
	var dialogueToShow = saveOptions['charName'] + value
	# reset the name value since not all text lines will have a name
	saveOptions['charName'] = '\n'
	# wait for a mouse click, enter key, etc.
	dialogue(dialogueToShow)
	
	cancelDialogueAnimation = false
	waitForClick = true


# displaying dialogue in the textbox.
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


func lexer():
	
	# return a list of files in the directory
	var fileNames = listAllFilesInDirectory("res://scenario")
	
	for name in fileNames:
		# open the file
		var file = File.new()
		file.open('res://scenario/%s' % name, File.READ)
		var fileText = file.get_as_text()
		# check if it's a config file
		
		# for the debugger
		if name.ends_with('.kpcf'):
			if not enableDebugger:
				pass
			debuggerRules['tag'] = {}
			debuggerRules['subtag'] = {}
			for value in fileText.split('\n', false):
				# ignore the comments and empty lines since there is no debugger yet for the config file
				if value == '\n' or value.begins_with('#') or value.begins_with('@@'):
					continue
				# remove spaces
				value = value.replace(' ', '')
				var grammarList = value.split(';')
				if grammarList[0] == "tag":
					
					debuggerRules[grammarList[0]][grammarList[1]] = {}
					
					debuggerRules[grammarList[0]][grammarList[1]]['allowedSubtags'] = {}
					
					if ',' in grammarList[2]:
						for value in grammarList[2].split(','):
							debuggerRules[grammarList[0]][grammarList[1]]['allowedSubtags'] = value
					else:
						debuggerRules[grammarList[0]][grammarList[1]]['allowedSubtags'] = grammarList[2]
					
					debuggerRules[grammarList[0]][grammarList[1]]['subtagRules'] = {}
					
					if grammarList.size() > 3:
						
						if ',' in grammarList[3]:
							for value in grammarList[3].split(','):
								debuggerRules[grammarList[0]][grammarList[1]]['subtagRules'] = value
						else:
							debuggerRules[grammarList[0]][grammarList[1]]['subtagRules'] = grammarList[3]
					else:
						debuggerRules[grammarList[0]][grammarList[1]]['subtagRules'] = 'default'
						
				if grammarList[0] == "subtag":
					debuggerRules[grammarList[0]][grammarList[1]] = {}
					debuggerRules[grammarList[0]][grammarList[1]]['subtagRegex'] = grammarList[2]
					
		
		var lineCount = 0
		# for dialogue and tag files
		if name.ends_with('.kp'):
			var thisSectionJump = ''
			var thisMenuJump = ''
			for value in fileText.split('\n', true):
				lineCount += 1
				if value.begins_with('*'):
					thisSectionJump = value
					gameScenario[thisSectionJump] = {}
					thisMenuJump = ''
					lineCount = 0
					continue
				if value.begins_with('@@'):
					thisMenuJump = value
					gameScenario[thisSectionJump][str(lineCount)] = {'mainTag': 'menuSectionJump', 'jump': value}
					continue
				# preserve empty lines for line counting, the interpreter will just pass over them
				value.replace('\n', '')
				if value == '' or value.begins_with('#'):
					gameScenario[thisSectionJump][str(lineCount)] = {'mainTag': 'empty'}
					continue
				
				# if the line is not a tag then it must be script since jumps are handled above
				if not value.begins_with('['):
					gameScenario[thisSectionJump][str(lineCount)] = {'mainTag': 'text', 'text': value}
					continue
				
				# === to get here, it must be a tag ===
				# remove the opening and closing square brackets, they are only used to tell the parser that this is a tag
				# also replace spaces around the equals signs and removes commas, since these are visual only
				value = value.replace(' = ', '=').replace(' =', '=').replace('= ', '=').replace('[', '').replace(']', '').replace(',', '')
				
				var tokens = value.split(' ')
				
				# take the values and add them to the dictionary
				var tokenDict = {}
				var mainTag = tokens[0]
				for token in tokens:
					token = token.replace('\"', '')
					if token == mainTag:
						tokenDict['mainTag'] = token
					elif not '=' in token:
						tokenDict['singleTag'] = token
					# handle tokens with variabls differently
					elif mainTag == 'if' or mainTag == 'set':
						var splitToken = token.split('=')
						tokenDict['varName'] = splitToken[0]
						tokenDict['varValue'] = splitToken[1]
					# split the subtag value for X and Y
					elif 'loc=' in token or 'size=' in token:
						var splitToken = token.split('=')
						var splitPlacement = splitToken[1].split('x')
						if 'loc=' in token:
							tokenDict['locX'] = splitPlacement[0]
							tokenDict['locY'] = splitPlacement[1]
						else:
							tokenDict['sizeX'] = splitPlacement[0]
							tokenDict['sizeY'] = splitPlacement[1]
					# find the actual path of the files
					elif '.jpg' in token or '.png' in token or '.webp' in token or '.wav' in token or '.ogv' in token or '.webp' in token:
						var splitToken = token.split('=')
						tokenDict[splitToken[0]] = allGameFiles[splitToken[1]]
					else:
						var splitToken = token.split('=')
						tokenDict[splitToken[0]] = splitToken[1]
				
				# if the debugger is disabled, assume the tag is correct
				if not enableDebugger:
					gameScenario[thisSectionJump][str(lineCount)] = tokenDict
					continue
				
				var regex = RegEx.new()
				var errorReturn = 'error'
	
				if not tokenDict['mainTag'] in debuggerRules['tag']:
					print('ERROR on line '+str(lineCount)+': tag <'+tokenDict['mainTag']+'> does not exist. Skipping tag.')
					continue
				
				for token in tokenDict:
					if not token in debuggerRules['']:
						pass
					
					
					var foundNoValidSubtags
					var usedSubtags = []
					for rule in tokenDict['mainTag']:
						var originalRule = rule
						# if it is supposed to jump to a regex value
						if '@' in rule:
							rule = rule.replace('@', '')
							rule = grammarSubtag[rule].split(';')[2]
							# if the tag is not supposed to have any subtags
							if '--' in rule:
								foundNoValidSubtags = false
								usedSubtags.append(originalRule)
								break
						regex.compile(rule)
						# makes sure the regex is valid
						if not regex.is_valid():
							print('ERROR: bad regex value: '+rule+' Skipping tag.')
							continue
						foundNoValidSubtags = false
						usedSubtags.append(originalRule)
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

func parser():
	pass


# The parser for all non-menu tags
# TODO: see if it can be made more efficient (although it's not too bad now)
func interpreter(line):
	
	var mainTag = line['mainTag']
	
	if mainTag == 'call':
		if 'reloadSystem' in line['singleTag']:
			return get_tree().reload_current_scene()
		elif 'reloadGame' in line['singleTag']:
			inSkipMode = false
			return
	
	# Print text from the game script in the game's console
	# do not use a space when writing the output in the script!
	elif mainTag == 'print':
		print('DEBUG:  ' +  line['singleTag'])
		
	elif mainTag == 'menu':
		saveOptions['menu'] = line['singleTag']
		return menuInterpreter(line['singleTag'])
	
	# to set a variable from the script
	elif mainTag == 'set':
		saveOptions[line['varName']] = line['varValue']
		
	elif mainTag == 'shake':
		return shakeScreen()
	
	elif mainTag == 'if':
		inIf = true
		if line['singleTag'] == 'var':
			# if the condition is met
			if saveOptions[line['varName']] == line['varValue']:
				ifTrue = true
	
	# 'img' and 'bgimg' are very similar. In fact, they are using the same nodes
	# But 'img' will replace the background image *and* hides the dialogue box
	# if showing and hiding the dialogue box becomes a tag, this might not be needed
	# Instead, it can be for images that go overtop the entire scene
	elif mainTag == 'img':
		get_node("MainGame/DialogueLayer").hide()
		get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load(line['storage'])
		waitForClick = true
		return
	
	# This is for sprites
	# this handles everything to do with basic sprites
	elif mainTag == 'fgimg':
		# remove the image from a given slot
		if 'singleTag' in line:
			if line['singleTag'] == 'remove':
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % line['slot']).texture = null
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % line['slot']).texture = null
				return
			get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % line['slot']).playback_speed = 2
		
		# assign the position of the sprite slot
		if 'pos' in line: match line['pos']:
			'right':
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % line['slot']).rect_position = Vector2(450, 0)
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % line['slot']).rect_position = Vector2(450, 0)
			'left':
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % line['slot']).rect_position = Vector2(-450, 0)
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % line['slot']).rect_position = Vector2(-450, 0)
			'center':
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % line['slot']).rect_position = Vector2(0, 0)
				get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % line['slot']).rect_position = Vector2(0, 0)
		# Every sprite slot has its ID assigned by its name
		# Every slot also has a 'background' and 'foreground' layer where only the foreground of the sprite is shown
		# This is done for crossfade animations
		if fgSlots['Sprite%s' % line['slot']]:
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_b" % line['slot']).texture = load(line['storage'])
			get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % line['slot']).play("crossfade")
			fgSlots['Sprite%s' % line['slot']] = false
		else:
			get_node("MainGame/CharacterLayer/Sprite%s/Sprite_a" % line['slot']).texture = load(line['storage'])
			get_node("MainGame/CharacterLayer/Sprite%s/SpriteAnimationPlayer" % line['slot']).play_backwards("crossfade")
			fgSlots['Sprite%s' % line['slot']] = true
		
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
		saveOptions['bgimage'] = line['storage']
		
		# Background will always fade, even without 'fadein'
		# I don't think there is any reason for background images to not fade, but it is easy to add in here
		
		if bgLayerIsA:
			get_node("MainGame/BgLayer/BgImage/BgImage_b").texture = load(line['storage'])
			if 'delay' in line:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = float(line['delay'])
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play("fade")
			else:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = 1
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play("fade")
			bgLayerIsA = false
		else:
			get_node("MainGame/BgLayer/BgImage/BgImage_a").texture = load(line['storage'])
			if 'delay' in line:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = float(line['delay'])
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play_backwards("fade")
			else:
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").playback_speed = 1
				get_node("MainGame/BgLayer/BgImage/BackgroundImageAnimation").play_backwards("fade")
				
			bgLayerIsA = true
	
	# This sets the character name in the text box
	elif mainTag == 'name':
		get_node("MainGame/DialogueLayer").show()
		if line['singleTag'].begins_with('%'):
			saveOptions['charName'] = '【%s】\n' % languages[configSave['language']]['names'][line['singleTag']]
		else:
			saveOptions['charName'] = '【%s】\n' % line['singleTag']
	
	# Every 'type' of sound has its own node
	
	# This is for short sounds that do not repeat, like a door closing
	elif mainTag == 'se':
		if loadingSave:
			return
		$SoundPlayer.stream = load(line['storage'])
		$SoundPlayer.volume_db = -5
		$SoundPlayer.play()
		
	# This is for repeating background noise, like the buzzing of cicadas
	elif mainTag == 'amb':
		if loadingSave:
			return
		if 'singleTag' in line and line['singleTag'] == 'stop':
			$AmbiencePlayer.stop()
		else:
			$AmbiencePlayer.stream = load(line['storage'])
			$AmbiencePlayer.volume_db = -5
			$AmbiencePlayer.play()
		
	# This is for standard background music
	# remember looping of music has to be done in the Godot editor under import settings
	elif mainTag == 'bgm':
		if loadingSave:
			return
		if 'singleTag' in line:
			if line['singleTag'] == 'stop':
				$BgmPlayer.stop()
		else:
			$BgmPlayer.stream = load(line['storage'])
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
		$VoicePlayer.stream = load(line['storage'])
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
		if not line['storage']:
			print('ERROR: Could not find video file')
			return
		get_node("MainGame/DialogueLayer").hide()
		# stop all other music
		get_node("BgmPlayer").stop()
		# $VoicePlayer.stop()
		get_node("AmbiencePlayer").stop()
		get_node("SoundPlayer").stop()
		get_node("VideoPlayer").show()
		
		get_node("VideoPlayer").stream = load(line['storage'])
		get_node("VideoPlayer").volume_db = -5
		get_node("VideoPlayer").play()
		return

	# sets the dialogue box image, position, and size
	# This allows to use the same text box and dialogue label for NVL style VNs
	# It also allows for more customized text boxes and text positioning
	# TODO: this should have the options 'show' and 'hide' with animations to match.
	# the tag should also be cleaned up a bit
	elif mainTag == 'dialogue':
		if line['singleTag'] == 'box':
			var dialogueBox = get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox")
			dialogueBox.rect_position = Vector2(line['locX'], line['locY'])
			dialogueBox.rect_size = Vector2(line['sizeX'], line['sizeY'])
			dialogueBox.texture = load(line['storage'])
		if line['singleTag'] == 'text':
			var textBox = get_node("MainGame/DialogueLayer/DialogueNode/DialogueBox/Dialogue")
			textBox.rect_position = Vector2(line['locX'], line['locY'])
			textBox.rect_size = Vector2(line['sizeX'], line['sizeY'])
		
	# jumps to a jump location
	elif mainTag == 'jump':
		saveOptions['jump'] = line['singleTag']
		saveOptions['currentLine'] = 0
		return
	
	# another way to end a section
	# shouldn't be used in most games, but can allow for very specific scenes
	elif mainTag == 'sec':
		pass
		
	# this should rarely need to be used directly, only as a fallback or for testing
	elif mainTag == 'break':
		isBreak = true
		print('found break')
	
	# go through the config file and create the GUI items
	# this is being done here to make sure they are already created by the time the splashscreen appears
	# this also makes the config file seperate from the other files
	elif mainTag == 'engine':
		engineVersion = line['version']
		engineName = line['id']
	
	elif mainTag == 'game':
		gameVersion = line['version']
		gameName = line['id']
	
	# make... slots for stuff
	elif mainTag == 'preload':
		if line['singleTag'] == 'fg':
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
		elif line['singleTag'] == 'buttons':
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
		# sliders are not working yet. They might eventually be made in a new scene for simplicity
		#  instead of being made like this
#		elif line['singleTag'] == 'sliders':
#			return
#			# disabled for now
#			var numberOfSlots = 10
#			var num = 0
#			print('found sliders')
#			while true:
#				# seems to work well
#				var thisSlider = HSlider.new()
#				thisSlider.name = "Slider" + str(num)
#				thisSlider.hide()
#				thisSlider.editable = true
#				thisSlider.tick_count = 100
#				thisSlider.ticks_on_borders = true
#				print('got this far')
#				thisSlider.theme = "MainGameStart"
#				get_node('MainGame/ButtonLayer').add_child(thisSlider)
#				num += 1
#				if num > numberOfSlots:
#					print('sliders made')
#					return
			
		elif line['singleTag'] == 'sound':
			var names = ['BgmPlayer', 'AmbiencePlayer', 'VoicePlayer', 'SoundPlayer']
			for name in names:
				var this = AudioStreamPlayer.new()
				this.name = name
				self.add_child(this)
		elif line['singleTag'] == 'video':
			var this = VideoPlayer.new()
			this.name = 'VideoPlayer'
			# make sure it is fullscreen
			this.rect_size =  Vector2(1920, 1080)
			this.hide()
			self.add_child(this)
		elif line['singleTag'] == 'menu':
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
		if line['parent'] == 'MainNode':
			var MainContainer = Container.new()
			MainContainer.name = line['id']
			self.add_child(MainContainer)
		else:
			var subContainer = Container.new()
			subContainer.name = line['id']
			get_node(line['parent']).add_child(subContainer)
	elif mainTag == 'instantiate':
		var inst = load("res://scenes/%s.tscn" % line['instance']).instance()
		get_node(line['parent']).add_child(inst)
		
	return


# The parser for all menu tags
func menuInterpreter(menujump):
	var foundMenu = false
	var ifTrue = false
	var inIf = false
	print('==========')
	
	for line in gameScenario['*menu']:
		line = gameScenario['*menu'][line]
		var mainTag = line['mainTag']
		
		if mainTag == 'empty':
			continue
		if not foundMenu:
			if mainTag == 'menuSectionJump':
				if not line['jump'] == menujump:
					continue
				else:
					foundMenu = true
					continue
			continue
		
		# if it has reached another menu tag, stop there
		if foundMenu and mainTag == 'menuSectionJump':
			break
		
		# ==if it has reached here, then it has found the correct menu section==
		
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
			if line['singleTag'] == 'var':
				if saveOptions[line['varName']] == line['vaValue']:
					ifTrue = true
			elif line['singleTag'] == 'conf':
				if configSave[line['varName']] == line['varValue']:
					ifTrue = true
			continue
		
		if mainTag == 'setfront':
			inMenu = true
			continue
			
		if mainTag == 'menuimg':
			get_node("MainGame/DialogueLayer").hide()
			get_node("MainGame/OptionsLayer/MenuImage").texture = load(line['storage'])
			get_node("MainGame/OptionsLayer/MenuImage").show()
			continue
		
		# TODO: unlike the main parser, this one doesn't go through a debugger (yet)
		# also, the subtags for the buttons are keywords that should not be used for any other purpose
		#    in the tag (such as for file names or custom script added in the script file)
		if mainTag == 'button':
			if 'singleTag' in line:
				if line['singleTag'] == 'delall':
					# destroy all buttons
					for button in get_node('MainGame/ButtonLayer').get_children():
						# set the buttons for deletion and remove them from the ButtonLayer
						# TODO: make sure this actually deletes the buttons, not just removes them
						get_node('MainGame/ButtonLayer').remove_child(button)
						#button.queue_free()
					
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
				
				if line['singleTag'] == 'hideall':
					for button in get_node("MainGame/ButtonLayer").get_children():
						if button.get_child_count() > 0:
							pass
						else:
							var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
							if thisButton.is_visible():
								thisButton.hide()
					continue
				
				if line['singleTag'] == 'showall':
					for button in get_node("MainGame/ButtonLayer").get_children():
						if button.get_child_count() > 0:
							pass
						else:
							var thisButton = get_node("MainGame/ButtonLayer/%s" % button.get_name())
							thisButton.show()
					continue
			
			var s = GDScript.new()
			
			# setting the button script from file
			s.set_source_code(buttonScript[line['id']])
			s.reload()
			
			var button = get_node("MainGame/ButtonLayer/Button%s" % line['slot'])
			button.set_script(s)
			# for save and load buttons
			if line['id'] == "##SaveGameButton" or line['id'] == "##LoadGameButton":
				if line['id'] == "##SaveGameButton":
					# wait to make sure the new png file exists when this is called
					$Timer.wait_time = 0.1
					$Timer.start()
					yield($Timer, "timeout")
				var allSaveFiles = listAllFilesInDirectory("user://")
				var existingImageFileName = ''
				for fileName in allSaveFiles:
					if fileName.begins_with('sc' + line['slot']):
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
				button.rect_position = Vector2(int(line['locX']), int(line['locY']))
				# set the size of the button
				button.rect_size = Vector2(int(line['sizeX']), int(line['sizeY']))
				button.show()
				continue
			
			# set the normal button texture
			button.texture_normal = load(line['imgNormal'])
			# if there is a hover texture, set it here
			button.texture_hover = load(line['imgHover'])
			button.set_process(true)
			if 'imgPressed' in line:
				button.texture_disabled = load(line['imgPressed'])
			# get the position of the button
			button.rect_position = Vector2(int(line['locX']), int(line['locY']))
			# set the size of the button
			button.rect_size = Vector2(int(line['sizeX']), int(line['sizeY']))
			button.show()
			continue


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
		return
	saveOptions = saveData
	return
	
		
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
			
	lexer()
	
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
