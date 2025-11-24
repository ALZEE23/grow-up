local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PickupDropItem = ReplicatedStorage:FindFirstChild("PickupDropItem")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local InventoryManager = require(game.ServerScriptService.Server.InventoryManager)
local DropItemsFolder = ReplicatedStorage:WaitForChild("DropItems")

-- PERBAIKAN: Function to check if item is valid pickup
local function isValidPickupItem(part)
    -- Skip if part is nil
    if not part or not part:IsA("BasePart") then return false end
    
    -- Skip terrain
    if part:IsA("Terrain") then return false end
    
    -- PERBAIKAN: Skip if item has pickup delay
    if part:FindFirstChild("PickupDelay") then
        return false -- Item not ready for pickup yet
    end
    
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
    
    -- Only allow items that exist in DropItems folder
    local itemExists = DropItemsFolder:FindFirstChild(part.Name)
    if not itemExists then
        return false -- Item not in DropItems catalog
    end
    
    -- Skip if part has "Character" in its ancestry (extra safety)
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
                
                print("[DropItemPickup] ==========PICKUP START==========")
                print("[DropItemPickup] Player", player.Name, "touched item:", part.Name)
                
                -- Kirim event ke client untuk pickup
                PickupDropItem:FireClient(player, part.Name)
                print("[DropItemPickup] Sent pickup event to client")
                
                InventoryManager.AddItem(player, part.Name)
                print("[DropItemPickup] Added to inventory")
                
                -- Check current inventory
                local currentInv = InventoryManager.GetInventory(player)
                print("[DropItemPickup] Current inventory after pickup:", currentInv)
                
                -- Hapus item dari Workspace
                part:Destroy()
                print("[DropItemPickup] Player", player.Name, "picked up", part.Name)
                print("[DropItemPickup] ==========PICKUP END==========")
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