local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gp)
  if gp then return end
  if input.KeyCode == Enum.KeyCode.E then
    print("Interact key")
  end
end)
