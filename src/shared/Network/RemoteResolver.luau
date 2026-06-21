--!strict

local RemoteResolver = {}

export type PathEntry = {
	Name: string,
	ErrorMessage: string,
}

function RemoteResolver.waitForPath(root: Instance, pathEntries: { PathEntry }, timeout: number): Instance?
	local current: Instance? = root

	for _, pathEntry in ipairs(pathEntries) do
		if not current then
			return nil
		end

		local nextInstance = current:WaitForChild(pathEntry.Name, timeout)

		if not nextInstance then
			warn(pathEntry.ErrorMessage)
			return nil
		end

		current = nextInstance
	end

	return current
end

function RemoteResolver.waitForNamedChildren(
	parent: Instance,
	childNames: { string },
	timeout: number,
	missingChildPrefix: string
): { [string]: Instance }?
	local resolvedChildren: { [string]: Instance } = {}

	for _, childName in ipairs(childNames) do
		local child = parent:WaitForChild(childName, timeout)

		if not child then
			warn(string.format("%s '%s' was not found", missingChildPrefix, childName))
			return nil
		end

		resolvedChildren[childName] = child
	end

	return resolvedChildren
end

return RemoteResolver
