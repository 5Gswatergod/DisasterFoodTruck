local RS = game:GetService("ReplicatedStorage")

local Remotes = RS:FindFirstChild("Remotes")
if not Remotes or not Remotes:IsA("Folder") then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = RS
end

local function ensure(name, className)
    local obj = Remotes:FindFirstChild(name)
    if obj and obj.ClassName ~= className then obj:Destroy(); obj = nil end
    if not obj then
        obj = Instance.new(className)
        obj.Name = name
        obj.Parent = Remotes
    end
    return obj
end

ensure("MatchState", "RemoteEvent")
ensure("SubmitOrder", "RemoteEvent")
ensure("ShakeCam", "RemoteEvent")
ensure("PurchaseItem", "RemoteEvent")
ensure("PreauthPurchase", "RemoteFunction")

print("[InitRemotes] Remotes ready:", table.concat((function()
    local t = {}
    for _,c in ipairs(Remotes:GetChildren()) do table.insert(t, c.Name.."("..c.ClassName..")") end
    return t
end)(), ", "))