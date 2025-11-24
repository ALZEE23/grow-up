local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventoryGui = playerGui:WaitForChild("Inventory")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropItemsFolder = ReplicatedStorage:WaitForChild("DropItems")

local UpdateInventoryEvent = ReplicatedStorage:WaitForChild("UpdateInventory") -- RemoteEvent dari server

-- Track connections untuk hotbar slots
local hotbarConnections = {}

UpdateInventoryEvent.OnClientEvent:Connect(function(inventoryData)
    print("[Client] Updating UI Inventory...")

    local hotbar = inventoryGui:WaitForChild("Hotbar")
    local inventoryInside = inventoryGui:WaitForChild("Inventory")
    local inventoryItemScroll = inventoryInside:WaitForChild("ItemsScroll")
    local slotTemplate = ReplicatedStorage.UI:WaitForChild("SlotTemplate")

    -- 💡 Kelompokkan item yang sama jadi count
    local itemCounts = {}
    for _, itemName in ipairs(inventoryData) do
        itemCounts[itemName] = (itemCounts[itemName] or 0) + 1
    end

    -- Convert jadi list untuk iterasi urutan slot
    local uniqueItems = {}
    for name, count in pairs(itemCounts) do
        table.insert(uniqueItems, { name = name, count = count })
    end
    
    -- PERBAIKAN: Disconnect semua event lama di hotbar
    for i = 1, 10 do
        if hotbarConnections[i] then
            hotbarConnections[i]:Disconnect()
            hotbarConnections[i] = nil
        end
    end
    
    -- Clear hotbar slots first
    for i = 1, 10 do -- Assuming 10 hotbar slots
        local slot = hotbar:FindFirstChild("Slot" .. i)
        if slot then
            local viewport = slot:FindFirstChild("ViewportFrame")
            if viewport then
                -- Clear viewport
                for _, obj in ipairs(viewport:GetChildren()) do
                    if not obj:IsA("UIStroke") and not obj:IsA("UICorner") then
                        obj:Destroy()
                    end
                end
            end
            
            -- Clear count label
            local countLabel = slot:FindFirstChild("ItemCount")
            if countLabel then
                countLabel.Text = ""
            end
        end
    end
    
    -- Update hotbar with current inventory
    for i, itemInfo in ipairs(uniqueItems) do
        local slot = hotbar:FindFirstChild("Slot" .. i)
        if slot then
            local viewport = slot:WaitForChild("ViewportFrame")

            -- Hapus isi viewport sebelumnya (sudah dilakukan di atas, tapi untuk safety)
            for _, obj in ipairs(viewport:GetChildren()) do
                if not obj:IsA("UIStroke") and not obj:IsA("UICorner") then
                    obj:Destroy()
                end
            end

            -- Ambil model dari folder DropItems
            local model = DropItemsFolder:FindFirstChild(itemInfo.name)
            if model then
                model = model:Clone()
                model.Parent = viewport

                -- Kamera viewport
                local cam = Instance.new("Camera")
                cam.CFrame = CFrame.new(Vector3.new(0, 0, 6), Vector3.new(0, 0, 0))
                cam.Parent = viewport
                viewport.CurrentCamera = cam

                model:PivotTo(CFrame.new(0, 0, 0))
                viewport.BackgroundTransparency = 1
                viewport.Ambient = Color3.new(1, 1, 1)
                viewport.LightDirection = Vector3.new(0, -1, -1)
            else
                warn("[InventoryUI] Item model not found:", itemInfo.name)
            end

            -- 🔢 Tambahkan label jumlah item (count)
            local countLabel = slot:FindFirstChild("ItemCount")
            if countLabel then
                countLabel.Text = itemInfo.count .. "x"
            end
            
            local EquipItemEvent = ReplicatedStorage:WaitForChild("EquipItem")

            -- PERBAIKAN: Buat event click baru dengan data terbaru
            local currentItemName = itemInfo.name -- Capture current item name
            hotbarConnections[i] = slot.MouseButton1Click:Connect(function()
                print("Hotbar slot", i, "clicked - equipping:", currentItemName)
                EquipItemEvent:FireServer(currentItemName)
            end)
        end
    end
    
    -- Bersihkan inventory lama
    for _, child in ipairs(inventoryItemScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    for name, count in pairs(itemCounts) do
        local slot = slotTemplate:Clone()
        slot.Name = name .. "_Slot"
        slot.Parent = inventoryItemScroll

        local viewport = slot:WaitForChild("ViewportFrame")

        -- Bersihkan viewport
        for _, obj in ipairs(viewport:GetChildren()) do
            if not obj:IsA("UIStroke") and not obj:IsA("UICorner") then
                obj:Destroy()
            end
        end

        -- Ambil model dari folder DropItems
        local model = DropItemsFolder:FindFirstChild(name)
        if model then
            model = model:Clone()
            model.Parent = viewport

            local cam = Instance.new("Camera")
            cam.CFrame = CFrame.new(Vector3.new(0, 0, 6), Vector3.new(0, 0, 0))
            cam.Parent = viewport
            viewport.CurrentCamera = cam

            model:PivotTo(CFrame.new(0, 0, 0))
            viewport.BackgroundTransparency = 1
            viewport.Ambient = Color3.new(1, 1, 1)
            viewport.LightDirection = Vector3.new(0, -1, -1)
        else
            warn("[InventoryUI] Item model not found:", name)
        end

        -- 🔢 Tambahkan label jumlah item (count)
        local countLabel = slot:FindFirstChild("ItemCount")
        if countLabel then
            countLabel.Text = count .. "x"
        end
        
        local nameLabel = slot:FindFirstChild("ItemName")
        if nameLabel then
            nameLabel.Text = name
        end
        
        local EquipItemEvent = ReplicatedStorage:WaitForChild("EquipItem")
        
        -- 🖱️ Event click untuk inventory (ini sudah benar karena slot baru)
        local currentItemName = name -- Capture current item name
        slot.MouseButton1Click:Connect(function()
            print("Inventory item clicked:", currentItemName)
            EquipItemEvent:FireServer(currentItemName)
        end)
    end
end)
