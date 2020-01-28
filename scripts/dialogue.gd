extends RichTextLabel

onready var _delta : float = 0.0
onready var _textSpeed : float = 0.01

func _ready() -> void:
	set_process(false)

func _process(delta:float) -> void:
	if global.inSkipMode:
		visible_characters = global.visibleCharsMax
		global.visibleChars = global.visibleCharsMax
		global.mainNodePath.emitNextLine()
		return
	if global.forcePrint:
		visible_characters = global.visibleCharsMax
		global.visibleChars = global.visibleCharsMax
		set_process(false)
		_finish()
		return
	_delta += delta
	if _delta >= _textSpeed:
		_delta = 0
		visible_characters += 1
		global.visibleChars += 1
		if global.visibleChars == global.visibleCharsMax:
			global.forcePrint = true
			set_process(false)
			_finish()


# for auto mode waiting
func _finish():
	if global.inAutoMode:
		global.mainNodePath.wait(global.autoModeTime)


func textInit(text:String) -> void:
	# set text colour
	text = text.replace("[r]", "\n")
	# for line continuation after click. Use @dia=cleartext to end text section
	if "[l]" in text and not self.bbcode_text == "":
		visible_characters = self.get_total_character_count()
		global.visibleChars = self.get_total_character_count()
	else:
		clear()
		visible_characters = 0
		global.visibleChars = 0
		text = "[color=#000000]" + text
	text = text.replace("[l]", "")
	bbcode_text += text
	# TODO: temp fix. text.length() will get the length including bbcode in the text, which is not wanted
	global.visibleCharsMax = global.visibleChars + text.length()
	set_process(true)


