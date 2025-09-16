local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensure(parent, className, name)
    local inst = parent:FindFirstChild(name)
    if not inst then
        inst = Instance.new(className)
        inst.Name = name
        inst.Parent = parent
    end
    return inst
end

local InitRemotes = {}

function InitRemotes.Setup()
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end

    ensure(remotesFolder, "RemoteEvent", "SubmitOrder")
    ensure(remotesFolder, "RemoteEvent", "PurchaseItem")
    ensure(remotesFolder, "RemoteFunction", "PreauthPurchase")
    ensure(remotesFolder, "RemoteEvent", "ShakeCam")
    ensure(remotesFolder, "RemoteEvent", "MatchState")
    ensure(remotesFolder, "RemoteEvent", "Ping")
end

return InitRemotes
