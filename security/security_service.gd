extends Node
class_name SecurityService

var seen_transactions: Dictionary = {}
var suspicious_events: Array = []

func validate_transaction(transaction_id: String, amount: int, source: String) -> bool:
    if transaction_id.is_empty() or seen_transactions.has(transaction_id) or amount < 0:
        suspicious_events.append({"type": "invalid_transaction", "id": transaction_id, "source": source})
        return false
    seen_transactions[transaction_id] = {"amount": amount, "source": source, "time": Time.get_unix_time_from_system()}
    return true

func validate_reward(reward_id: String, source: String) -> bool:
    return validate_transaction(reward_id, 0, source)

func snapshot() -> Dictionary:
    return {"transactions": seen_transactions.duplicate(true)}

func restore(value: Dictionary) -> void:
    seen_transactions = value.get("transactions", {}).duplicate(true)
