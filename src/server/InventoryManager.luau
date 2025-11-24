local DataStoreService = game:GetService("DataStoreService")
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory") -- RemoteEvent

-- Add this new RemoteEvent
local GetInventoryEvent = Instance.new("RemoteEvent")
GetInventoryEvent.Name = "GetInventory"
GetInventoryEvent.Parent = ReplicatedStorage

local inventories = {}
local InventoryManager = {}

-- Handle request for current inventory
GetInventoryEvent.OnServerEvent:Connect(function(player)
    local inventory = inventories[player.UserId] or {}
    UpdateInventoryEvent:FireClient(player, inventory)
    print("[InventoryManager] Sent current inventory to", player.Name, "Count:", #inventory)
end)

-- 🧩 Load data player saat masuk
function InventoryManager.InitPlayer(player)
	local success, savedData = pcall(function()
		return inventoryStore:GetAsync(player.UserId)
	end)

	if success and savedData then
		inventories[player.UserId] = savedData
		UpdateInventoryEvent:FireClient(player, inventories[player.UserId])
		-- Add this delay to ensure mixer UI is loaded
		task.wait(2)
		InventoryManager.SendInventoryToMixer(player)
		print("[InventoryManager] Loaded inventory for", player.Name, table.concat(savedData, ", "))
	else
		inventories[player.UserId] = {}
		print("[InventoryManager] Created new inventory for", player.Name)
	end
end

-- 🪄 Tambahkan item ke inventory
function InventoryManager.AddItem(player, itemName)
	local inv = inventories[player.UserId]
	if not inv then
		inv = {}
		inventories[player.UserId] = inv
	end
	
	table.insert(inv, itemName)
	UpdateInventoryEvent:FireClient(player, inventories[player.UserId])
	print("[InventoryManager] Added", itemName, "for", player.Name)
end

-- 📦 Ambil data inventory player
function InventoryManager.GetInventory(player)
	return inventories[player.UserId] or {}
end

-- 💾 Simpan data ke DataStore (biasanya saat PlayerRemoving)
function InventoryManager.SavePlayerData(player)
	local data = inventories[player.UserId]
	if not data then return end

	local success, err = pcall(function()
		inventoryStore:SetAsync(player.UserId, data)
	end)

	if success then
		print("[InventoryManager] Saved inventory for", player.Name)
	else
		warn("[InventoryManager] Failed to save data for", player.Name, err)
	end
end

-- 🧹 Hapus data lokal player saat keluar
function InventoryManager.RemovePlayer(player)
	InventoryManager.SavePlayerData(player)
	inventories[player.UserId] = nil
end

-- Send inventory to mixer
function InventoryManager.SendInventoryToMixer(player)
    local inventory = inventories[player.UserId] or {}
    UpdateInventoryEvent:FireClient(player, inventory)
    print("[InventoryManager] Sent inventory to mixer for", player.Name)
end

return InventoryManager
