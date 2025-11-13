local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropItemsFolder = ReplicatedStorage:FindFirstChild("DropItems")
local Workspace = game:GetService("Workspace")

-- Table untuk tracking Health yang sudah dihubungkan
local connectedHealths = {}

-- Fungsi untuk paksa semua BasePart di item agar visible dan bisa jatuh
local function forceVisibleAndPhysics(item)
    local foundBasePart = false
    if item:IsA("BasePart") then
        item.Anchored = false
        item.Transparency = 0
        item.CanCollide = true
        if item.Size.Magnitude == 0 then
            item.Size = Vector3.new(2,2,2)
            print("[DropItemOnDestroy] WARNING: BasePart size was 0, set to 2,2,2 for:", item:GetFullName())
        end
        foundBasePart = true
        print("[DropItemOnDestroy] Set BasePart:", item.Name, "Anchored:", item.Anchored, "Transparency:", item.Transparency, "CanCollide:", item.CanCollide, "Size:", tostring(item.Size))
    elseif item:IsA("Model") then
        local hasPart = false
        for _, part in item:GetDescendants() do
            if part:IsA("BasePart") then
                part.Anchored = false
                part.Transparency = 0
                part.CanCollide = true
                if part.Size.Magnitude == 0 then
                    part.Size = Vector3.new(2,2,2)
                    print("[DropItemOnDestroy] WARNING: Model BasePart size was 0, set to 2,2,2 for:", part:GetFullName())
                end
                hasPart = true
                print("[DropItemOnDestroy] Set Model BasePart:", part.Name, "Anchored:", part.Anchored, "Transparency:", part.Transparency, "CanCollide:", part.CanCollide, "Size:", tostring(part.Size))
            end
        end
        if not hasPart then
            print("[DropItemOnDestroy] WARNING: Model", item.Name, "has NO BasePart!")
        end
        foundBasePart = hasPart
    end
    return foundBasePart
end

-- Fungsi untuk log visual dan properti item drop
local function logDropVisual(item)
    local pos = nil
    if item:IsA("BasePart") then
        pos = item.Position
        print("[DropItemOnDestroy] VISUAL: BasePart", item.Name, "Pos:", tostring(pos), "Size:", tostring(item.Size), "Transparency:", item.Transparency, "Anchored:", item.Anchored, "CanCollide:", item.CanCollide)
        if pos.Y < 0 then
            print("[DropItemOnDestroy] WARNING: Item", item.Name, "drop di bawah Y=0, kemungkinan tertanam di Terrain!")
        elseif pos.Y < 5 then
            print("[DropItemOnDestroy] WARNING: Item", item.Name, "drop di bawah Y=5, kemungkinan tidak terlihat!")
        end
    elseif item:IsA("Model") then
        local pivot = item:GetPivot().Position
        print("[DropItemOnDestroy] VISUAL: Model", item.Name, "Pivot Pos:", tostring(pivot))
        if pivot.Y < 0 then
            print("[DropItemOnDestroy] WARNING: Model", item.Name, "drop di bawah Y=0, kemungkinan tertanam di Terrain!")
        elseif pivot.Y < 5 then
            print("[DropItemOnDestroy] WARNING: Model", item.Name, "drop di bawah Y=5, kemungkinan tidak terlihat!")
        end
        for _, part in item:GetDescendants() do
            if part:IsA("BasePart") then
                print("[DropItemOnDestroy] VISUAL: Model BasePart", part.Name, "Pos:", tostring(part.Position), "Size:", tostring(part.Size), "Transparency:", part.Transparency, "Anchored:", part.Anchored, "CanCollide:", part.CanCollide)
            end
        end
    end
end

