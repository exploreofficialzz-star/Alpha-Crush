extends RefCounted
class_name TestBattleNodes

static func run() -> bool:
    var ok := true
    ok = _fighter_damage() and ok
    ok = _director() and ok
    ok = _explosion_and_props() and ok
    ok = _zones_and_pickups() and ok
    return ok

static func _hit(amount: float, team: int, kind: int = DamageInfo.KIND_BULLET) -> DamageInfo:
    return DamageInfo.make(amount, kind, null, team, Vector3.ZERO, Vector3.FORWARD)

static func _fighter_damage() -> bool:
    var ok := true
    var fighter := Fighter.new()
    fighter.team = Teams.ALPHA
    fighter.max_health = 100.0
    fighter.health = 100.0
    fighter.max_armor = 50.0
    fighter.armor = 50.0
    var deaths: Array[int] = []
    fighter.died.connect(func(_info: DamageInfo): deaths.append(1))
    ok = TestSupport.expect(TestSupport.approx(fighter.take_damage(_hit(20.0, Teams.OPPOSITION)), 20.0), "damage reports what landed") and ok
    ok = TestSupport.expect(TestSupport.approx(fighter.armor, 38.0) and TestSupport.approx(fighter.health, 92.0), "armour soaks 60% of a hit") and ok
    ok = TestSupport.expect(fighter.take_damage(_hit(30.0, Teams.ALPHA)) == 0.0 and TestSupport.approx(fighter.health, 92.0), "friendly fire is ignored") and ok
    ok = TestSupport.expect(fighter.take_damage(_hit(10.0, Teams.ALPHA, DamageInfo.KIND_ENVIRONMENT)) > 0.0, "environmental damage hurts everyone") and ok
    fighter.invulnerable = 1.0
    var health_before := fighter.health
    ok = TestSupport.expect(fighter.take_damage(_hit(50.0, Teams.OPPOSITION)) == 0.0 and TestSupport.approx(fighter.health, health_before), "dodge i-frames block damage") and ok
    fighter.invulnerable = 0.0
    var stunning := _hit(5.0, Teams.OPPOSITION)
    stunning.stagger = 0.5
    stunning.knockback = 4.0
    stunning.direction = Vector3(1.0, 0.0, 0.0)
    fighter.stagger_resist = 0.5
    fighter.take_damage(stunning)
    ok = TestSupport.expect(TestSupport.approx(fighter.stunned, 0.25), "stagger resistance halves the stun") and ok
    fighter.heal(1000.0)
    ok = TestSupport.expect(TestSupport.approx(fighter.health, 100.0), "healing caps at max health") and ok
    fighter.add_armor(1000.0)
    ok = TestSupport.expect(TestSupport.approx(fighter.armor, 50.0), "armour caps at max armour") and ok
    fighter.take_damage(_hit(10000.0, Teams.OPPOSITION))
    ok = TestSupport.expect(not fighter.alive and deaths.size() == 1 and TestSupport.approx(fighter.health, 0.0), "lethal damage defeats the fighter once") and ok
    ok = TestSupport.expect(fighter.take_damage(_hit(10.0, Teams.OPPOSITION)) == 0.0 and deaths.size() == 1, "the defeated cannot be hurt again") and ok
    fighter.free()

    var own := Fighter.new()
    own.team = Teams.ALPHA
    var info := DamageInfo.make(40.0, DamageInfo.KIND_BULLET, own, Teams.OPPOSITION, Vector3.ZERO, Vector3.FORWARD)
    ok = TestSupport.expect(own.take_damage(info) == 0.0, "you cannot hurt yourself") and ok
    own.free()
    return ok

static func _director() -> bool:
    var ok := true
    var root := TestSupport.tree_root()
    var director := CombatDirector.new()
    root.add_child(director)
    var near := Node3D.new()
    near.position = Vector3(0.0, 0.0, -5.0)
    var far := Node3D.new()
    far.position = Vector3(0.0, 0.0, -30.0)
    var ally := Node3D.new()
    ally.position = Vector3(2.0, 0.0, 0.0)
    for node in [near, far, ally]:
        root.add_child(node)
    director.register(near, Teams.OPPOSITION)
    director.register(far, Teams.OPPOSITION)
    director.register(ally, Teams.ALPHA)
    ok = TestSupport.expect(director.count(Teams.OPPOSITION) == 2 and director.count(Teams.ALPHA) == 1, "rosters count each side") and ok
    ok = TestSupport.expect(director.nearest(Vector3.ZERO, Teams.OPPOSITION) == near, "nearest finds the closest enemy") and ok
    ok = TestSupport.expect(director.nearest(Vector3.ZERO, Teams.OPPOSITION, 3.0) == null, "nearest respects the distance limit") and ok
    ok = TestSupport.expect(director.in_radius(Vector3.ZERO, 10.0, Teams.OPPOSITION).size() == 1, "in_radius filters by distance") and ok
    director.register(near, Teams.OPPOSITION)
    ok = TestSupport.expect(director.count(Teams.OPPOSITION) == 2, "registering twice does nothing") and ok
    director.unregister(far)
    ok = TestSupport.expect(director.count(Teams.OPPOSITION) == 1, "unregister removes a fighter") and ok
    director.register(far, Teams.OPPOSITION)

    director.set_aggression(1.0)
    ok = TestSupport.expect(director.ranged_tokens == 2 and director.melee_tokens == 2, "gentle difficulty allows two attackers of each kind") and ok
    var a := Node3D.new()
    var b := Node3D.new()
    var c := Node3D.new()
    ok = TestSupport.expect(director.request_token(a, CombatDirector.KIND_RANGED) and director.request_token(b, CombatDirector.KIND_RANGED), "the first two shooters get a token") and ok
    ok = TestSupport.expect(not director.request_token(c, CombatDirector.KIND_RANGED), "the third shooter must wait") and ok
    ok = TestSupport.expect(director.request_token(a, CombatDirector.KIND_RANGED), "holding a token keeps it") and ok
    director.release_token(a, CombatDirector.KIND_RANGED)
    ok = TestSupport.expect(director.request_token(c, CombatDirector.KIND_RANGED) and director.holds_token(c, CombatDirector.KIND_RANGED), "a released token goes to the next in line") and ok
    director.release_all(b)
    ok = TestSupport.expect(director.token_count(CombatDirector.KIND_RANGED) == 1, "release_all frees every token a fighter holds") and ok
    director.set_aggression(4.0)
    ok = TestSupport.expect(director.ranged_tokens == 5 and director.melee_tokens == 4, "harder difficulty allows more attackers") and ok
    var ring := CombatDirector.surround_point(Vector3.ZERO, 0, 4, 5.0)
    ok = TestSupport.expect(TestSupport.approx(ring.length(), 5.0, 0.01), "surround points lie on the circle") and ok
    for node in [near, far, ally]:
        root.remove_child(node)
        node.free()
    for node in [a, b, c]:
        node.free()
    root.remove_child(director)
    director.free()
    return ok

