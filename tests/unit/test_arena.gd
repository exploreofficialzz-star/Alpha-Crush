extends RefCounted
class_name TestArena

static func run() -> bool:
    var ok := true
    var center := BattleWorld.CENTER
    for hills in [3.0, 9.0]:
        var middle := ArenaTerrain.height_at(center.x, center.z, center, hills, 11)
        ok = TestSupport.expect(absf(middle) < 0.5, "the fighting floor is almost flat") and ok
        var rim := ArenaTerrain.height_at(center.x + 100.0, center.z, center, hills, 11)
        ok = TestSupport.expect(rim > hills * 0.3 and rim < hills + 0.5, "hills ring the arena") and ok
        var step_ok := true
        var x := center.x - 90.0
        while x < center.x + 90.0:
            if absf(ArenaTerrain.height_at(x + 1.0, center.z, center, hills, 11) - ArenaTerrain.height_at(x, center.z, center, hills, 11)) > 1.5:
                step_ok = false
            x += 1.0
        ok = TestSupport.expect(step_ok, "the ground has no cliffs") and ok
    ok = TestSupport.expect(ArenaTerrain.normal_at(center.x, center.z, center, 5.0, 11).y > 0.9, "the floor faces up") and ok
    ok = TestSupport.expect(TestSupport.approx(ArenaTerrain.height_at(center.x + 10.0, center.z + 10.0, center, 5.0, 7), ArenaTerrain.height_at(center.x + 10.0, center.z + 10.0, center, 5.0, 7)), "terrain is deterministic") and ok

    var patch := ArenaTerrain.build_patch(center, 5.0, 11, StandardMaterial3D.new())
    var cells := int(round(ArenaTerrain.EXTENT * 2.0 / ArenaTerrain.STEP))
    var faces: PackedVector3Array = patch["faces"]
    ok = TestSupport.expect(faces.size() == cells * cells * 6 and patch["mesh"] is ArrayMesh, "patch has two triangles per cell") and ok
    var upward := 0
    for i in range(0, faces.size(), 3):
        var normal := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
        if normal.y < 0.0:
            upward += 1
    ok = TestSupport.expect(float(upward) > float(faces.size()) / 6.0, "the triangles wind so the ground faces up (clockwise from above)") and ok
    ok = TestSupport.expect(Vector2(patch["origin"].x, patch["origin"].z).distance_to(Vector2(center.x - ArenaTerrain.EXTENT, center.z - ArenaTerrain.EXTENT)) < 0.01, "patch origin is its south-west corner") and ok
    return ok
