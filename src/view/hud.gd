extends Node2D

const NAMES := ["YOU", "CPU"]

var sim = null

func render(s) -> void:
	sim = s
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var font := ThemeDB.fallback_font
	var games := "%s %d - %d %s" % [NAMES[0], sim.score.games[0], sim.score.games[1], NAMES[1]]
	draw_string(font, Vector2(20, 40), games, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var points := "%s - %s" % [sim.score.score_text(0), sim.score.score_text(1)]
	draw_string(font, Vector2(540, 40), points, HORIZONTAL_ALIGNMENT_CENTER, 200, 28, Color.WHITE)
	if sim.score.match_winner != -1:
		var msg := "%s WINS! (hit to restart)" % NAMES[sim.score.match_winner]
		draw_string(font, Vector2(340, 300), msg, HORIZONTAL_ALIGNMENT_CENTER, 600, 40, Color.YELLOW)
	elif sim.last_event != "":
		draw_string(font, Vector2(340, 300), sim.last_event, HORIZONTAL_ALIGNMENT_CENTER, 600, 36, Color.ORANGE)
	elif not sim.ball.in_play and sim.pause_ticks == 0:
		draw_string(font, Vector2(490, 640), "%s SERVE" % NAMES[sim.server], HORIZONTAL_ALIGNMENT_CENTER, 300, 22, Color(1, 1, 1, 0.6))
