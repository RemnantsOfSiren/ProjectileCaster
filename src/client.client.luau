local RunService = game:GetService("RunService")

local Net = require(script.Parent.Net)
local Trove = require(script.Parent.Parent.Trove)

local Projectiles = {}

local Projectile = {}
Projectile.__index = Projectile

type ProjectileData = {
    Id: string,
    Size: number,
    Speed: number,
    Start: Vector3,
    Direction: Vector3,
    -- Optional fields
    Ignore: { Instance }?,
    Visual: Instance?,
    Config: Instance?,
    MaxDistance: number?,
}

local VisualFolder = Instance.new("Folder")
VisualFolder.Name = "Projectiles"
VisualFolder.Parent = workspace

function Projectile:Destroy()
    if self.Cleaner then
        self.Cleaner:Destroy()
    end

    Projectiles[self.Id] = nil
end

function Projectile:Update(DeltaTime: number)
    local Step = self.Direction * self.Speed * DeltaTime
    self.Position += Step
    self.DistanceTraveled += Step.Magnitude
    self.Visual.CFrame = CFrame.new(self.Position, self.Position + self.Direction)

    local Result = workspace:Spherecast(self.Position, self.Size, (self.Position + self.Direction).Unit * DeltaTime, self._OverlapParams)

    if Result then
        Net.hit.send({
            Id = self.Id,
            Time = workspace:GetServerTimeNow(),
            Normal = Result.Normal,
            Object = Result.Instance,
            Position = Result.Position,
        })
    end

    if self.MaxDistance and self.DistanceTraveled >= self.MaxDistance then
        self:Destroy()
    end
end

function Projectile.new(Data: ProjectileData)
    local self = setmetatable({
        Id = Data.Id,
        Size = Data.Size,
        Speed = Data.Speed,
        Position = Data.Start,
        Direction = Data.Direction,
        MaxDistance = Data.MaxDistance,
        DistanceTraveled = 0,
    }, Projectile)

    local _RaycastParams = RaycastParams.new()
    _RaycastParams.FilterDescendantsInstances = Data.Ignore or {}
    _RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

    if Data.Config then
        self.Config = require(Data.Config)
    end

    self.Cleaner = Trove.new()

    if Data.Visual then
        self.Visual = self.Cleaner:Add(Data.Visual:Clone(), "Destroy")
        self.Visual.CFrame = CFrame.new(self.Position, self.Position + self.Direction)
        self.Visual.Parent = VisualFolder
    end

    self.Cleaner:Connect(RunService.Heartbeat, function(DeltaTime)
        self:Update(DeltaTime)
    end)

    Projectiles[Data.Id] = self

    return self
end

Net.update.listen(function(Data: {Id: string, Position: Vector3, Direction: Vector3})
    local _Projectile = Projectiles[Data.Id]

    if _Projectile then
        if (Data.Position - _Projectile.Position).Magnitude > 3 then -- Add degree of error to prevent snapping
            _Projectile.Position = Data.Position
        end

        if _Projectile.Direction ~= Data.Direction then
            _Projectile.Direction = Data.Direction
        end
    end
end)

Net.destroy.listen(function(Id: string) -- add a destroy case incase the server wants the projectile to end earlier MaxDistance
    local _Projectile = Projectiles[Id]

    if _Projectile then
        _Projectile:Destroy()
    end

    Projectiles[Id] = nil
end)

Net.create.listen(Projectile.new)