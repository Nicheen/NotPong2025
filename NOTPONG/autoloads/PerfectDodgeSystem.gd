# PerfectDodgeSystem.gd
# Lägg till detta script som en autoload (Singleton)
extends Node

signal perfect_dodge_triggered
signal time_slow_started
signal time_slow_ended

# Perfect dodge inställningar
var time_slow_duration: float = 0.12      # Hur länge slow motion varar
var damage_multiplier: float = 5.0       # Skademultiplikator under slow motion
var slow_motion_scale: float = 0.2       # Hur sakta tiden går (0.2 = 20% hastighet)

# State
var is_time_slowed: bool = false
var time_slow_timer: float = 0.0
var original_time_scale: float = 1.0

func _ready():
	# Spara original time scale
	original_time_scale = Engine.time_scale

func _process(delta):
	# Hantera time slow countdown
	if is_time_slowed:
		time_slow_timer -= delta
		if time_slow_timer <= 0:
			end_time_slow()

func trigger_perfect_dodge():
	"""Aktivera perfect dodge med time slow"""
	print("Perfect dodge triggered! Time slowing down...")
	
	is_time_slowed = true
	time_slow_timer = time_slow_duration
	Engine.time_scale = slow_motion_scale
	
	# Emit signals
	perfect_dodge_triggered.emit()
	time_slow_started.emit()

func end_time_slow():
	"""Avsluta time slow effekten"""
	if not is_time_slowed:
		return
		
	print("Time slow ending, returning to normal speed")
	
	is_time_slowed = false
	Engine.time_scale = original_time_scale
	time_slow_ended.emit()

func is_in_slow_motion() -> bool:
	return is_time_slowed

func get_damage_multiplier() -> float:
	if is_time_slowed:
		return damage_multiplier
	return 1.0

func cleanup():
	"""Återställ time scale när spelet avslutas"""
	Engine.time_scale = original_time_scale
	is_time_slowed = false
