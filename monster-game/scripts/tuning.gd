class_name HordeTuning
extends RefCounted

# World pixels and seconds. Experimental game values for playtest tuning.
const PREVIOUS_TUNNEL_DISTANCE = 18000.0
const TUNNEL_DISTANCE_MULTIPLIER = 0.70 * 1.20
const TUNNEL_DISTANCE = PREVIOUS_TUNNEL_DISTANCE * TUNNEL_DISTANCE_MULTIPLIER
const PHASE_ENDS = [3, 6, 8, 10]
const CHALLENGE_WEIGHTS = [Vector3(0.70, 0.27, 0.03), Vector3(0.52, 0.38, 0.10), Vector3(0.38, 0.43, 0.19), Vector3(0.25, 0.47, 0.28), Vector3(0.18, 0.44, 0.38)]
const GROWTH_CHANCE = [0.64, 0.50, 0.40, 0.31, 0.24]
const HELICOPTER_CHANCE = [0.02, 0.06, 0.10, 0.10, 0.14]
const HELICOPTER_COOLDOWN_SECONDS = [27.0, 23.0, 19.0, 17.0, 15.0]
const MAX_BOMBS = [2, 3, 3, 4, 6]
const MAX_GAPS = [1, 1, 2, 3, 4]
const GAP_SMALL_SECONDS = Vector2(0.38, 0.49)
const GAP_MEDIUM_SECONDS = Vector2(0.58, 0.72)
const GAP_LARGE_SECONDS = Vector2(0.84, 0.94)
const LANDING_RECOVERY_SECONDS = 0.32
const SEQUENCE_REACTION_SECONDS = 1.15
const MAX_QUIET_SECONDS = 3.6
const COIN_CHANCE = 0.70 * 0.70
# The v0.8.7 playtest baseline was about 1.8 physical coins per road second.
# Budget complete formations at 70% of that density, rather than thinning grids.
const COINS_PER_ROAD_SECOND = 1.80 * 0.70
const COIN_CREDIT_LIMIT = 24.0
const BOMB_PITCH = 64.0
const BOMB_WIDTH = 42.0 * 1.10
const BOMB_HEIGHT = 68.0 * 1.10
const COLLAPSE_WARNING_SECONDS = 0.65
const HISTORY_LENGTH = 5
const BONUS_COOLDOWN = Vector2(0.60, 0.90)
const BONUS_DEADLINE = Vector2(1.80, 2.30)
const BONUS_WINDOW_SECONDS = 2.8
const BONUS_INITIAL_CHANCE = 0.14
const BONUS_CHANCE_STEP = 0.085
const TRACE_LENGTH = 48
const FOLLOWER_DELAY_STEP = 0.008
const INPUT_BUFFER_SECONDS = 0.14
const FOLLOWER_INPUT_WINDOW = 0.16
const MIN_TAP_HOLD = 0.04
const BASE_POWER_SECONDS = 11.0
const BOOST_SECONDS = 8.0
const POSITIVE_CONTENT_MULTIPLIER = 0.85

static func phase(tunnel: int) -> int:
	for i in range(PHASE_ENDS.size()):
		if tunnel <= PHASE_ENDS[i]: return i
	return 4

static func tunnel_interval(cruise: float) -> float:
	return TUNNEL_DISTANCE * maxf(1.0, cruise / 305.0)
