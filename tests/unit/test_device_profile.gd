extends RefCounted
class_name TestDeviceProfile

## Graphics-tier guessing and the adaptive governor's decision, as pure functions.
static func run() -> bool:
    # Typical Android Go / entry-level phones must start on the light tier.
    if DeviceProfile.tier_from(2800, 8, "Mali-G52 MC2", true) != "low":
        return false
    if DeviceProfile.tier_from(3300, 8, "Adreno (TM) 619", true) != "low":
        return false
    if DeviceProfile.tier_from(4096, 4, "Mali-G31", true) != "low":
        return false
    if DeviceProfile.tier_from(0, 4, "PowerVR Rogue GE8320", true) != "low":
        return false
    # Mid-range stays on medium, including when RAM / GPU are unknown.
    if DeviceProfile.tier_from(4000, 8, "Adreno (TM) 619", true) != "medium":
        return false
    if DeviceProfile.tier_from(0, 8, "", true) != "medium":
        return false
    # Flagships and desktops may use the high tier.
    if DeviceProfile.tier_from(8000, 8, "Adreno (TM) 740", true) != "high":
        return false
    if DeviceProfile.tier_from(4096, 4, "", false) != "high":
        return false
    # The governor reacts to a clearly slow average only.
    var slow: Array[float] = [19.0, 21.0, 20.0, 18.0, 22.0, 20.0]
    var fine: Array[float] = [29.0, 30.0, 30.0, 28.0, 30.0, 30.0]
    var empty: Array[float] = []
    if not AdaptiveQuality.should_step_down(slow, 30.0):
        return false
    if AdaptiveQuality.should_step_down(fine, 30.0):
        return false
    if AdaptiveQuality.should_step_down(empty, 30.0):
        return false
    var sixty_slow: Array[float] = [35.0, 36.0, 34.0, 35.0, 36.0, 35.0]
    var sixty_fine: Array[float] = [58.0, 60.0, 59.0, 57.0, 60.0, 60.0]
    return AdaptiveQuality.should_step_down(sixty_slow, 60.0) and not AdaptiveQuality.should_step_down(sixty_fine, 60.0)
