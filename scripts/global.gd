extends Node

# project settings
onready var gameName : String = "SiennaScripter"
onready var isRelease : bool = false
onready var scenarioEncryptionKey : String = "@TheVeryLeast#SlackenTheMaize"

# system settings
onready var isMobilePlatform : bool = false
onready var mainNodePath

# for dialogue
onready var visibleChars : int = 0
onready var textLen : int = 0
onready var visibleCharsMax : int = 0
onready var forcePrint : bool = false

#game settings
onready var currentLanguage : String = "en"
onready var inSkipMode : bool = false
onready var inAutoMode : bool = false
onready var autoModeTime : float = 1

onready var saveAllGameNodeData : Dictionary = {}

# for save/load menus
onready var savePage : int = 1
onready var saveSlot : int = 1


func _ready() -> void:
	print("game start")


var systemSave : Dictionary = {
	"language": "ch",
	"textSpeed": 1,
	"screenSetting": "windowed",
	"skipMode": "all",
	"animations": true,
	"skipSpeed": 2,
	"autoSpeed": 2,
	"masterVolume": 0,
	"voiceVolume": 0,
	"soundVolume": 0,
	"seenJumpsMaxLine": {},
	
}

var gameSave : Dictionary = {
	"scriptVariables": {
		"lang" : systemSave["language"],
		},
	"macroVariables": {},
	"currentJump": "*init",
	"currentLine": 0,
	"currentMacroJump": "",
	"currentMacroLine" : 0,
	
	
}


func saveSystem() -> void:
	var f : File = File.new()
	f.open("user://conf.conf", f.WRITE)
	f.store_line(to_json(systemSave))
	f.close()

func loadSystem() -> void:
	var f : File = File.new()
	if f.file_exists("user://conf.conf"):
		f.open("user://conf.conf", f.READ)
		systemSave = parse_json(f.get_as_text())
	f.close()


func saveGame(slot:String):
	_saveAllNodes(get_tree().get_root())
	# print(saveAllGameNodeData)
	saveAllGameNodeData["gameSave"] = gameSave
	#return
	var f : File = File.new()
	f.open("user://%s.sisave" %slot, f.WRITE)
	f.store_line(to_json(saveAllGameNodeData))
	f.close()


func loadGame(slot:String):
	var f : File = File.new()
	f.open("user://%s.sisave" %slot, f.READ)
	systemSave = parse_json(f.get_as_text())
	f.close()


func _saveAllNodes(root):
	for node in root.get_children():
		var nodeName = node.get_name()
		if "@@" in nodeName:
			continue
		match node.get_class():
			"Node":
				pass
			"Node2D":
				pass
			# ignore for now, created with RichTextLabel
			"VScrollBar":
				pass
			"TextureRect":
				if node.texture == null:
					saveAllGameNodeData[nodeName] = {"name":nodeName, "path":str(node.get_path()).replace("/"+nodeName, ""), "storage":null, "pos":node.rect_position, "size":node.rect_size, "material":node.material}
				else:
					saveAllGameNodeData[nodeName] = {"name":nodeName, "path":str(node.get_path()).replace("/"+nodeName, ""), "storage":node.texture.resource_path, "pos":node.rect_position, "size":node.rect_size, "material":node.material}
			"RichTextLabel":
				saveAllGameNodeData[nodeName] = {"name":nodeName, "path":str(node.get_path()).replace("/"+nodeName, ""), "text":node.text, "pos":node.rect_position, "size":node.rect_size}
			"TextureButton":
				saveAllGameNodeData[nodeName] = {"name":nodeName, "path":str(node.get_path()).replace("/"+nodeName, ""), "pos":node.rect_position, "size":node.rect_size}
			"AudioStreamPlayer", "VideoPlayer":
				if node.stream == null:
					saveAllGameNodeData[nodeName] = {"name":nodeName, "path":str(node.get_path()).replace("/"+nodeName, ""), "stream":null}
				else:
					saveAllGameNodeData[nodeName] = {"name":nodeName, "path":str(node.get_path()).replace("/"+nodeName, ""), "stream":node.stream.resource_path}
			_:
				print(node.get_name())
				print(node.get_class())
		
		if node.get_child_count() > 0:
			_saveAllNodes(node)








