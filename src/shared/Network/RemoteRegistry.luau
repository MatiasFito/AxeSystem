--!strict

local RemoteRegistry = {}

export type ChildDefinition = {
	Name: string,
	ClassName: string,
}

function RemoteRegistry.getOrCreateChild(parent: Instance, name: string, className: string): Instance
	local child = parent:FindFirstChild(name)

	if child and child.ClassName == className then
		return child
	end

	if child then
		child:Destroy()
	end

	local newChild = Instance.new(className)
	newChild.Name = name
	newChild.Parent = parent
	return newChild
end

function RemoteRegistry.getOrCreatePath(root: Instance, definitions: { ChildDefinition }): Instance
	local current = root

	for _, definition in ipairs(definitions) do
		current = RemoteRegistry.getOrCreateChild(current, definition.Name, definition.ClassName)
	end

	return current
end

function RemoteRegistry.getOrCreateNamedChildren(
	parent: Instance,
	definitions: { ChildDefinition }
): { [string]: Instance }
	local resolvedChildren: { [string]: Instance } = {}

	for _, definition in ipairs(definitions) do
		resolvedChildren[definition.Name] =
			RemoteRegistry.getOrCreateChild(parent, definition.Name, definition.ClassName)
	end

	return resolvedChildren
end

return RemoteRegistry
