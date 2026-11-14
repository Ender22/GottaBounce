class_name PlayerIdentity
## ONE player = ONE colour = their goat's colour (BACKLOG WK-08 · audit C-08 / R-04 / D-03 · COUCH_CONVENTIONS
## CC-8.3). The single source of truth for each goat skin's identity colour + display name. Every identity
## surface (HUD card, P# pip / name tag, edge chevron, banners, ScoreScreen, VictoryScreen) reads
## `PartyMatch.player_color(i)`, which resolves through `color_for_skin(players[i].skin)` — so a player's
## colour always follows the skin they actually WEAR (Sports team colourways included), never their slot.
##
## Values are the Herd roster colours (HerdLobby.HEROES, ex-CharacterSelect.gd:17-30). Keep the two in sync
## until HerdLobby reads this table directly (it is under design review; not touched by WK-08).

const SKIN_COLORS := {
	"pink": Color("#ff5fa8"),    # POGO
	"blue": Color("#4aa8ff"),    # BUTCH
	"green": Color("#54c94a"),   # ZIGGY
	"yellow": Color("#ffc93f"),  # PUFF
	"purple": Color("#a15fff"),  # VEX
	"orange": Color("#ff7a2d"),  # BILLY
}

const SKIN_NAMES := {
	"pink": "POGO", "blue": "BUTCH", "green": "ZIGGY",
	"yellow": "PUFF", "purple": "VEX", "orange": "BILLY",
}

## Fallback when a skin id is unknown (should not happen with the six shipped skins).
const UNKNOWN_COLOR := Color(0.94, 0.94, 0.94, 1.0)

## Identity colour of a goat skin id ("pink" .. "orange"). Unknown -> UNKNOWN_COLOR.
static func color_for_skin(skin: String) -> Color:
	if SKIN_COLORS.has(skin):
		var c: Color = SKIN_COLORS[skin]
		return c
	return UNKNOWN_COLOR

static func has_skin(skin: String) -> bool:
	return SKIN_COLORS.has(skin)

## Goat display name for a skin id ("blue" -> "BUTCH"). Unknown -> the id upper-cased.
static func name_for_skin(skin: String) -> String:
	return str(SKIN_NAMES.get(skin, skin.to_upper()))
