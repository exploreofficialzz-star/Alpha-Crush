extends Node
class_name CustomizationCatalog

var styles := {
    "default": {"label": "Explorer", "body": "#31577d", "skin": "#c98d6b"},
    "sunrise": {"label": "Sunrise", "body": "#b16b42", "skin": "#8f5f49"},
    "forest": {"label": "Forest", "body": "#52754d", "skin": "#b97d62"},
    "coastal": {"label": "Coastal", "body": "#3e7890", "skin": "#d09b78"}
}

func get_style(id: String) -> Dictionary:
    return styles.get(id, styles["default"]).duplicate(true)
