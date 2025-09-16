local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function ensure(parent, className, name)
  local inst = parent:FindFirstChild(name)
  if not inst then inst = Instance.new(className); inst.Name=name; inst.Parent=parent end
  return inst
end
local InitRemotes = {}
function InitRemotes.Setup()
  local folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
  folder.Name="Remotes"; folder.Parent=ReplicatedStorage
  ensure(folder, "RemoteEvent", "SubmitOrder")
  ensure(folder, "RemoteEvent", "PurchaseItem")
  ensure(folder, "RemoteFunction", "PreauthPurchase")
  ensure(folder, "RemoteEvent", "ShakeCam")
  ensure(folder, "RemoteEvent", "MatchState")
  ensure(folder, "RemoteEvent", "Ping")
  ensure(folder, "RemoteFunction", "CookStep")
end
return InitRemotes
