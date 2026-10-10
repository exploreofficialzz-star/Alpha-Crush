extends RefCounted
class_name DeviceProfile

## Picks a starting graphics tier from what the phone reports. The decision logic is a pure
## function (tier_from) so it can be unit-tested without a device; detect() only gathers inputs.
## AdaptiveQuality then corrects the guess from the frame rate actually achieved.

const LOW_GPU_HINTS: Array[String] = [
    "mali-4", "mali-t", "mali-g31", "mali-g51", "mali-g52",
    "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 5", "adreno 3", "adreno 4", "adreno 5",
    "adreno (tm) 610", "adreno (tm) 612", "adreno (tm) 613", "adreno 610", "adreno 612", "adreno 613",
    "powervr", "sgx", "videocore", "llvmpipe", "swiftshader"
]
const HIGH_GPU_HINTS: Array[String] = [
    "adreno (tm) 7", "adreno 7", "adreno (tm) 66", "adreno (tm) 69", "adreno 66", "adreno 69",
    "mali-g7", "mali-g6", "immortalis", "apple", "nvidia", "geforce", "radeon"
]
## Phones report a little less than their marketed RAM, so "3 GB" arrives as roughly 2.7-2.9 GB.
const LOW_RAM_MB := 3400
const HIGH_RAM_MB := 7000

static func tier_from(ram_mb: int, cores: int, gpu_name: String, is_mobile: bool) -> String:
    if not is_mobile:
        return "high"
    var gpu := gpu_name.to_lower()
    var low_votes := 0
    var high_votes := 0
    if ram_mb > 0:
        if ram_mb <= LOW_RAM_MB:
            low_votes += 2
        elif ram_mb >= HIGH_RAM_MB:
            high_votes += 1
    if cores > 0 and cores <= 4:
        low_votes += 1
    for hint in LOW_GPU_HINTS:
        if gpu.contains(hint):
            low_votes += 2
            break
    for hint in HIGH_GPU_HINTS:
        if gpu.contains(hint):
            high_votes += 2
            break
    if low_votes >= 2:
        return "low"
    if high_votes >= 3 and low_votes == 0:
        return "high"
    return "medium"

static func is_mobile_device() -> bool:
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

static func ram_megabytes() -> int:
    var info: Dictionary = OS.get_memory_info()
    var physical := int(info.get("physical", -1))
    if physical <= 0:
        return 0
    return int(float(physical) / 1048576.0)

static func gpu_name() -> String:
    return RenderingServer.get_video_adapter_name()

static func detect() -> String:
    return tier_from(ram_megabytes(), OS.get_processor_count(), gpu_name(), is_mobile_device())
