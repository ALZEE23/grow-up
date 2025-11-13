local DataStoreService = game:GetService("DataStoreService")
local inventoryStore = DataStoreService:GetDataStore("PlayerInventory")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory") -- RemoteEvent

local inventories = {}
local InventoryManager = {}

-- 🧩 Load data player saat masuk
function InventoryManager.InitPlayer(player)
	local success, savedData = pcall(function()
		return inventoryStore:GetAsync(player.UserId)
	end)

	if success and savedData then
		inventories[player.UserId] = savedData
		UpdateInventoryEvent:FireClient(player, inventories[player.UserId])
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

return InventoryManager
