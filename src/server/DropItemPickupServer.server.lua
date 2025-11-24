local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PickupDropItem = ReplicatedStorage:FindFirstChild("PickupDropItem")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local InventoryManager = require(game.ServerScriptService.Server.InventoryManager)
local DropItemsFolder = ReplicatedStorage:WaitForChild("DropItems")

-- PERBAIKAN: Track players yang sudah di-init
local initializedPlayers = {}

Players.PlayerAdded:Connect(function(player)
    if not initializedPlayers[player.UserId] then
        InventoryManager.InitPlayer(player)
        initializedPlayers[player.UserId] = true
        print("[DropItemPickup] Initialized player:", player.Name)
    end
    
    -- PERBAIKAN: Handle respawn - kirim ulang inventory saat character spawn
    player.CharacterAdded:Connect(function(character)
        -- Wait a bit for character to fully load
        task.wait(1)
        
        -- Send current inventory to client
        local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory")
        local inventory = InventoryManager.GetInventory(player)
        UpdateInventoryEvent:FireClient(player, inventory)
        print("[DropItemPickup] Sent inventory to", player.Name, "after respawn. Items:", #inventory)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    InventoryManager.RemovePlayer(player)
    initializedPlayers[player.UserId] = nil
end)

-- PERBAIKAN: Function to check if item is valid pickup
local function isValidPickupItem(part)
    -- Skip if part is nil
    if not part or not part:IsA("BasePart") then return false end
    
    -- Skip terrain
    if part:IsA("Terrain") then return false end
    
    -- Skip if part belongs to a player character
    local character = part.Parent
    if character and character:FindFirstChild("Humanoid") then
        local player = game.Players:GetPlayerFromCharacter(character)
        if player then
            return false -- This is a player body part
        end
    end
    
    -- Skip if part is child of a player character
    local rootParent = part.Parent
    while rootParent and rootParent ~= Workspace do
        if rootParent:FindFirstChild("Humanoid") then
            local player = game.Players:GetPlayerFromCharacter(rootParent)
            if player then
                return false -- This part belongs to a player
            end
        end
        rootParent = rootParent.Parent
    end
    
    -- PERBAIKAN: Only allow items that exist in DropItems folder
    local itemExists = DropItemsFolder:FindFirstChild(part.Name)
    if not itemExists then
        return false -- Item not in DropItems catalog
    end
    
    -- PERBAIKAN: Skip if part has "Character" in its ancestry (extra safety)
    local fullName = part:GetFullName()
    if string.find(string.lower(fullName), "character") then
        return false
    end
    
    return true -- Valid pickup item
end

-- Fungsi untuk cek apakah part disentuh oleh player
local function setupPickup(part)
    if not isValidPickupItem(part) then return end
    
    part.Touched:Connect(function(hit)
        local character = hit.Parent
        if character and character:FindFirstChild("Humanoid") then
            local player = game.Players:GetPlayerFromCharacter(character)
            if player then
                -- Double check the part is still valid (not a player body part)
                if not isValidPickupItem(part) then return end
                
                -- Kirim event ke client untuk pickup
                PickupDropItem:FireClient(player, part.Name)
                InventoryManager.AddItem(player, part.Name)
                -- Hapus item dari Workspace
                part:Destroy()
                print("[DropItemPickup] Player", player.Name, "picked up", part.Name)
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