extends Node

var allGameFiles : Dictionary = {}
var funcRefArray : Array = []
var mainNodePath

func _ready() -> void:
	pass


func scriptLoader() -> void:
	mainNodePath = get_tree().get_root().get_node("SiennaScripter")
	global.mainNodePath = mainNodePath
	_createFuncRefArray()
	if not global.isRelease:
		_getGameFiles()
	_fileLoader()
	mainNodePath.createFuncRefDict(funcRefArray)


# goes one directory deep, finds the res:// path of files
func _getGameFiles() -> void:
	for file in _listAllFilesInDirectory("res://"):
		for subFile in _listAllFilesInDirectory("res://" + file):
			if "." in file:
				continue
			allGameFiles[subFile] = "res://" + file + "/" + subFile


func _fileLoader() -> void:
	var scenario : Array = []
	var gameScenario : Dictionary = {}
	
	for file in _listAllFilesInDirectory("res://scenario"):
		if file.ends_with(".ss"):
			if global.isRelease:
				continue
			var f : File = File.new()
			f.open("res://scenario/" + file, f.READ)
			for line in f.get_as_text().split("\n"):
				scenario.append(line)
			f.close()
		# processed files
		elif file.ends_with(".ssc"):
			if not global.isRelease:
				continue
			var f : File = File.new()
			f.open("res://scenario/" + file, f.READ)
			mainNodePath.fullGameScript = parse_json(f.get_as_text())
			f.close()
		# language files
		elif file.ends_with(".lang"):
			var f : File = File.new()
			f.open("res://scenario/" + file, f.READ)
			mainNodePath.languages[file.split(".")[0]] = parse_json(f.get_as_text())
			f.close()
		# files with GDScript
		elif file.ends_with(".ssg"):
			var f : File = File.new()
			f.open("res://scenario/" + file, f.READ)
			var scriptSection : String = ""
			var scripts : Dictionary = {}
			for line in f.get_as_text().split("\n"):
				if line == "":
					continue
				elif line.begins_with("##"):
					scriptSection = line.replace("#", "")
					scripts[scriptSection] = ""
				else:
					scripts[scriptSection] += line + "\n"
			mainNodePath.scriptDict = scripts
			f.close()
		else:
			pass
	
	if not scenario == []:
		mainNodePath.fullGameScript = _parser(_tokenizer(scenario))


func _tokenizer(scenario:Array) -> Dictionary:
	var tokenScenario : Dictionary = {}
	var currentJump : String = ""
	var ifCount : int = 0
	var ifID : int = 0
	var lineCount : int = 0
	
	for line in scenario:
		lineCount += 1
		if line.begins_with("*"):
			lineCount = 0
			currentJump = line
			tokenScenario[currentJump] = {}
			continue
		elif line == "" or line.begins_with("#"):
			line = {"funcs":["empty"]}
		# if it's a command
		elif line.begins_with("@"):
			line = line.replace("@", "").replace(" =", "=").replace("= ", "=").replace(" = ", "=").replace("\"", "").replace("==", "=").split(" ")
			var parsedLine : Dictionary = {}
			var exceptionsToAddToFunc : Array = ["var", "return", "if", "elif", "else", "endif", "autosave"]
			parsedLine["funcs"] = []
			var mainTag : String = ""
			for value in line:
				if not "=" in value:
					if mainTag == "":
						mainTag = value
						parsedLine["tag"] = mainTag
						# add here if a "tag" value also needs to call a function
						if mainTag in exceptionsToAddToFunc:
							if mainTag in funcRefArray:
								parsedLine["funcs"].append(mainTag)
					else:
						if value in funcRefArray:
							parsedLine["funcs"].append(value)
				else:
					var splitValue = value.split("=")
					if splitValue[1].begins_with("&"):
						parsedLine[splitValue[0]] = {"var":splitValue[1].replace("&", "")}
					else:
						if splitValue[1] in allGameFiles:
							splitValue[1] = allGameFiles[splitValue[1]]
						parsedLine[splitValue[0]] = splitValue[1]
					# don't add a function more than once per line
					if not splitValue[0] in parsedLine["funcs"]:
						if splitValue[0] in funcRefArray:
							parsedLine["funcs"].append(splitValue[0])
			line = parsedLine
		# if it's text/dialogue
		else:
			line = {"text":line, "funcs":["text"]}
		tokenScenario[currentJump][str(lineCount)] = line
			
	return tokenScenario


func _parser(tokenScript:Dictionary):
	
	return tokenScript

func _createFuncRefArray() -> void:
	var funcList : Array = [
		"text",
		"create",
		"destroy",
		"destroyall",
		"storage",
		"group",
		"jump",
		"print",
		"wait",
		"moveto",
		"moveby",
		"empty",
		"setlayer",
		"size",
		"pos",
		"show",
		"hide",
		"var",
		"play",
		"volume",
		"stop",
		"seek",
		"script",
		"macro",
		"return",
		"call",
		"dia",
		"material",
		"theme",
		"fadein",
		"fadeout",
		"autosave"
		
	]
	funcRefArray = funcList


# lists all files in a given directory
func _listAllFilesInDirectory(path:String) -> Array:
	var files : Array = []
	var dir : Directory = Directory.new()
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
