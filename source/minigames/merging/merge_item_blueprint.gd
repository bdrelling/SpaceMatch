class_name MergeItemBlueprint
extends Resource
## One rung of a merge ladder: the size, color, and optional sprite of an item at a single tier. Two
## touching items on the same rung promote to the next one up; [member radius] sets both the physics
## body and how large the item draws.

@export var display_name: String = ""
## Collision and draw radius, in board pixels. Each rung up the ladder is larger.
@export var radius: float = 24.0
## Fill color used when no [member texture] is set.
@export var color: Color = Color.WHITE
## Optional sprite, drawn fit to the item's diameter in place of the flat circle.
@export var texture: Texture2D = null

## A fallback ladder of circles tinted like Suika's fruit run — stand-ins until real item sprites are
## authored as [MergeItemBlueprint] resources and assigned on the stage. Radii run from [param base_radius]
## (tier 0) up to [param max_radius] (the top tier), interpolated in log space so the endpoints land
## exactly. [param curve] bends the spacing: 1.0 = constant ratio, below 1 spreads the small tiers
## apart (gentler top), above 1 clusters them tiny (then ramps hard). Past the palette, hues fall back
## to a golden-angle stagger.
static func default_ladder(count: int = 11, base_radius: float = 30.0, max_radius: float = 216.0, curve: float = 1.0) -> Array[MergeItemBlueprint]:
	var span: float = max_radius / base_radius
	var steps: float = float(maxi(count - 1, 1))
	# Sampled from a Suika reference shot (apple cleaned up — its sample point caught a shadow; the top
	# four are eyeballed Suika hues since the reference only showed the first several fruits).
	var palette: Array[Color] = [
		Color(0.91, 0.27, 0.20),  # cherry
		Color(0.92, 0.45, 0.34),  # strawberry
		Color(0.58, 0.41, 0.96),  # grape
		Color(0.88, 0.67, 0.34),  # dekopon
		Color(0.90, 0.50, 0.22),  # persimmon
		Color(0.80, 0.18, 0.17),  # apple
		Color(0.78, 0.85, 0.38),  # pear
		Color(0.97, 0.72, 0.72),  # peach
		Color(0.98, 0.84, 0.30),  # pineapple
		Color(0.64, 0.84, 0.42),  # melon
		Color(0.30, 0.64, 0.30),  # watermelon
	]
	var ladder: Array[MergeItemBlueprint] = []
	for index: int in count:
		var rung := MergeItemBlueprint.new()
		rung.display_name = "Item %d" % (index + 1)
		var t: float = float(index) / steps
		rung.radius = base_radius * pow(span, pow(t, curve))
		if index < palette.size():
			rung.color = palette[index]
		else:
			rung.color = Color.from_hsv(fmod(float(index) * 0.618, 1.0), 0.7, 0.9)
		ladder.append(rung)
	return ladder
