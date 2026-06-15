local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local blacksmithConstants = require(sharedFolder:WaitForChild("BlacksmithConstants") :: ModuleScript)

local GoldTester = {}

local started = false
local addTestGoldRemote = nil
local onGoldAdded = nil

local function resolveRemote()
	local remotesFolder = ReplicatedStorage:WaitForChild(blacksmithConstants.REMOTE_FOLDER_NAME, 10)

	if not remotesFolder then
		return false
	end

	local blacksmithFolder = remotesFolder:WaitForChild(blacksmithConstants.BLACKSMITH_REMOTE_FOLDER_NAME, 10)

	if not blacksmithFolder then
		return false
	end

	addTestGoldRemote = blacksmithFolder:WaitForChild(blacksmithConstants.ADD_TEST_GOLD_REMOTE_NAME, 10)
	return addTestGoldRemote ~= nil
end

local function handleInputBegan(input, gameProcessedEvent)
	if gameProcessedEvent or input.KeyCode ~= Enum.KeyCode.X or not addTestGoldRemote then
		return
	end

	local success, payload = pcall(function()
		return addTestGoldRemote:InvokeServer()
	end)

	if not success or not payload or payload.success ~= true then
		return
	end

	if onGoldAdded then
		onGoldAdded(payload)
	end

	print(string.format("GoldTester added %d Gold", blacksmithConstants.TEST_GOLD_AMOUNT))
end

function GoldTester.start(callback)
	if started or not RunService:IsStudio() then
		return
	end

	started = true
	onGoldAdded = callback

	if not resolveRemote() then
		warn("GoldTester remote was not found")
		return
	end

	UserInputService.InputBegan:Connect(handleInputBegan)
end

return GoldTester