static func _explosion_and_props() -> bool:
    var ok := true
    var root := TestSupport.tree_root()
    ok = TestSupport.expect(TestSupport.approx(Explosion.damage_at(0.0, 5.0, 100.0), 100.0) and TestSupport.approx(Explosion.damage_at(5.0, 5.0, 100.0), 0.0) and TestSupport.approx(Explosion.damage_at(4.99, 5.0, 100.0), 30.0, 1.0), "blast damage fades from full to nothing at the rim") and ok
    ok = TestSupport.expect(Explosion.damage_at(2.0, 5.0, 100.0) > Explosion.damage_at(4.0, 5.0, 100.0), "closer is worse") and ok
    ok = TestSupport.expect(Explosion.detonate(null, null, Vector3.ZERO, 5.0, 100.0, Teams.ALPHA, null) == 0, "detonating with no referee is harmless") and ok
    var crate := BreakableProp.new()
    root.add_child(crate)
    crate.setup("crate")
    var broken: Array[int] = []
    crate.destroyed.connect(func(_prop: BreakableProp): broken.append(1))
    var loot: Array[Vector3] = []
    crate.loot_callback = func(point: Vector3): loot.append(point)
    ok = TestSupport.expect(crate.is_in_group("breakable") and crate.collision_layer == Teams.LAYER_BREAKABLE, "crates are breakable props on their own layer") and ok
    crate.take_damage(_hit(10.0, Teams.ALPHA))
    ok = TestSupport.expect(broken.is_empty(), "a crate survives a light hit") and ok
    crate.take_damage(_hit(100.0, Teams.ALPHA))
    ok = TestSupport.expect(broken.size() == 1 and loot.size() == 1, "a crate drops loot when smashed") and ok
    var barrel := BreakableProp.new()
    root.add_child(barrel)
    barrel.setup("barrel")
    ok = TestSupport.expect(TestSupport.approx(barrel.health, 30.0), "barrels are fragile") and ok
    barrel.take_damage(_hit(100.0, Teams.ALPHA))
    ok = TestSupport.expect(not barrel.is_in_group("breakable"), "a destroyed barrel leaves the breakable group") and ok
    root.remove_child(crate)
    root.remove_child(barrel)
    crate.free()
    barrel.free()
    return ok

static func _zones_and_pickups() -> bool:
    var ok := true
    var zone := CaptureZone.new()
    zone.setup("A")
    zone.set_initial_owner(Teams.OPPOSITION)
    var changes: Array[int] = []
    zone.ownership_changed.connect(func(_z: CaptureZone, new_owner: int): changes.append(new_owner))
    ok = TestSupport.expect(TestSupport.approx(zone.progress, -1.0) and zone.owner_team == Teams.OPPOSITION, "the flag starts in enemy hands") and ok
    zone.update_zone(10.0, 1, 1)
    ok = TestSupport.expect(zone.contested and TestSupport.approx(zone.progress, -1.0), "a contested flag does not move") and ok
    for i in 12:
        zone.update_zone(1.0, 1, 0)
    ok = TestSupport.expect(zone.owner_team == Teams.ALPHA and changes == [Teams.ALPHA], "standing alone captures the flag") and ok
    zone.update_zone(1.0, 0, 0)
    ok = TestSupport.expect(zone.owner_team == Teams.ALPHA, "an empty flag stays captured") and ok
    var root := TestSupport.tree_root()
    root.add_child(zone)
    zone.global_position = Vector3(100.0, 0.0, 100.0)
    ok = TestSupport.expect(zone.contains(Vector3(103.0, 5.0, 100.0)) and not zone.contains(Vector3(130.0, 0.0, 100.0)), "the ring is measured on the ground plane") and ok
    root.remove_child(zone)
    zone.free()
    for kind in ["coin", "health", "ammo", "armor", "grenade"]:
        var pickup := Pickup.create(kind, 5)
        ok = TestSupport.expect(pickup.kind == kind and pickup.amount == 5 and pickup.get_child_count() > 0, "%s pickup builds" % kind) and ok
        pickup.free()
    return ok
