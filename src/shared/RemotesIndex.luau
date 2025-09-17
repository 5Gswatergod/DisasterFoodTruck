local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = RS:FindFirstChild("Remotes")
if not Remotes then
	if RunService:IsServer() then
		Remotes = Instance.new("Folder")
		Remotes.Name = "Remotes"
		Remotes.Parent = RS
	else
		Remotes = RS:WaitForChild("Remotes")
	end
end

local function ensure(name, className)
	local obj = Remotes:FindFirstChild(name)
	if obj and obj.ClassName ~= className then
		if RunService:IsServer() then obj:Destroy(); obj = nil end
	end
	if not obj then
		if RunService:IsServer() then
			obj = Instance.new(className); obj.Name = name; obj.Parent = Remotes
		else
			obj = Remotes:WaitForChild(name)
		end
	end
	return obj
end

local M = { Folder = Remotes }
M.MatchState      = ensure("MatchState", "RemoteEvent")
M.SubmitOrder     = ensure("SubmitOrder", "RemoteEvent")
M.ShakeCam        = ensure("ShakeCam", "RemoteEvent")
M.PurchaseItem    = ensure("PurchaseItem", "RemoteEvent")
M.PreauthPurchase = ensure("PreauthPurchase", "RemoteFunction")
M.CookStep        = ensure("CookStep", "RemoteFunction")
M.Interact        = ensure("Interact", "RemoteEvent")
M.StationRF       = ensure("StationRF", "RemoteFunction")
M.StationNet      = ensure("StationNet", "RemoteEvent")

if RunService:IsServer() then
	print("[RemotesIndex] server initialized →", M.MatchState.Name, M.SubmitOrder.Name)
end
return M