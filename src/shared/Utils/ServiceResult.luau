--!strict

local ServiceResult = {}

local function applyExtraFields(payload: { [string]: any }, extraFields: { [string]: any }?)
	if typeof(extraFields) ~= "table" then
		return payload
	end

	for key, value in extraFields do
		if key ~= "success" and key ~= "state" then
			payload[key] = value
		end
	end

	return payload
end

function ServiceResult.success(state: any, extraFields: { [string]: any }?)
	local payload = {
		success = true,
		state = state,
	}

	return applyExtraFields(payload, extraFields)
end

function ServiceResult.failure(
	reason: string,
	getFailureMessage: (string) -> string,
	state: any?,
	extraFields: { [string]: any }?
)
	local payload = {
		success = false,
		reason = reason,
		message = getFailureMessage(reason),
	}

	if state ~= nil then
		payload.state = state
	end

	return applyExtraFields(payload, extraFields)
end

return ServiceResult
