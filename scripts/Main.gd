extends Node

signal nextLine

onready var fullGameScript : Dictionary = {}
onready var languages : Dictionary = {}
onready var scriptDict : Dictionary = {}
onready var funcRefDict : Dictionary = {}
onready var nodePaths : Dictionary = {}

onready var tween : Tween = Tween.new()
onready var timer : Timer = Timer.new()

var currentLineDict : Dictionary = {}
var inMacro : bool = false
# TODO : implement proper "if" statements some day (tm)
var inIf : bool = false
var toElif : bool = false
var toEndif : bool = false


func _ready() -> void:
	OS.set_window_title(global.gameName)
	OS.set_window_maximized(true)
	# check if the game is running on a mobile device
	var operatingSystemName : String = OS.get_name()
	if operatingSystemName == "Android" or operatingSystemName == "iOS":
		global.isMobilePlatform = true
	else:
		OS.low_processor_usage_mode = true
	# load system settings
	global.loadSystem()
	# add nodes to tree
	add_child(tween)
	add_child(timer)
	# load scripts to make them readable by the program
	var scriptsNode = Node.new()
	scriptsNode.set_script(load("res://scripts/scriptLoader.gd"))
	scriptsNode.name = "scriptsNode"
	add_child(scriptsNode)
	get_node("scriptsNode").scriptLoader()
	scriptsNode.queue_free()
	# begin the game
	emit_signal("nextLine")


func _process(delta:float) -> void:
	if global.isRelease:
		set_process(false)
	OS.set_window_title("%s / FPS: %s / Line: %s / Jump: %s" %[
		global.gameName, 
		str(Engine.get_frames_per_second()), 
		global.gameSave["currentLine"], 
		global.gameSave["currentJump"]
		])


# TODO: set up some other system to check for variables
func _on_nextLine() -> void:
	# make sure the line exists
	if not str(global.gameSave["currentLine"] + 1) in fullGameScript[global.gameSave["currentJump"]]:
		return
	var jump : String = ""
	var thisLine : String = ""
	if inMacro:
		global.gameSave["currentMacroLine"] += 1
		jump = global.gameSave["currentMacroJump"]
		thisLine = str(global.gameSave["currentMacroLine"])
	else:
		global.gameSave["currentLine"] += 1
		jump = global.gameSave["currentJump"]
		thisLine = str(global.gameSave["currentLine"])
	currentLineDict = fullGameScript[jump][thisLine]
	# TODO: there must be a better way to do this
	# check for and, if found, replace variable with their actual value
#	for value in currentLineDict:
#		for key in value:
#			if typeof(value[key]) == TYPE_DICTIONARY:
#				currentLineDict[key] = _checkForVar(value[key])
#			else:
#				currentLineDict[key] = value[key]
	print(currentLineDict)
	
	#### --for hacked-in "if" statements (works though):
	if "endif" in currentLineDict:
		inIf = false
		toElif = false
		toEndif = false
		emit_signal("nextLine")
		return
	if toEndif:
		if not "endif" in currentLineDict:
			emit_signal("nextLine")
			return
	if toElif:
		if not "elif" in currentLineDict:
			if not "else" in currentLineDict:
				if not inIf:
					emit_signal("nextLine")
					return
	#### --end hacked-in "if" statements
	
	# call functions on a group of nodes
	if "tag" in currentLineDict and currentLineDict["tag"] == "group":
		for node in get_tree().get_nodes_in_group(currentLineDict["group"]):
			currentLineDict["slot"] = node.name
			for value in currentLineDict["funcs"]:
				funcRefDict[value].call_func()
	# call a function on a single node
	else:
		for value in currentLineDict["funcs"]:
			funcRefDict[value].call_func()
	# check if the signal should be emitted (or if the function will emit it itself for any reason)
	if "wait" in currentLineDict["funcs"] or "text" in currentLineDict["funcs"]:
		return
	else:
		emit_signal("nextLine")

func ref_text():
	# for language support
	if currentLineDict["text"].begins_with("%"):
		nodePaths["main"].textInit(languages[global.currentLanguage][currentLineDict["text"]])
	else:
		nodePaths["main"].textInit(currentLineDict["text"])

