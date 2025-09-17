local RS = game:GetService("ReplicatedStorage")
local Remotes = require(RS:WaitForChild("Shared"):WaitForChild("RemotesIndex"))
print("[RemotesBootstrap] ready:", Remotes.MatchState.ClassName, Remotes.SubmitOrder.ClassName)