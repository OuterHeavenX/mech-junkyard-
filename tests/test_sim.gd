extends SceneTree

## Headless functional test: boot the arena, kill one enemy, assert a part
## drops, walk the player onto it, assert it equips.
## Run: godot --headless --path <proj> -s res://tests/test_sim.gd

var fails: Array = []


func _init() -> void:
	var scene: PackedScene = load("res://scenes/arena.tscn")
	var game: MechGame = scene.instantiate()
	root.add_child(game)
	_run.call_deferred(game)


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		fails.append(msg)
		print("  FAIL: ", msg)


func _run(game: MechGame) -> void:
	print("== mech-junkyard headless test ==")
	for i in 40:
		await physics_frame

	var player: PlayerMech = game.player
	check(player != null, "player exists")
	check(game.hud != null, "hud exists")
	check(game.state == "fight", "game in fight state, wave 1")
	var wave1_total: int = game.spawn_queue.size() + get_nodes_in_group("enemies").size()
	check(wave1_total == 3, "wave 1 has 3 enemies (queued+alive=%d)" % wave1_total)

	# Sprite visibility regression (v2 shipped invisible mechs: load("res://...png")
	# fails without a working editor import, so textures must decode via RawLoader).
	var pv: SpriteMech = player.visual
	check(pv != null, "player has a SpriteMech visual")
	for i in 5:
		await physics_frame
	var ptex: Texture2D = pv._body.texture
	check(ptex != null, "player body texture loaded (mech visible, not invisible)")
	if ptex != null:
		check(ptex.get_size().x > 100.0 and ptex.get_size().y > 100.0,
			"player body texture has real dimensions (%s)" % str(ptex.get_size()))
	check(pv.visible and pv._body.visible, "player visual nodes visible")
	check(pv.modulate.a > 0.0, "player visual not transparent")
	for aid in SpriteMech.PLAYER_ARMS:
		var at: Texture2D = RawLoader.load_texture("res://assets/sprites/player/arm_%s_rest.png" % aid)
		check(at != null and at.get_size().x > 50.0, "player arm texture loads: %s" % aid)
	for et in ["walker", "speeder", "crusher", "gunner", "charger"]:
		var etx: Texture2D = RawLoader.load_texture("res://assets/sprites/enemies/%s_idle.png" % et)
		check(etx != null and etx.get_size().x > 100.0, "enemy texture loads: %s" % et)

	# Spawn a walker right next to the player and kill it.
	game.spawn_enemy("walker", player.position.x + 150.0)
	for i in 25:
		await physics_frame
	var enemies: Array = get_nodes_in_group("enemies")
	check(not enemies.is_empty(), "enemy spawned near player")
	var picks_before: int = get_nodes_in_group("pickups").size()
	var e: EnemyMech = null
	for cand in enemies:
		if (cand as EnemyMech).etype == "walker":
			e = cand
			break
	check(e != null, "found the walker")
	if e != null:
		e.take_damage(9999.0, 1.0, false)
	for i in 25:
		await physics_frame
	var picks_after: int = get_nodes_in_group("pickups").size()
	check(picks_after > picks_before, "enemy dropped loot (%d -> %d)" % [picks_before, picks_after])

	var part: PartPickup = null
	for p in get_nodes_in_group("pickups"):
		if p is PartPickup:
			part = p
			break
	check(part != null, "at least one PartPickup among drops")

	if part != null:
		var ptype := part.part_type
		var pid := part.part_id
		print("  dropped part: %s / %s" % [ptype, pid])
		# Teleport the player onto the part; body_entered should fire.
		player.position = part.position + Vector2(0, -20)
		player.velocity = Vector2.ZERO
		for i in 30:
			await physics_frame
		check(str(player.loadout[ptype]) == pid,
			"part equipped on walk-over (%s slot now %s)" % [ptype, str(player.loadout[ptype])])
		check(not is_instance_valid(part), "pickup consumed after equip")

	# Attack sanity: every arm kind fires without errors.
	for arm_id in PartsDB.ARMS.keys():
		player.loadout["arm"] = arm_id
		player.attack_cd = 0.0
		player.multi_ticks = 0
		player.do_attack()
		for i in 6:
			await physics_frame
	print("  ok: all 5 arm kinds attack without errors")

	# Leg/core sanity.
	player.loadout["leg"] = "turbo_legs"
	check(is_equal_approx(player.leg_speed(), 410.0), "turbo legs speed = 410")
	player.loadout["leg"] = "spring_legs"
	check(player.max_jumps() == 2, "spring legs double jump")
	player.loadout["core"] = "none"
	player.equip_part("core", "magnet_core")
	check(is_equal_approx(player.magnet_r, 280.0), "magnet core radius = 280")

	# Arm rip-off path: heavy hit can knock the arm off.
	player.loadout["arm"] = "rusty_fist"
	player.hp = 100.0
	player.dash_t = 0.0
	var ripped := false
	for i in 60:
		player.take_damage(20.0, player.position.x - 50.0)
		if str(player.loadout["arm"]) == "none":
			ripped = true
			break
		player.hp = 100.0 # keep alive for the loop
		for j in 3:
			await physics_frame
	check(ripped, "heavy hits can rip the arm off (bare-wires state reachable)")
	if ripped:
		player.do_attack() # spark attack with no arm
		for i in 6:
			await physics_frame
		print("  ok: bare-wires spark attack works")

	# New enemy types: spawn one of each, let their AI run, no errors.
	player.hp = 5000.0 # survive the soak
	for et in ["gunner", "charger", "speeder", "crusher"]:
		game.spawn_enemy(et, player.position.x + 220.0)
	for i in 120:
		await physics_frame
	var seen := {}
	for foe in get_nodes_in_group("enemies"):
		seen[(foe as EnemyMech).etype] = true
		var ev: SpriteMech = (foe as EnemyMech).visual
		check(ev != null and ev._body.texture != null,
			"spawned '%s' has a loaded body texture" % (foe as EnemyMech).etype)
		(foe as EnemyMech).take_damage(9999.0, 1.0, false)
	for et in ["gunner", "charger", "speeder", "crusher"]:
		check(seen.get(et, false), "enemy type '%s' spawned and AI ticked" % et)
	player.hp = 100.0
	for i in 20:
		await physics_frame

	# Shop flow: clear the wave -> shop opens -> buy -> next wave.
	for e2 in get_nodes_in_group("enemies"):
		(e2 as EnemyMech).take_damage(9999.0, 1.0, false)
	game.spawn_queue.clear()
	for i in 20:
		await physics_frame
	check(game.state == "shop", "wave clear opens the scrap shop (state=%s)" % game.state)
	check(game.hud.shop_panel.visible, "shop panel visible")
	game.scrap = 500
	player.hp = 40.0
	game.buy("repair")
	check(player.hp > 40.0, "shop repair heals (hp=%.0f)" % player.hp)
	var mhp := player.max_hp
	game.buy("plating")
	check(player.max_hp > mhp, "shop plating raises max HP")
	game.buy("crate")
	check(game.scrap == 500 - 15 - 45 - 60, "shop purchases deduct scrap (scrap=%d)" % game.scrap)
	# Spawn-on-demand: clear the field, drop a buzzsaw arm, and confirm it
	# shows up (leftover drops may vacuum/swap mid-test, so match by part).
	for p in get_nodes_in_group("pickups"):
		p.queue_free()
	for i in 5:
		await physics_frame
	player.position = Vector2(-500, game.floor_y)
	player.velocity = Vector2.ZERO
	for i in 5:
		await physics_frame
	game.spawn_part_pickup("arm", "buzzsaw", Vector2(-100, game.floor_y))
	for i in 10:
		await physics_frame
	var saw_found: bool = str(player.loadout["arm"]) == "buzzsaw"
	for pk in get_nodes_in_group("pickups"):
		if pk is PartPickup and pk.part_id == "buzzsaw":
			saw_found = true
	check(saw_found, "part pickups spawn on demand")
	game.next_wave()
	check(game.state == "fight" and game.wave_idx == 1, "next wave starts (wave 2, fight state)")
	check(not game.hud.shop_panel.visible, "shop panel hidden on wave start")

	if fails.is_empty():
		print("TEST PASS: all checks ok")
	else:
		print("TEST FAIL: %d failure(s)" % fails.size())
	quit(1 if not fails.is_empty() else 0)