-- Fungsi untuk spawn beberapa item di posisi tertentu dan membuatnya jatuh
local function dropItemAtPosition(position, itemName, itemObj, itemList, jumlahDrop)
    if DropItemsFolder then
        local itemsToDrop = {}

        -- Prioritas: DropItemList > ObjectValue > StringValue > random
        if itemList and itemList:IsA("Folder") then
            print("[DropItemOnDestroy] Found DropItemList folder:", itemList:GetFullName())
            print("[DropItemOnDestroy] DropItemList children count:", #itemList:GetChildren())
            -- Drop semua anak di folder, baik ObjectValue maupun langsung item
            for i, child in itemList:GetChildren() do
                print("[DropItemOnDestroy] DropItemList child #" .. tostring(i) .. ": " .. child.Name .. " | Type: " .. child.ClassName)
                local clonedItem = nil
                if child:IsA("ObjectValue") then
                    if child.Value then
                        print("[DropItemOnDestroy] Dropping ObjectValue:", child.Name, "->", child.Value.Name, "Type:", child.Value.ClassName)
                        -- Jika Value adalah Folder/Model, drop semua anaknya
                        if child.Value:IsA("Folder") or child.Value:IsA("Model") then
                            local subItems = child.Value:GetChildren()
                            print("[DropItemOnDestroy] ObjectValue.Value is Folder/Model, children count:", #subItems)
                            for j, subChild in subItems do
                                print("[DropItemOnDestroy] Sub-child #" .. tostring(j) .. ": " .. subChild.Name .. " | Type: " .. subChild.ClassName)
                                if subChild:IsA("BasePart") or subChild:IsA("Model") then
                                    local subClone = subChild:Clone()
                                    subClone.Parent = Workspace
                                    table.insert(itemsToDrop, {item = subClone, offsetIndex = #itemsToDrop + 1})
                                    print("[DropItemOnDestroy] Dropping sub-item from ObjectValue.Value:", subChild.Name, "Type:", subChild.ClassName)
                                else
                                    print("[DropItemOnDestroy] Sub-child", subChild.Name, "is not BasePart/Model, skip.")
                                end
                            end
                        elseif child.Value:IsA("BasePart") or child.Value:IsA("Model") then
                            clonedItem = child.Value:Clone()
                            clonedItem.Parent = Workspace
                            table.insert(itemsToDrop, {item = clonedItem, offsetIndex = #itemsToDrop + 1})
                        else
                            print("[DropItemOnDestroy] ObjectValue.Value", child.Value.Name, "is not Folder/Model/BasePart, skip.")
                        end
                    else
                        print("[DropItemOnDestroy] ObjectValue", child.Name, "Value is nil, skip.")
                    end
                elseif child:IsA("BasePart") or child:IsA("Model") then
                    clonedItem = child:Clone()
                    clonedItem.Parent = Workspace
                    table.insert(itemsToDrop, {item = clonedItem, offsetIndex = #itemsToDrop + 1})
                    print("[DropItemOnDestroy] Dropping direct item:", child.Name)
                else
                    print("[DropItemOnDestroy] Child", child.Name, "is not ObjectValue/BasePart/Model, skip.")
                end
            end
            if #itemsToDrop == 0 then
                print("[DropItemOnDestroy] DropItemList folder exists but no valid item found, fallback to random drop.")
            end
        elseif itemObj and itemObj:IsA("ObjectValue") then
            print("[DropItemOnDestroy] Found ObjectValue:", itemObj.Name, "Value:", itemObj.Value)
            if itemObj.Value then
                -- Jika Value adalah Folder/Model, drop semua anaknya
                if itemObj.Value:IsA("Folder") or itemObj.Value:IsA("Model") then
                    local subItems = itemObj.Value:GetChildren()
                    print("[DropItemOnDestroy] ObjectValue.Value is Folder/Model, children count:", #subItems)
                    for j, subChild in subItems do
                        print("[DropItemOnDestroy] Sub-child #" .. tostring(j) .. ": " .. subChild.Name .. " | Type: " .. subChild.ClassName)
                        if subChild:IsA("BasePart") or subChild:IsA("Model") then
                            local subClone = subChild:Clone()
                            subClone.Parent = Workspace
                            table.insert(itemsToDrop, {item = subClone, offsetIndex = #itemsToDrop + 1})
                            print("[DropItemOnDestroy] Dropping sub-item from ObjectValue.Value:", subChild.Name, "Type:", subChild.ClassName)
                        else
                            print("[DropItemOnDestroy] Sub-child", subChild.Name, "is not BasePart/Model, skip.")
                        end
                    end
                elseif itemObj.Value:IsA("BasePart") or itemObj.Value:IsA("Model") then
                    local jumlah = jumlahDrop or 1
                    for i = 1, jumlah do
                        local clonedItem = itemObj.Value:Clone()
                        clonedItem.Parent = Workspace
                        table.insert(itemsToDrop, {item = clonedItem, offsetIndex = #itemsToDrop + 1})
                    end
                else
                    print("[DropItemOnDestroy] ObjectValue.Value", itemObj.Value.Name, "is not Folder/Model/BasePart, skip.")
                end
            else
                print("[DropItemOnDestroy] ObjectValue exists but Value is nil, fallback to random drop.")
            end
        elseif itemName and typeof(itemName) == "string" and itemName ~= "" then
            local found = DropItemsFolder:FindFirstChild(itemName)
            print("[DropItemOnDestroy] Found StringValue:", itemName, "Found in DropItems:", found ~= nil)
            if found then
                local jumlah = jumlahDrop or 1
                for i = 1, jumlah do
                    local clonedItem = found:Clone()
                    clonedItem.Parent = Workspace
                    table.insert(itemsToDrop, {item = clonedItem, offsetIndex = #itemsToDrop + 1})
                end
            else
                print("[DropItemOnDestroy] StringValue exists but item not found, fallback to random drop.")
            end
        end

        -- Fallback random jika tidak ada pengaturan
        if #itemsToDrop == 0 then
            local allItems = {}
            for _, item in DropItemsFolder:GetChildren() do
                table.insert(allItems, item)
            end
            if #allItems > 0 then
                local jumlah = jumlahDrop or 1
                for i = 1, jumlah do
                    local randomIndex = math.random(1, #allItems)
                    print("[DropItemOnDestroy] Fallback random drop:", allItems[randomIndex].Name)
                    local clonedItem = allItems[randomIndex]:Clone()
                    clonedItem.Parent = Workspace
                    table.insert(itemsToDrop, {item = clonedItem, offsetIndex = #itemsToDrop + 1})
                end
            else
                print("[DropItemOnDestroy] No items available in DropItemsFolder!")
            end
        end

        -- Offset posisi drop agar tidak terlalu tinggi dan tidak bertumpuk
        local dropPos = position
        if dropPos.Y > 100 then
            dropPos = Vector3.new(dropPos.X, dropPos.Y - 20, dropPos.Z)
        end
        -- Pastikan dropPos.Y minimal 5 agar item tidak tertanam di Terrain
        if dropPos.Y < 5 then
            print("[DropItemOnDestroy] WARNING: DropPos.Y terlalu rendah ("..tostring(dropPos.Y).."), diangkat ke Y=5")
            dropPos = Vector3.new(dropPos.X, 5, dropPos.Z)
        end

        print("[DropItemOnDestroy] Drop item at position:", dropPos)
        print("[DropItemOnDestroy] Total items to drop:", #itemsToDrop)

        -- Spawn semua item yang ada di itemsToDrop
        for i, dropData in itemsToDrop do
            local itemToDrop = dropData.item
            local offsetIndex = dropData.offsetIndex
            -- Offset posisi X dan Z agar tidak bertumpuk
            local offsetX = (offsetIndex - 1) * 2 - (#itemsToDrop - 1)
            local offsetZ = math.random(-2,2)
            local itemDropPos = Vector3.new(dropPos.X + offsetX, dropPos.Y, dropPos.Z + offsetZ)
            print("[DropItemOnDestroy] Spawning item #" .. tostring(i) .. ": " .. itemToDrop.Name .. " | Parent now: " .. tostring(itemToDrop.Parent) .. " | Pos: " .. tostring(itemDropPos))
            
            -- Paksa semua BasePart di item agar visible dan bisa jatuh
            local hasBasePart = forceVisibleAndPhysics(itemToDrop)
            if not hasBasePart then
                print("[DropItemOnDestroy] WARNING: Item", itemToDrop.Name, "has NO BasePart, cannot drop physics!")
            end

            if itemToDrop:IsA("Model") then
                itemToDrop:PivotTo(CFrame.new(itemDropPos))
                -- Cari part utama untuk physics
                local mainPart = nil
                for _, part in itemToDrop:GetDescendants() do
                    if part:IsA("BasePart") then
                        mainPart = part
                        break
                    end
                end
                if mainPart then
                    mainPart.Anchored = false
                    mainPart.AssemblyLinearVelocity = Vector3.new(math.random(-2,2), math.random(10,15), math.random(-2,2))
                end
            elseif itemToDrop:IsA("BasePart") then
                itemToDrop.Position = itemDropPos
                itemToDrop.Anchored = false
                itemToDrop.AssemblyLinearVelocity = Vector3.new(math.random(-2,2), math.random(10,15), math.random(-2,2))
            end

            -- Log visual dan properti item drop
            logDropVisual(itemToDrop)

            -- Event untuk log jika item dihapus dari Workspace
            itemToDrop.AncestryChanged:Connect(function(child, parent)
                if parent == nil then
                    print("[DropItemOnDestroy] WARNING: Item", itemToDrop.Name, "dihapus dari Workspace!")
                end
            end)
        end

        -- Log akhir: cek semua item yang benar-benar ada di Workspace
        local workspaceItems = {}
        for _, item in Workspace:GetChildren() do
            table.insert(workspaceItems, item.Name)
        end
        print("[DropItemOnDestroy] Workspace items after drop:", table.concat(workspaceItems, ", "))
    end
end

-- Fungsi saat objek hancur
local function onDestroyed(obj)
    local pos = nil
    if obj:IsA("Model") then
        pos = obj:GetPivot().Position
        -- Jika terlalu tinggi, offset ke bawah
        if pos.Y > 100 then
            pos = Vector3.new(pos.X, pos.Y - 20, pos.Z)
        end
    elseif obj:IsA("BasePart") then
        pos = obj.Position
        if pos.Y > 100 then
            pos = Vector3.new(pos.X, pos.Y - 20, pos.Z)
        end
    end

    -- Cek pengaturan drop item pada Model
    local itemName = nil
    local itemObj = nil
    local itemList = nil
    local jumlahDrop = 1 -- Default 1, bisa diubah sesuai kebutuhan

    if obj:IsA("Model") then
        local dropItemListFolder = obj:FindFirstChild("DropItemList")
        if dropItemListFolder and dropItemListFolder:IsA("Folder") then
            itemList = dropItemListFolder
            -- Jangan set jumlahDrop ke jumlah anak, biarkan drop semua item di folder
            jumlahDrop = 1 -- Tidak digunakan untuk folder, drop semua anak
        end
        local dropItemNameValue = obj:FindFirstChild("DropItemName")
        if dropItemNameValue and dropItemNameValue:IsA("StringValue") then
            itemName = dropItemNameValue.Value
            local jumlahValue = obj:FindFirstChild("DropItemAmount")
            if jumlahValue and jumlahValue:IsA("IntValue") then
                jumlahDrop = jumlahValue.Value
            end
        end
        local dropItemObjValue = obj:FindFirstChild("DropItem")
        if dropItemObjValue and dropItemObjValue:IsA("ObjectValue") then
            itemObj = dropItemObjValue
            local jumlahValue = obj:FindFirstChild("DropItemAmount")
            if jumlahValue and jumlahValue:IsA("IntValue") then
                jumlahDrop = jumlahValue.Value
            end
        end
    end

    if pos then
        dropItemAtPosition(pos, itemName, itemObj, itemList, jumlahDrop)
    else
        print("[DropItemOnDestroy] Failed to get position for destroyed object:", obj:GetFullName())
    end
end

-- Fungsi untuk menghubungkan event Health pada satu Health
local function connectHealthEvent(obj, healthObj)
    if not connectedHealths[healthObj] then
        connectedHealths[healthObj] = true
        healthObj.Changed:Connect(function(newValue)
            if newValue <= 0 then
                print("[DropItemOnDestroy] Health reached 0 for:", obj:GetFullName())
                onDestroyed(obj)
            end
        end)
    end
end

-- Fungsi untuk menghubungkan event Health pada semua objek di container
local function connectHealthMonitor(container)
    for _, obj in container:GetChildren() do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local healthObj = obj:FindFirstChild("Health")
            if healthObj and healthObj:IsA("IntValue") then
                connectHealthEvent(obj, healthObj)
            end
        end
        -- Rekursif untuk folder/model
        if obj:IsA("Folder") or obj:IsA("Model") then
            connectHealthMonitor(obj)
            -- Tambahkan listener ChildAdded pada setiap Folder/Model
            obj.ChildAdded:Connect(function(child)
                -- Jika child adalah Health, langsung hubungkan eventnya
                if child:IsA("IntValue") and child.Name == "Health" then
                    connectHealthEvent(obj, child)
                end
                -- Jika child adalah Folder/Model, rekursif
                if child:IsA("Folder") or child:IsA("Model") then
                    connectHealthMonitor(child)
                end
            end)
        end
    end
end

-- Inisialisasi: monitor semua objek di Workspace
connectHealthMonitor(Workspace)

-- Jika ada objek baru ditambahkan ke Workspace, monitor juga
Workspace.ChildAdded:Connect(function(child)
    connectHealthMonitor(child)
end)
