--!strict
local PlayerService = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Net = require(script.Parent.Net)
local Trove = require(script.Parent.Parent.Trove)
local Signal = require(script.Parent.Parent.Signal)

local Projectile = {}
Projectile.__index = Projectile

type Projectile = typeof(setmetatable({} :: {
    Hit: typeof(Signal.new()),
    _Data: { [string]: any },
    _Cleaner: typeof(Trove.new()),
}, Projectile))

local HitRegistry = {}
local Projectiles: { Projectile } = {}

task.spawn(function() 
    while true do
        for Id, _Projectile: Projectile in Projectiles do
            if HitRegistry[Id] then
                for _, HitData in HitRegistry[Id] do
                    for Object, HitInfo in HitData do
                        if #HitInfo.__Players > (#PlayerService:GetPlayers() / 2) then
                            table.sort(HitInfo.__Hits, function(A, B)
                                return A.Name == "Server" or A.Time < B.Time 
                            end)
                            _Projectile.Hit:Fire(Object, unpack(HitInfo.__Hits[1]))
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

function Projectile.new(Data: { [string]: any }): Projectile
    Data.Id = HttpService:GenerateGUID(false)

    Net.create.sendToAll(Data)

    local self = setmetatable({
        Hit = Signal.new(),
        _Data = Data,
        _Cleaner = Trove.new(),
    }, Projectile)

    local Origin = Data.Start

    self._Cleaner:Add(task.spawn(function() 
        while true do
            Net.update.sendToAll({
                Id = Data.Id,
                Position = Data.Start,
                Direction = Data.Direction,
            })

            local DeltaTime = task.wait()
            Data.Start += Data.Direction * Data.Speed * DeltaTime
            
            local Result = workspace:Spherecast(Data.Start, Data.Size, Data.Direction * DeltaTime, self._Data.__RaycastParams)

            if Result then
                RegisterHit({
                    Id = Data.Id,
                    Time = workspace:GetServerTimeNow(),
                    Normal = Result.Normal,
                    Object = Result.Instance,
                    Position = Result.Position,
                }, "Server")
            end

            if Data.MaxDistance and (Data.Position - Origin).Magnitude >= self._Data.MaxDistance then
                self:Destroy()
                break
            end
        end
    end), true)

    Projectiles[Data.Id] = self

    return self
end

function Projectile:Destroy()
    Net.destroy.sendToAll(self._Data.Id)
    self.Hit:Destroy()
    if self._Cleaner then
        self._Cleaner:Destroy()
    end
    table.clear(self :: any)
end

Net.hit.listen(RegisterHit)

local function OnPlayerAdded(Player: Player)
    for _, _Projectile in Projectiles do
        Net.create.sendTo(_Projectile._Data, Player)
    end
end

for _, Player in PlayerService:GetPlayers() do
    task.spawn(OnPlayerAdded, Player)
end

PlayerService.PlayerAdded:Connect(OnPlayerAdded)

return Projectile