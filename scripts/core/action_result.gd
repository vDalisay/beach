class_name ActionResult
extends RefCounted

enum Reason {
	NONE,
	CAPACITY,
	WRONG_STATE,
	MISSING_ID,
	BLOCKED_TARGET,
	INVALID_CATEGORY,
	DEFINITION_MISSING,
	INVALID_OWNER,
	INVALID_REFERENCE,
	DEFERRED,
	TOOL_REQUIRED,
}

var ok := false
var reason: Reason = Reason.NONE
var message := ""
var changed_ids: PackedStringArray = []
var receipt: Dictionary = {}


static func accepted(ids: PackedStringArray = [], action_receipt: Dictionary = {}) -> ActionResult:
	var result := ActionResult.new()
	result.ok = true
	result.changed_ids = ids
	result.receipt = action_receipt
	return result


static func rejected(failure_reason: Reason, failure_message: String) -> ActionResult:
	var result := ActionResult.new()
	result.reason = failure_reason
	result.message = failure_message
	return result
