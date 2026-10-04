-- Shared access to the game's remotes. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local DEFINITIONS = {
	Notify = "RemoteEvent", -- server -> client: (text, color?)
	DataChanged = "RemoteEvent", -- server -> client: (dataSnapshot)
	ChaseState = "RemoteEvent", -- server -> client: (isChased, ownerName?)
	Request = "RemoteFunction", -- client -> server: (action, arg) -> (ok, message)
	TreadmillRunning = "RemoteEvent", -- client -> server: (isRunning) held on the belt and running, or stepped off
	Tutorial = "RemoteEvent", -- server -> client: ("StepDone", stepName, extra) or ("Skipped")
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

for name in DEFINITIONS do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
