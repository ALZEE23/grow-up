local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipItemEvent = ReplicatedStorage:WaitForChild("EquipItem")
local DropItemsFolder = ReplicatedStorage:WaitForChild("DropItems")

EquipItemEvent.OnServerEvent:Connect(function(player, itemName)
    print("[EquipItemHandler] Equipping", itemName, "for", player.Name)

    local character = player.Character
    if not character then return end

    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if not rightHand then
        warn("[EquipItemHandler] Right hand not found for", player.Name)
        return
    end

    -- Hapus item lama kalau ada
    local existing = character:FindFirstChild("EquippedItem")
    if existing then
        existing:Destroy()
    end

    -- PERBAIKAN: Cari item di DropItems, FoodItems, dan BoosterItems
    local itemModel = DropItemsFolder:FindFirstChild(itemName)
    if not itemModel then
        -- Coba cari di FoodItems subfolder
        local foodItemsFolder = DropItemsFolder:FindFirstChild("FoodItems")
        if foodItemsFolder then
            itemModel = foodItemsFolder:FindFirstChild(itemName)
        end
    end
    if not itemModel then
        -- Coba cari di BoosterItems subfolder
        local boosterItemsFolder = DropItemsFolder:FindFirstChild("BoosterItems")
        if boosterItemsFolder then
            itemModel = boosterItemsFolder:FindFirstChild(itemName)
        end
    end
    
    if not itemModel then
        warn("[EquipItemHandler] Item model not found:", itemName)
        return
    end

    local clone = itemModel:Clone()
    clone.Name = "EquippedItem"
    clone.Parent = character

    -- Pastikan tidak jatuh / tembus tanah
    if clone:IsA("BasePart") then
        clone.Anchored = false
        clone.CanCollide = false
    elseif clone:IsA("Model") then
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = false
                part.CanCollide = false
            end
        end
    end

    -- Ambil bagian utama
    local primaryPart = clone:IsA("BasePart") and clone or clone:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        warn("[EquipItemHandler] No BasePart in", itemName)
        return
    end

    -- Posisikan dan weld ke tangan
    primaryPart.CFrame = rightHand.CFrame * CFrame.new(0, 0, -0.5)

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = primaryPart
    weld.Part1 = rightHand
    weld.Parent = primaryPart

    print("[EquipItemHandler] Successfully equipped", itemName, "for", player.Name)
end)
