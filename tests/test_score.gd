extends "res://tests/test_base.gd"

const MatchScore := preload("res://src/sim/match_score.gd")

func test_point_labels() -> void:
	var s := MatchScore.new()
	check(s.score_text(0) == "0", "no points shows 0")
	s.point_won_by(0)
	check(s.score_text(0) == "15", "first point shows 15")
	s.point_won_by(0)
	check(s.score_text(0) == "30", "second point shows 30")
	s.point_won_by(0)
	check(s.score_text(0) == "40", "third point shows 40")

func test_four_straight_points_win_game() -> void:
	var s := MatchScore.new()
	for i in 4:
		s.point_won_by(0)
	check(s.games[0] == 1, "four straight points must win the game")
	check(s.points[0] == 0 and s.points[1] == 0, "points must reset after a game")

func test_deuce_shows_forty_forty() -> void:
	var s := MatchScore.new()
	for i in 3:
		s.point_won_by(0)
		s.point_won_by(1)
	check(s.score_text(0) == "40" and s.score_text(1) == "40", "deuce shows 40-40")
	check(s.games[0] == 0 and s.games[1] == 0, "deuce must not end the game")

func test_advantage_and_back_to_deuce() -> void:
	var s := MatchScore.new()
	for i in 3:
		s.point_won_by(0)
		s.point_won_by(1)
	s.point_won_by(0)
	check(s.score_text(0) == "Ad" and s.score_text(1) == "40", "leader at deuce has advantage")
	s.point_won_by(1)
	check(s.score_text(0) == "40" and s.score_text(1) == "40", "losing the advantage returns to deuce")

func test_advantage_converts_game() -> void:
	var s := MatchScore.new()
	for i in 3:
		s.point_won_by(0)
		s.point_won_by(1)
	s.point_won_by(0)
	s.point_won_by(0)
	check(s.games[0] == 1, "winning the advantage point must win the game")

func test_three_games_win_match() -> void:
	var s := MatchScore.new()
	for g in 3:
		for p in 4:
			s.point_won_by(0)
	check(s.match_winner == 0, "three games must win the match")
	s.point_won_by(1)
	check(s.points[1] == 0, "no scoring after the match is over")
