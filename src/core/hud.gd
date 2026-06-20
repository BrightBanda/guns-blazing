extends CanvasLayer

@onready var ammo_label:Label = $Ammo
@onready var reload_indicator:Label = $CenterContainer/ReloadIndicator

func _ready() -> void:
	if not reload_indicator:
		reload_indicator = $CenterContainer/ReloadIndicator
	reload_indicator.visible = false
	
func on_ammo_changed(current:int,max:int):
	if not ammo_label:
		ammo_label = $Ammo
	ammo_label.text = str(current) + " / " + str(max)
	
func on_reload_started():
	if not reload_indicator:
		reload_indicator = $CenterContainer/ReloadIndicator
	reload_indicator.visible = true

func on_reload_finished():
	if not reload_indicator:
		reload_indicator = $CenterContainer/ReloadIndicator
	reload_indicator.visible = false
