class_name Audio
extends Node
## Tiny audio singleton: SFX one-shots + looping battle BGM.
## Game creates one instance; all play calls are static and no-op
## when no instance exists (e.g. running a scene standalone).

static var instance: Audio = null

const SFX := {
	"hit": preload("res://assets/audio/hit.mp3"),
	"push": preload("res://assets/audio/push.mp3"),
	"splash": preload("res://assets/audio/splash.mp3"),
	"building": preload("res://assets/audio/building.mp3"),
	"click": preload("res://assets/audio/click.mp3"),
	"heal": preload("res://assets/audio/heal.mp3"),
	"spawn": preload("res://assets/audio/spawn.mp3"),
}
const BGM := preload("res://assets/audio/battle_bgm.mp3")

var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	instance = self
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.stream = BGM
	_bgm_player.stream.loop = true
	_bgm_player.volume_db = -8.0
	add_child(_bgm_player)


static func play(name: String) -> void:
	if instance == null or not Audio.SFX.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = Audio.SFX[name]
	p.volume_db = -4.0
	instance.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func play_for_event(ev: Dictionary) -> void:
	match ev["type"]:
		"unit_damaged":
			Audio.play("hit")
		"unit_pushed":
			Audio.play("push")
		"unit_died":
			Audio.play("splash" if ev["cause"] in ["water", "chasm"] else "hit")
		"building_damaged", "mountain_damaged":
			Audio.play("building")
		"unit_healed":
			Audio.play("heal")
		"vek_spawned", "spawn_blocked":
			Audio.play("spawn")


static func click() -> void:
	Audio.play("click")


static func bgm(on: bool) -> void:
	if instance == null:
		return
	if on and not instance._bgm_player.playing:
		instance._bgm_player.play()
	elif not on:
		instance._bgm_player.stop()
