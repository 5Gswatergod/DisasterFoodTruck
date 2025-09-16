--!nonstrict
local RS = game:GetService("ReplicatedStorage")
local ShakeCam = RS:WaitForChild("Remotes"):WaitForChild("ShakeCam")
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera
local shaking, t0, dur = false, 0, 0
ShakeCam.OnClientEvent:Connect(function(cfg) shaking = true; t0 = time(); dur = (cfg and cfg.dur) or 1 end)
RunService.RenderStepped:Connect(function()
  if not shaking then return end
  if time() - t0 > dur then shaking = false return end
  cam.CFrame = cam.CFrame * CFrame.new(math.random(-2,2)/400, math.random(-2,2)/400, 0)
end)
