--[[ezz]]--

local module = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- Default configuration
if not getgenv().ConfigColor then
    getgenv().ConfigColor = Color3.fromRGB(227, 227, 227)
end

function module:start()
    local start = {}
    local dragToggle, dragStart, startPos
    local camera = workspace.CurrentCamera
    
    -- Blur constants
    local BLUR_SIZE = Vector2.new(10, 10)
    local PART_SIZE = 0.01
    local PART_TRANSPARENCY = 1 - 1e-7
    local START_INTENSITY = 1
    
    -- Blur variables
    local PartsList = {}
    local BlursList = {}
    local BlurObjects = {}
    local BlurredGui = {}
    BlurredGui.__index = BlurredGui

    -- Main GUI Setup
    local UI = Instance.new("ScreenGui")
    local Main = Instance.new("Frame")
    local AcrylicBackground = Instance.new("Frame")
    local UICorner = Instance.new("UICorner")
    local Topbar = Instance.new("Frame")
    local TextContainer = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local UserContainer = Instance.new("Frame")
    local UserIcon = Instance.new("ImageLabel")
    local UserIconCorner = Instance.new("UICorner")
    local UserLabel = Instance.new("TextLabel")
    local UserContainerCorner = Instance.new("UICorner")
    local Info = Instance.new("Frame")
    local InfoCorner = Instance.new("UICorner")
    local Container = Instance.new("ScrollingFrame")
    local UIListLayout = Instance.new("UIListLayout")
    local UIPadding = Instance.new("UIPadding")

    -- Setup DepthOfField
    local BLUR_OBJ = Instance.new("DepthOfFieldEffect")
    BLUR_OBJ.FarIntensity = 0
    BLUR_OBJ.NearIntensity = START_INTENSITY
    BLUR_OBJ.FocusDistance = 0.25
    BLUR_OBJ.InFocusRadius = 0
    BLUR_OBJ.Parent = Lighting

    UI.Name = "EZ" .. tostring(math.random(5, 100000))
    UI.Parent = game.CoreGui
    UI.ZIndexBehavior = Enum.ZIndexBehavior.Global

    Main.Name = "Main"
    Main.Parent = UI
    Main.BackgroundTransparency = 1
    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.Size = UDim2.new(0, 645, 0, 435)

    -- Drag functionality
    local function updateInput(input)
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
            dragToggle = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragToggle = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragToggle then
                updateInput(input)
            end
        end
    end)

    -- Acrylic Background with Blur
    AcrylicBackground.Name = "AcrylicBackground"
    AcrylicBackground.Parent = Main
    AcrylicBackground.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
    AcrylicBackground.BackgroundTransparency = 0.45
    AcrylicBackground.Size = UDim2.new(1, 0, 1, 0)
    AcrylicBackground:SetAttribute("BlurIntensity", START_INTENSITY)
    CollectionService:AddTag(AcrylicBackground, "DropShadow")
    UICorner.Parent = AcrylicBackground

    -- Blur functions
    local function rayPlaneIntersect(planePos, planeNormal, rayOrigin, rayDirection)
        local n = planeNormal
        local d = rayDirection
        local v = rayOrigin - planePos
        local num = n.x*v.x + n.y*v.y + n.z*v.z
        local den = n.x*d.x + n.y*d.y + n.z*d.z
        local a = -num / den
        return rayOrigin + a * rayDirection, a
    end

    local function rebuildPartsList()
        PartsList = {}
        BlursList = {}
        for blurObj, part in pairs(BlurObjects) do
            table.insert(PartsList, part)
            table.insert(BlursList, blurObj)
        end
    end

    local function updateGui(blurObj)
        if not blurObj.Frame.Visible then
            blurObj.Part.Transparency = 1
            return
        end
        
        local frame = blurObj.Frame
        local part = blurObj.Part
        local mesh = blurObj.Mesh
        
        part.Transparency = PART_TRANSPARENCY
        
        local corner0 = frame.AbsolutePosition + BLUR_SIZE
        local corner1 = corner0 + frame.AbsoluteSize - BLUR_SIZE*2
        local ray0 = camera:ScreenPointToRay(corner0.X, corner0.Y, 1)
        local ray1 = camera:ScreenPointToRay(corner1.X, corner1.Y, 1)

        local planeOrigin = camera.CFrame.Position + camera.CFrame.LookVector * (0.05 - camera.NearPlaneZ)
        local planeNormal = camera.CFrame.LookVector
        local pos0 = rayPlaneIntersect(planeOrigin, planeNormal, ray0.Origin, ray0.Direction)
        local pos1 = rayPlaneIntersect(planeOrigin, planeNormal, ray1.Origin, ray1.Direction)

        local pos0 = camera.CFrame:PointToObjectSpace(pos0)
        local pos1 = camera.CFrame:PointToObjectSpace(pos1)

        local size = pos1 - pos0
        local center = (pos0 + pos1)/2

        mesh.Offset = center
        mesh.Scale = size / PART_SIZE
    end

    local function updateAll()
        BLUR_OBJ.NearIntensity = AcrylicBackground:GetAttribute("BlurIntensity")
        for i = 1, #BlursList do
            updateGui(BlursList[i])
        end
        local cframes = table.create(#BlursList, camera.CFrame)
        workspace:BulkMoveTo(PartsList, cframes, Enum.BulkMoveMode.FireCFrameChanged)
        BLUR_OBJ.FocusDistance = 0.25 - camera.NearPlaneZ
    end

    -- Setup blur effect
    do
        local blurPart = Instance.new("Part")
        blurPart.Size = Vector3.new(1, 1, 1) * PART_SIZE
        blurPart.Anchored = true
        blurPart.CanCollide = false
        blurPart.CanTouch = false
        blurPart.Material = Enum.Material.Glass
        blurPart.Transparency = PART_TRANSPARENCY
        blurPart.Parent = camera

        local mesh = Instance.new("BlockMesh")
        mesh.Parent = blurPart

        local new = setmetatable({
            Frame = AcrylicBackground,
            Part = blurPart,
            Mesh = mesh,
            IgnoreGuiInset = false
        }, BlurredGui)

        BlurObjects[new] = blurPart
        rebuildPartsList()

        RunService:BindToRenderStep("BlurUpdate", Enum.RenderPriority.Camera.Value + 1, function()
            blurPart.CFrame = camera.CFrame
            updateAll()
        end)
    end

    -- Topbar
    Topbar.Name = "Topbar"
    Topbar.Parent = Main
    Topbar.BackgroundTransparency = 1
    Topbar.Size = UDim2.new(0, 645, 0, 40)

    TextContainer.Name = "TextContainer"
    TextContainer.Parent = Topbar
    TextContainer.BackgroundTransparency = 1
    TextContainer.Position = UDim2.new(0.01705, 0, 0, 0)
    TextContainer.Size = UDim2.new(0, 528, 0, 40)

    Title.Name = "Title"
    Title.Parent = TextContainer
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(0, 475, 0, 40)
    Title.FontFace = Font.new("rbxassetid://12187365977")
    Title.Text = "<font color=\"rgb(227,227,227)\"> Murder Mystery 2 |</font> pre-build v1.0"
    Title.TextColor3 = Color3.fromRGB(160, 160, 160)
    Title.TextSize = 16
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.RichText = true

    -- User Container
    UserContainer.Name = "UserContainer"
    UserContainer.Parent = Main
    UserContainer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    UserContainer.BackgroundTransparency = 0.75
    UserContainer.AnchorPoint = Vector2.new(0, 1)
    UserContainer.Position = UDim2.new(0, 5, 1, -5)
    UserContainer.Size = UDim2.new(0, 635, 0, 27)
    UserContainerCorner.CornerRadius = UDim.new(0, 4)
    UserContainerCorner.Parent = UserContainer

    UserIcon.Name = "UserIcon"
    UserIcon.Parent = UserContainer
    UserIcon.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    UserIcon.BackgroundTransparency = 0.9
    UserIcon.AnchorPoint = Vector2.new(0, 0.5)
    UserIcon.Position = UDim2.new(0, 5, 0.5, 0)
    UserIcon.Size = UDim2.new(0, 23, 0, 23)
    UserIconCorner.Parent = UserIcon
    local thumbType = Enum.ThumbnailType.HeadShot
    local thumbSize = Enum.ThumbnailSize.Size60x60
    UserIcon.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, thumbType, thumbSize)

    UserLabel.Name = "UserLabel"
    UserLabel.Parent = UserContainer
    UserLabel.BackgroundTransparency = 1
    UserLabel.AnchorPoint = Vector2.new(0, 0.5)
    UserLabel.Position = UDim2.new(-0.01514, 45, 0.5, 0)
    UserLabel.Size = UDim2.new(0, 542, 0, 16)
    UserLabel.FontFace = Font.new("rbxassetid://12187365977")
    UserLabel.Text = "Welcome <b>" .. Players.LocalPlayer.Name .. "</b>! This script is still in beta, if you find any bugs feel free to report them"
    UserLabel.TextColor3 = Color3.fromRGB(228, 228, 228)
    UserLabel.TextSize = 14
    UserLabel.TextXAlignment = Enum.TextXAlignment.Left
    UserLabel.RichText = true

    -- Info Container
    Info.Name = "Info"
    Info.Parent = Main
    Info.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Info.BackgroundTransparency = 0.75
    Info.AnchorPoint = Vector2.new(0, 1)
    Info.Position = UDim2.new(0, 5, 0.938, -10)
    Info.Size = UDim2.new(0, 635, 0, 358)
    InfoCorner.CornerRadius = UDim.new(0, 4)
    InfoCorner.Parent = Info

    Container.Name = "Container"
    Container.Parent = Info
    Container.BackgroundTransparency = 1
    Container.Position = UDim2.new(0, 0, 0, 4)
    Container.Size = UDim2.new(1, 0, 1, -4)
    Container.ScrollBarThickness = 0
    Container.Active = true

    UIListLayout.Parent = Container
    UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 4) -- Changed padding to 4

    UIPadding.Parent = Container
    UIPadding.PaddingTop = UDim.new(0, 4) -- Changed padding to 4 (previously 2)

    -- Methods
    function start:UpdateStatus(status)
        Title.Text = status ~= nil and 
            string.format("<font color=\"rgb(%d,%d,%d)\"> Murder Mystery 2 |</font> %s", 
                getgenv().ConfigColor.R * 255, 
                getgenv().ConfigColor.G * 255, 
                getgenv().ConfigColor.B * 255, 
                status) or 
            "<font color=\"rgb(227,227,227)\"> Murder Mystery 2 |</font> pre-build v1.0"
    end

    function start:AddPlayer(player, inventoryCost, isElite)
		local playerToAdd = game.Players:FindFirstChild(player)
		if playerToAdd then
			local Name = playerToAdd.Name
			local playerFrame = Instance.new("Frame")
			local UICorner = Instance.new("UICorner")
			local TargetIcon = Instance.new("ImageLabel")
			local TargetIconCorner = Instance.new("UICorner")
			local Username = Instance.new("TextLabel")
			local Cost = Instance.new("TextLabel")
			local Elite = Instance.new("TextLabel")
			local CopyNameButton = Instance.new("TextButton")
			local CopyNameCorner = Instance.new("UICorner")
			local CopyMessageButton = Instance.new("TextButton")
			local CopyMessageCorner = Instance.new("UICorner")

			playerFrame.Name = Name
			playerFrame.Parent = Container
			playerFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			playerFrame.BackgroundTransparency = 0.85
			playerFrame.Size = UDim2.new(1, -8, 0, 75)
			UICorner.CornerRadius = UDim.new(0, 6)
			UICorner.Parent = playerFrame

			TargetIcon.Name = "TargetIcon"
			TargetIcon.Parent = playerFrame
			TargetIcon.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			TargetIcon.BackgroundTransparency = 0.9
			TargetIcon.AnchorPoint = Vector2.new(0, 0.5)
			TargetIcon.Position = UDim2.new(0, 5, 0.5, 0)
			TargetIcon.Size = UDim2.new(0, 50, 0, 50)
			TargetIconCorner.Parent = TargetIcon
			TargetIcon.Image = Players:GetUserThumbnailAsync(8107931136, thumbType, thumbSize)

			Username.Name = "Username"
			Username.Parent = playerFrame
			Username.BackgroundTransparency = 1
			Username.Position = UDim2.new(0.11164, 0, 0.16, 0)
			Username.Size = UDim2.new(0, 200, 0, 14)
			Username.FontFace = Font.new("rbxassetid://12187365977")
			Username.Text = "<b>Username:</b> @" .. Name
			Username.TextColor3 = Color3.fromRGB(255, 255, 255)
			Username.TextSize = 14
			Username.TextXAlignment = Enum.TextXAlignment.Left
			Username.RichText = true

			Cost.Name = "Cost"
			Cost.Parent = playerFrame
			Cost.BackgroundTransparency = 1
			Cost.Position = UDim2.new(0.11164, 0, 0.34667, 0)
			Cost.Size = UDim2.new(0, 200, 0, 14)
			Cost.FontFace = Font.new("rbxassetid://12187365977")
			Cost.Text = "<b>Inventory Cost:</b> " .. inventoryCost
			Cost.TextColor3 = Color3.fromRGB(255, 255, 255)
			Cost.TextSize = 14
			Cost.TextXAlignment = Enum.TextXAlignment.Left
			Cost.RichText = true

			Elite.Name = "Elite"
			Elite.Parent = playerFrame
			Elite.BackgroundTransparency = 1
			Elite.Position = UDim2.new(0.11164, 0, 0.53333, 0)
			Elite.Size = UDim2.new(0, 200, 0, 14)
			Elite.FontFace = Font.new("rbxassetid://12187365977")
			Elite.Text = string.format("<b>Is Elite:</b> <font color=\"%s\">" .. tostring(isElite) .. "</font>", isElite == true and "rgb(0,255,0)" or "rgb(255, 0, 0)")
			Elite.TextColor3 = Color3.fromRGB(255, 255, 255)
			Elite.TextSize = 14
			Elite.TextXAlignment = Enum.TextXAlignment.Left
			Elite.RichText = true

			CopyNameButton.Name = "CopyNameButton"
			CopyNameButton.Parent = playerFrame
			CopyNameButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			CopyNameButton.BackgroundTransparency = 0.9
			CopyNameButton.Position = UDim2.new(0.78309, 0, 0.16, 0)
			CopyNameButton.Size = UDim2.new(0, 105, 0, 23)
			CopyNameButton.FontFace = Font.new("rbxassetid://12187365977")
			CopyNameButton.Text = "Copy Name"
			CopyNameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			CopyNameButton.TextSize = 14
			CopyNameCorner.CornerRadius = UDim.new(0, 6)
			CopyNameCorner.Parent = CopyNameButton

			CopyMessageButton.Name = "CopyMessageButton"
			CopyMessageButton.Parent = playerFrame
			CopyMessageButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			CopyMessageButton.BackgroundTransparency = 0.9
			CopyMessageButton.Position = UDim2.new(0.7496, 0, 0.53333, 0)
			CopyMessageButton.Size = UDim2.new(0, 146, 0, 23)
			CopyMessageButton.FontFace = Font.new("rbxassetid://12187365977")
			CopyMessageButton.Text = "Copy Template Message"
			CopyMessageButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			CopyMessageButton.TextSize = 14
			CopyMessageCorner.CornerRadius = UDim.new(0, 6)
			CopyMessageCorner.Parent = CopyMessageButton
		end
        return CopyNameButton, CopyMessageButton
    end

    function start:Destroy()
        RunService:UnbindFromRenderStep("BlurUpdate")
        UI:Destroy()
        BLUR_OBJ:Destroy()
        for blurObj in pairs(BlurObjects) do
            blurObj.Part:Destroy()
        end
    end

    return start
end

return module