func ref_create():
	match currentLineDict["tag"]:
		"bgimg":
			var textureRect : TextureRect = TextureRect.new()
			textureRect.rect_position = Vector2(0,0)
			textureRect.rect_size = Vector2(1920, 1080)
			textureRect.expand = true
			textureRect.STRETCH_KEEP_ASPECT_CENTERED
			textureRect.material = load("res://system/crossfade.material")
			_addCreatedNode(textureRect)
		"fgimg", "img":
			var textureRect : TextureRect = TextureRect.new()
			textureRect.expand = true
			textureRect.STRETCH_KEEP_ASPECT_CENTERED
			_addCreatedNode(textureRect)
		"label":
			var label : RichTextLabel = RichTextLabel.new()
			label.bbcode_enabled = true
			label.scroll_active = false
			label.set_script(load("res://scripts/dialogue.gd"))
			_addCreatedNode(label)
		"sound":
			var audioPlayer : AudioStreamPlayer = AudioStreamPlayer.new()
			_addCreatedNode(audioPlayer)
		"video":
			var videoPlayer : VideoPlayer = VideoPlayer.new()
			_addCreatedNode(videoPlayer)
		"button":
			var button : TextureButton = TextureButton.new()
			button.expand = true
			button.STRETCH_KEEP_ASPECT_CENTERED
			_addCreatedNode(button)

func _addCreatedNode(node):
	node.name = currentLineDict["slot"]
	if "layer" in currentLineDict:
		get_node(currentLineDict["layer"]).add_child(node)
	else:
		get_node(currentLineDict["tag"] + "Layer").add_child(node)
	nodePaths[currentLineDict["slot"]] = get_node("%sLayer/%s" %[currentLineDict["tag"], currentLineDict["slot"]])

func ref_destroy():
	nodePaths[currentLineDict["slot"]].queue_free()

func ref_destroyall():
	for node in get_node(currentLineDict["tag"] + "Layer").get_children():
		node.queue_free()

# TODO: add support for custom layer nodes, for now it uses the default set by "tag"
func ref_storage():
	var node = nodePaths[currentLineDict["slot"]]
	match currentLineDict["tag"]:
		"bgimg", "fgimg", "img":
			if node.material and not node.texture == null:
				_crossfade(node, load(currentLineDict["storage"]))
			else:
				node.texture = load(currentLineDict["storage"])
		"sound", "video":
			node.stream = load(currentLineDict["storage"])
		"button":
			node.texture_normal = load(currentLineDict["storage"])

func ref_group():
	nodePaths[currentLineDict["slot"]].add_to_group(currentLineDict["group"])

func ref_jump():
	global.gameSave["currentJump"] = currentLineDict["jump"]
	global.gameSave["currentLine"] = 0
	
func ref_print():
	print("PRINT:   " + currentLineDict["print"])

func ref_wait():
	if currentLineDict["wait"] == "input":
		global.forcePrint = true
	else:
		timer.wait_time = float(currentLineDict["wait"])
		timer.start()
		yield(timer, "timeout")
		emit_signal("nextLine")

func ref_moveto():
	var speed : float = 1.0
	if "speed" in currentLineDict:
		speed = float(currentLineDict["speed"])
	tween.interpolate_property(
		nodePaths[currentLineDict["slot"]], 
		'rect_position',
		null, 
		Vector2(
			int(currentLineDict["vec2"].split("x")[0]),
			int(currentLineDict["vec2"].split("x")[1])
		), 
		speed,
		Tween.TRANS_QUAD, 
		Tween.EASE_OUT
		)
	tween.start()

func ref_moveby():
	var node = nodePaths[currentLineDict["slot"]]
	var speed : float = 1.0
	if "speed" in currentLineDict:
		speed = float(currentLineDict["speed"])
	tween.interpolate_property(
		node, 
		'rect_position',
		node.rect_position, 
		Vector2(
			node.rect_position.x + int(currentLineDict["vec2"].split("x")[0]),
			node.rect_position.y + int(currentLineDict["vec2"].split("x")[1])
		), 
		speed,
		Tween.TRANS_QUAD, 
		Tween.EASE_OUT
		)
	tween.start()

func ref_empty():
	return

func ref_setlayer():
	var layer : Node2D = Node2D.new()
	layer.name = currentLineDict["setlayer"]
	add_child(layer)

# TODO: for both size and pos, add support for custom layers. For now it uses the default set by "tag"
func ref_size():
	nodePaths[currentLineDict["slot"]].rect_size = Vector2(int(currentLineDict["size"].split("x")[0]), int(currentLineDict["size"].split("x")[1]))

func ref_pos():
	nodePaths[currentLineDict["slot"]].rect_position = Vector2(int(currentLineDict["pos"].split("x")[0]), int(currentLineDict["pos"].split("x")[1]))

func ref_show():
	nodePaths[currentLineDict["slot"]].show()
	
func ref_hide():
	nodePaths[currentLineDict["slot"]].hide()

