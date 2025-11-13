local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PickupDropItem = ReplicatedStorage:FindFirstChild("PickupDropItem")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local InventoryManager = require(game.ServerScriptService.Server.InventoryManager)

Players.PlayerAdded:Connect(function(player)
	InventoryManager.InitPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	InventoryManager.RemovePlayer(player)
end)

-- Fungsi untuk cek apakah part disentuh oleh player
local function setupPickup(part)
	if not part:IsA("BasePart") then return end
	if part:IsA("Terrain") then return end
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		if character and character:FindFirstChild("Humanoid") then
			local player = game.Players:GetPlayerFromCharacter(character)
			if player then
				-- Kirim event ke client untuk pickup
				PickupDropItem:FireClient(player, part.Name)
				InventoryManager.AddItem(player, part.Name)
				-- Hapus item dari Workspace
				part:Destroy()
			end
		end
	end)
end

-- Monitor item drop baru di Workspace
Workspace.ChildAdded:Connect(function(child)
	if child:IsA("BasePart") then
		setupPickup(child)
	elseif child:IsA("Model") then
		for _, part in child:GetDescendants() do
			if part:IsA("BasePart") then
				setupPickup(part)
			end
		end
	end
end)

-- Inisialisasi untuk item yang sudah ada di Workspace
for _, child in Workspace:GetChildren() do
	if child:IsA("BasePart") then
		setupPickup(child)
	elseif child:IsA("Model") then
		for _, part in child:GetDescendants() do
			if part:IsA("BasePart") then
				setupPickup(part)
			end
		end
	end
end