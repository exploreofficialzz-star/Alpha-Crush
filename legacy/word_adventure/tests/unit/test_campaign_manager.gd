extends RefCounted
class_name TestCampaignManager

const STORY_WORDS := ["LADDER", "ORANGE", "BASKET", "MARKET", "BRIDGE", "SEEDS", "TOOLS", "LANTERN", "ENGINE", "KEY", "LIGHT"]

static func run() -> bool:
    var campaign: CampaignManager = preload("res://gameplay/campaign/campaign_manager.gd").new()
    if campaign.is_game_complete() or campaign.finale_ready:
        return false
    var unlocked: Array[bool] = []
    campaign.finale_unlocked.connect(func(): unlocked.append(true))
    # Regression: finishing the market through its alternate word OPEN must restore the same chapter.
    if campaign.complete_for_word("OPEN").is_empty() or not campaign.is_complete("market"):
        return false
    # Regression: completing chapters out of order must not skip the first unfinished one.
    campaign.complete_for_word("KEY")
    if not campaign.is_complete("storage") or str(campaign.current().get("id", "")) != "garden":
        return false
    for word in STORY_WORDS:
        campaign.complete_for_word(word)
    # Regression: the finale used to require the TOGETHER chapter, which can only be
    # played *after* the finale unlocks (circular dependency, finale unreachable).
    if not campaign.finale_ready or campaign.finale_done or unlocked.size() != 1:
        return false
    if campaign.is_complete("unity"):
        return false
    var reward: Dictionary = campaign.complete_for_word("TOGETHER")
    if reward.is_empty() or not campaign.is_complete("unity"):
        return false
    campaign.complete_finale()
    if not (campaign.is_game_complete() and campaign.postgame_unlocked):
        return false
    # A save made while stuck behind the old deadlock heals itself on load.
    var healed: CampaignManager = preload("res://gameplay/campaign/campaign_manager.gd").new()
    var stuck := {"completed": {}, "finale_ready": false, "finale_done": false, "current_index": 11}
    for word in STORY_WORDS:
        for chapter in CampaignManager.CHAPTERS:
            if str(chapter["word"]) == word:
                stuck["completed"][str(chapter["id"])] = true
    healed.restore(stuck)
    return healed.finale_ready and not healed.finale_done and healed.current_index == CampaignManager.CHAPTERS.size() - 1