# TODO: add support for math
# TODO: take "if" stuff out of here and implement it properly
func ref_var():
	match currentLineDict["tag"]:
		"var":
			for key in currentLineDict:
				if not key == "tag" and not key == "var":
					global.gameSave["scriptVariables"][key] = currentLineDict[key]
		"if":
			for key in currentLineDict:
				if not key == "tag" and not key == "if" and not key == "var":
					if global.gameSave["scriptVariables"][key] == currentLineDict[key]:
						inIf = true
					else:
						toElif = true
		"elif":
			if inIf:
				toEndif = true
				return
			for key in currentLineDict:
				if not key == "tag" and not key == "elif" and not key == "var":
					if global.gameSave["scriptVariables"][key] == currentLineDict[key]:
						inIf = true
						toElif = false
		"else":
			if inIf:
				toEndif = true
				return
			inIf = true
			toElif = false
		_:
			pass

func ref_play():
	var node = nodePaths[currentLineDict["slot"]]
	node.play()
	if node.get_class() == "VideoPlayer":
		global.forcePrint = true
		yield(node, "finished")
		global.forcePrint = false
		emit_signal("nextLine")
		
func ref_volume():
	nodePaths[currentLineDict["slot"]].set_volume_db(float(currentLineDict["volume"]))

func ref_stop():
	nodePaths[currentLineDict["slot"]].stop()

func ref_seek():
	nodePaths[currentLineDict["slot"]].seek(float(currentLineDict["seek"]))

func ref_script():
	var s = GDScript.new()
	s.set_source_code(scriptDict[currentLineDict["script"]])
	s.reload()
	nodePaths[currentLineDict["slot"]].set_script(s)

func ref_macro():
	global.gameSave["currentMacroJump"] = currentLineDict["macro"]
	global.gameSave["currentMacroLine"] = 0
	inMacro = true

func ref_return():
	inMacro = false
	global.gameSave["currentMacroJump"] = ""
	global.gameSave["currentMacroLine"] = 0

func ref_call():
	match currentLineDict["call"]:
		"printTextureMemory":
			OS.print_all_textures_by_size()
		"restartSystem":
			pass
		"printStaticMemoryMax":
			print(OS.get_static_memory_peak_usage())
		"printDynamicMemory":
			print(OS.get_dynamic_memory_usage())
		"printResources":
			print(OS.print_resources_in_use(false))
		"scriptdump":
			if not global.isRelease:
				var f : File = File.new()
				f.open("res://scenario/release.ssc", f.WRITE)
				f.store_line(to_json(fullGameScript))
				f.close()
		_:
			pass

func ref_dia():
	match currentLineDict["dia"]:
		"cleartext":
			nodePaths["main"].bbcode_text = ""
		_:
			pass

func ref_material():
	nodePaths[currentLineDict["slot"]].material = load("res://system/%s.material" % currentLineDict["material"])
	
func ref_theme():
	nodePaths[currentLineDict["slot"]].theme = load("res://system/%s.theme" % currentLineDict["theme"])

func ref_fadein():
	var speed : float = 0.4
	if "speed" in currentLineDict:
		speed = float(currentLineDict["speed"])
	tween.interpolate_property(
		nodePaths[currentLineDict["slot"]], 
		"modulate:a", 
		null, 
		1.0, 
		speed, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_IN_OUT
	)
	tween.start()

func ref_fadeout():
	var speed : float = 0.4
	if "speed" in currentLineDict:
		speed = float(currentLineDict["speed"])
	tween.interpolate_property(
		nodePaths[currentLineDict["slot"]], 
		"modulate:a", 
		null, 
		0.0, 
		speed, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_IN_OUT
	)
	tween.start()

func ref_autosave():
	global.saveGame("0")

# private helper functions
func _checkForVar(value:Dictionary) -> String:
	for key in value:
		if key == "str":
			return str(value[key])
		else:
			return str(global.gameSave["scriptVariables"][value[key]])

func _crossfade(node, texture):
	node.material.set_shader_param("newtex", texture)
	tween.interpolate_property(
		node.get_material(), 
		"shader_param/progress", 
		null, 
		1, 
		0.4, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_IN_OUT
	)
	tween.start()
	yield(tween, "tween_all_completed")
	node.texture = texture
	node.material.set_shader_param("newtex", null)
	node.material.set_shader_param("progress", 0)


# public helper functions
func createFuncRefDict(refArray:Array):
	for function in refArray:
		funcRefDict[function] = funcref(self, "ref_" + function)

func wait(wait:float=0):
	timer.wait_time = wait
	timer.start()
	yield(timer, "timeout")
	emit_signal("nextLine")

func emitNextLine() -> void:
	emit_signal("nextLine")








# end file
