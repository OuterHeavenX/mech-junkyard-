extends SceneTree

## Rendered screenshot capture under xvfb (NOT headless — needs a renderer).
## Run: xvfb-run -a godot --path <proj> --resolution 1280x720 -s res://tests/shots.gd

const OUT := "res://shots/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://shots/")
	var game: MechGame = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	_run.call_deferred(game)


func _shot(path: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path)


func _run(game: MechGame) -> void:
	for i in 80:
		await physics_frame
	await _shot(OUT + "01_arena.png")

	# Kill a crusher next to the player to stage drops + debris.
	var player: PlayerMech = game.player
	game.spawn_enemy("crusher", player.position.x + 220.0)
	for i in 25:
		await physics_frame
	var enemies := get_nodes_in_group("enemies")
	var crusher: EnemyMech = null
	for cand in enemies:
		if (cand as EnemyMech).etype == "crusher":
			crusher = cand
	if crusher != null:
		crusher.take_damage(9999.0, 1.0, true)
	for i in 30:
		await physics_frame
	# Pull the player near the drops for a lively shot.
	player.position.x += 120.0
	for i in 20:
		await physics_frame
	await _shot(OUT + "02_drops.png")

	# Force-equip a crusher fist for the loadout/HUD shot.
	var part: PartPickup = null
	for p in get_nodes_in_group("pickups"):
		if p is PartPickup and (p as PartPickup).part_id == "crusher_fist":
			part = p
			break
	if part == null:
		for p in get_nodes_in_group("pickups"):
			if p is PartPickup:
				part = p
				break
	if part != null:
		player.position = part.position + Vector2(0, -20)
		player.velocity = Vector2.ZERO
		for i in 30:
			await physics_frame
		player.do_attack()
		for i in 12:
			await physics_frame
	await _shot(OUT + "03_pickup.png")
	quit()
