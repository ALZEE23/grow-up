local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players") -- TAMBAH INI
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
    print("[InventoryManager] GetInventory request from", player.Name, "Items:", inventory)
    UpdateInventoryEvent:FireClient(player, inventory)
    print("[InventoryManager] Sent current inventory to", player.Name, "Count:", #inventory)
end)

-- 🧩 Load data player saat masuk
function InventoryManager.InitPlayer(player)
    print("[InventoryManager] InitPlayer called for", player.Name)
    
    local success, savedData = pcall(function()
        return inventoryStore:GetAsync(player.UserId)
    end)

    if success and savedData then
        print("[InventoryManager] Found saved data:", savedData)
        inventories[player.UserId] = savedData
        UpdateInventoryEvent:FireClient(player, inventories[player.UserId])
        print("[InventoryManager] Loaded inventory for", player.Name, "Items:", table.concat(savedData, ", "))
    else
        print("[InventoryManager] No saved data, creating new inventory")
        inventories[player.UserId] = {}
        UpdateInventoryEvent:FireClient(player, {})
        print("[InventoryManager] Created new inventory for", player.Name)
    end
end

-- 📤 Send current inventory to player (for respawn)
function InventoryManager.SendCurrentInventory(player)
    local inventory = inventories[player.UserId] or {}
    print("[InventoryManager] SendCurrentInventory to", player.Name, "Items:", inventory)
    UpdateInventoryEvent:FireClient(player, inventory)
end

-- 🪄 Tambahkan item ke inventory
function InventoryManager.AddItem(player, itemName)
    print("[InventoryManager] AddItem called for", player.Name, "item:", itemName)
    
    local inv = inventories[player.UserId]
    if not inv then
        print("[InventoryManager] Player inventory not found, creating new one")
        inv = {}
        inventories[player.UserId] = inv
    end
    
    print("[InventoryManager] Current inventory before add:", inv)
    table.insert(inv, itemName)
    print("[InventoryManager] Current inventory after add:", inv)
    
    UpdateInventoryEvent:FireClient(player, inventories[player.UserId])
    print("[InventoryManager] Added", itemName, "for", player.Name, "Total items:", #inv)
end

-- 📦 Ambil data inventory player
function InventoryManager.GetInventory(player)
    local inventory = inventories[player.UserId] or {}
    print("[InventoryManager] GetInventory for", player.Name, "returning:", inventory)
    return inventory
end

-- 💾 Simpan data ke DataStore (biasanya saat PlayerRemoving)
function InventoryManager.SavePlayerData(player)
    local data = inventories[player.UserId]
    if not data then 
        print("[InventoryManager] No data to save for", player.Name)
        return 
    end

    print("[InventoryManager] Saving data for", player.Name, ":", data)

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
    print("[InventoryManager] Removed player data for", player.Name)
end

-- PERBAIKAN: Handle player events di InventoryManager
Players.PlayerAdded:Connect(function(player)
    print("[InventoryManager] Player joined:", player.Name)
    InventoryManager.InitPlayer(player)
    
    -- Handle respawn - send inventory when character spawns
    player.CharacterAdded:Connect(function(character)
        print("[InventoryManager] Character spawned for", player.Name)
        
        -- Multiple attempts dengan timing yang berbeda
        local attempts = {2, 4, 6} -- Try at 2s, 4s, 6s
        
        for i, delay in ipairs(attempts) do
            task.spawn(function()
                task.wait(delay)
                
                if player.Parent and character.Parent then -- Player still connected
                    print("[InventoryManager] Attempt", i, "- Sending inventory to", player.Name, "after", delay, "seconds")
                    InventoryManager.SendCurrentInventory(player)
                end
            end)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    print("[InventoryManager] Player leaving:", player.Name)
    InventoryManager.RemovePlayer(player)
end)

return InventoryManager
