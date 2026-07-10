extends "res://tests/test_base.gd"

const Proj := preload("res://src/view/projection.gd")
const CourtSim := preload("res://src/sim/court_sim.gd")

func test_near_baseline_center() -> void:
	var p := Proj.to_screen(Vector2(0, -CourtSim.HALF_LENGTH))
	check(p == Vector2(Proj.SCREEN_W / 2.0, Proj.NEAR_Y), "near baseline center mapped to %s" % p)

func test_far_baseline() -> void:
	var p := Proj.to_screen(Vector2(0, CourtSim.HALF_LENGTH))
	check(p.y == Proj.FAR_Y, "far baseline mapped to y=%s" % p.y)

func test_court_narrows_with_depth() -> void:
	var near := Proj.to_screen(Vector2(CourtSim.HALF_WIDTH, -CourtSim.HALF_LENGTH))
	var far := Proj.to_screen(Vector2(CourtSim.HALF_WIDTH, CourtSim.HALF_LENGTH))
	check(far.x < near.x, "side line should pull toward center with depth (trapezoid)")

func test_height_lifts_ball_up_screen() -> void:
	var ground := Proj.to_screen(Vector2(0, 0))
	var lifted := Proj.to_screen(Vector2(0, 0), 1.0)
	check(lifted.y < ground.y, "height must offset the ball upward on screen")
