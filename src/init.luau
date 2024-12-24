local PlayerService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(script.Net)
local Signal = require(script.Parent.Signal)

local ProjectileCaster = {}
ProjectileCaster.__index = ProjectileCaster

type ProjectileCasterSettings = {
    Size: number?,
    Speed: number?,
    MaxDistance: number?,
    Visual: Instance?,
    Config: ModuleScript?,
    Ignore: { Instance }?,
}

function ProjectileCaster.new(Settings: ProjectileCasterSettings)
    if Settings.Visual then
        assert(Settings.Visual:IsDescendantOf(ReplicatedStorage), "@[ProjectileCaster] - Visual must be a descendant of ReplicatedStorage.")
    end

    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterDescendantsInstances = Settings.Ignore or {}
    RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

    return setmetatable({
        Hit = Signal.new(),
        Size = Settings.Size or 1,
        Speed = Settings.Speed or 10,
        Visual = Settings.Visual,
        Config = Settings.Config,
        MaxDistance = Settings.MaxDistance,
        __RaycastParams = RaycastParams,
    }, ProjectileCaster)
end

local HitRegistry = {}
local Projectiles = {}

task.spawn(function() 
    while true do
        for Id, Data in Projectiles do
            if HitRegistry[Id] then
                for _, HitData in HitRegistry[Id] do
                    for Object, HitInfo in HitData do
                        if #HitInfo.__Players > (#PlayerService:GetPlayers() / 2) then
                            table.sort(HitInfo.__Hits, function(A, B)
                                return A.Name == "Server" or A.Time < B.Time 
                            end)
                            Data[2].Hit:Fire(Object, unpack(HitInfo.__Hits[1]))
                        end
                    end
                end
            end
        end
        table.clear(HitRegistry)
        task.wait()
    end
end)

local function RegisterHit(Data: { Id: string, Time: number, Position: Vector3, Normal: Vector3, Object: Instance }, Player: Player | "Server")
    if not HitRegistry[Data.Id] then
        HitRegistry[Data.Id] = {}
    end

    if not HitRegistry[Data.Id][Data.Time] then
        HitRegistry[Data.Id][Data.Time] = {}
    end

    if not HitRegistry[Data.Id][Data.Time][Data.Object] then
        HitRegistry[Data.Id][Data.Time][Data.Object] = {
            __Players = {},
            __Hits = {},
        }
    end

    if not table.find(HitRegistry[Data.Id][Data.Time][Data.Object].__Players, Player) then
        table.insert(HitRegistry[Data.Id][Data.Time][Data.Object].__Players, Player)
        table.insert(HitRegistry[Data.Id][Data.Time][Data.Object].__Hits, { Data.Position, Data.Normal, Player })
    end
end

function ProjectileCaster:Cast(Start: Vector3, Direction: Vector3, VisualOverride: Instance?)
    if VisualOverride then
        assert(VisualOverride:IsDescendantOf(ReplicatedStorage), "@[ProjectileCaster] - Visual Override must be a descendant of ReplicatedStorage.")
    end

    local Id = game:GetService("HttpService"):GenerateGUID(false)

    local Data = {
        Id = Id,
        Size = self.Size,
        Speed = self.Speed,
        Start = Start,
        Direction = Direction,
        MaxDistance = self.MaxDistance,
        Visual = VisualOverride or self.Visual,
        Config = self.Config,
    }

    Projectiles[Id] = {
        Data,
        self,
    }

    Net.create.sendToAll(Data)

    local T = task.spawn(function() 
        while true do
            Net.update.sendToAll({
                Id = Id,
                Position = Data.Start,
                Direction = Direction,
            })

            local DeltaTime = task.wait()
            Data.Start += Direction * self.Speed * DeltaTime
            
            local Result = workspace:Spherecast(Data.Start, Data.Size, Direction * DeltaTime, self.__RaycastParams)

            if Result then
                RegisterHit({
                    Id = Id,
                    Time = workspace:GetServerTimeNow(),
                    Normal = Result.Normal,
                    Object = Result.Instance,
                    Position = Result.Position,
                }, "Server")
            end

            if self.MaxDistance and (Data.Start - Start).Magnitude >= self.MaxDistance then
                break
            end
        end
    end)

    return function()
        if coroutine.status(T) ~= "dead" then
            task.cancel(T)
        end

        Projectiles[Id] = nil
        Net.destroy.sendToAll(Id)
    end
end

Net.hit.listen(RegisterHit)

local function OnPlayerAdded(Player: Player)
    for _, Data in Projectiles do
        Net.create.sendTo(Data[1], Player)
    end
end

for _, Player in PlayerService:GetPlayers() do
    task.spawn(OnPlayerAdded, Player)
end

PlayerService.PlayerAdded:Connect(OnPlayerAdded)

return ProjectileCaster