extends RefCounted
class_name TestAvatarRig

## The four humans (boy, girl, man, woman) must load as skinned models with every bone the animation needs,
## accept every outfit, survive animation without a script error and keep their attachments.
const CASES: Array = [["male", "child", "boy"], ["female", "child", "girl"], ["male", "adult", "man"], ["female", "adult", "woman"]]

static func run() -> bool:
    for case in CASES:
        var rig := AvatarRig.new()
        var outfit := AvatarRig.outfit_for("default", 3, str(case[0]))
        if not rig.build(str(case[0]), outfit, str(case[1])):
            rig.free()
            return false
        var ok := rig.kind == str(case[2]) and rig.skeleton != null and rig.skeleton.get_bone_count() >= AvatarRig.JOINT_NAMES.size()
        for joint_name in AvatarRig.JOINT_NAMES:
            ok = ok and rig.skeleton.find_bone(joint_name) >= 0
        ok = ok and rig.head_top > 1.0 and rig.head_top < 2.2
        # animate through idle, walk, run, carry, jump and reach; the pose must stay finite
        rig.animate(0.016, 0.0, true)
        rig.animate(0.016, 3.0, true)
        rig.animate(0.016, 7.0, true, true)
        rig.carrying = true
        for _i in 20:
            rig.animate(0.03, 2.0, true)
        rig.play_reach()
        rig.animate(0.016, 0.0, false)
        var head_pose := rig.skeleton.get_bone_global_pose(rig.skeleton.find_bone("Head")).origin
        ok = ok and head_pose.is_finite() and head_pose.y > 0.8
        # outfits with a hat and a backpack create attachments
        var styled := AvatarRig.outfit_for("builder", 9, str(case[0]))
        rig.apply_outfit(styled)
        ok = ok and rig.skeleton.get_child_count() >= 1
        rig.free()
        if not ok:
            return false
    return AvatarRig.kind_for("female", "child") == "girl" and AvatarRig.kind_for("male", "adult") == "man" \
        and AvatarSpecs.get_spec("boy").has("pack") and AvatarSpecs.get_spec("nobody").has("height")
