extends "res://scripts/enemy/lightning_strike.gd"

## Inherited damage/timing; shared cels replace stacked legacy stamps.
func create_telegraph_visual() -> void:
	super.create_telegraph_visual()
	var accent: Color = Color(1,.79,.39,.96) if presentation_theme == &"solar_nirvana" else Color(.60,.90,1,.96)
	if telegraph_visual != null: telegraph_visual.color = Color(accent,.105)
	if is_instance_valid(telegraph_outline):
		telegraph_outline.default_color = accent
		telegraph_outline.width = 2.7

func create_impact_visual() -> void:
	super.create_impact_visual()
