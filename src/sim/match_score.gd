extends RefCounted

const POINT_LABELS := ["0", "15", "30", "40"]
const GAMES_TO_WIN := 3

var points := [0, 0]        # raw point counts within the current game
var games := [0, 0]
var match_winner := -1      # -1 = match ongoing, else winning player index

func point_won_by(i: int) -> void:
	if match_winner != -1:
		return
	points[i] += 1
	if points[i] >= 4 and points[i] - points[1 - i] >= 2:
		points = [0, 0]
		games[i] += 1
		if games[i] >= GAMES_TO_WIN:
			match_winner = i

func score_text(i: int) -> String:
	if points[0] >= 3 and points[1] >= 3:
		return "Ad" if points[i] > points[1 - i] else "40"
	return POINT_LABELS[mini(points[i], 3)]
