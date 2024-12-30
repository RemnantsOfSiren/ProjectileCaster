--!strict
local PlayerService = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Net = require(script.Parent.Net)
local Trove = require(script.Parent.Parent.Trove)
local Signal = require(script.Parent.Parent.Signal)

local Projectile = {}
Projectile.__index = Projectile

type Projectile = typeof(setmetatable(
	{} :: {
		Hit: typeof(Signal.new()),
		_Data: { [string]: any },
		_Cleaner: typeof(Trove.new()),
	},
	Projectile
))

local HitRegistry = {}
local Projectiles: { [string]: Projectile } = {}

task.spawn(function()
	while true do
		for Id, _Projectile: Projectile in Projectiles do
			if HitRegistry[Id] then
				for _, HitData in HitRegistry[Id] do
					for Object, HitInfo in HitData do
						if
							(not table.find(HitInfo.__Players, "Server") and #HitInfo.__Players > 1)
							or (#HitInfo.__Players > (#PlayerService:GetPlayers() * 0.1))
						then
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

local function RegisterHit(
	Data: { Id: string, Time: number, Position: Vector3, Normal: Vector3, Object: Instance },
	Player: Player | "Server"
)
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

local ServerInstance = Instance.new("Part")
ServerInstance.Anchored = true
ServerInstance.CanCollide = false
ServerInstance.CanQuery = false
ServerInstance.CanTouch = false
ServerInstance.Transparency = 0.5

--[=[
	@class Projectile
	Projectile is used to manage and detect hits of a projectile in the game world.
]=]

--[=[
	@prop Hit Signal
	@within Projectile
	Signal that fires when the projectile hits an object.
	```lua
	Projectile.Hit:Connect(function(Object: Instance, Position: Vector3, Normal: Vector3)
		-- Code
	end)
	```
]=]

--[=[
	@function new
	@within Projectile
	@param Data: { [string]: any }
	@return Projectile
	Creates a new Projectile instance.
]=]
function Projectile.new(Data: { [string]: any }): Projectile
	Data.Id = HttpService:GenerateGUID(false)
	Data.Time = workspace:GetServerTimeNow()

	Net.create.sendToAll(table.clone(Data))

	Data.Time = nil

	local self = setmetatable({
		Hit = Signal.new(),
		_Data = Data,
		_Cleaner = Trove.new(),
	}, Projectile)

	Data.Position = Data.Start
	Data.Start = nil

	if Data.Debug then
		local ServerInstance = self._Cleaner:Add(ServerInstance:Clone(), "Destroy")
		ServerInstance.Name = Data.Id
		ServerInstance.Size = Vector3.new(Data.Size, Data.Size, Data.Size)
		ServerInstance.Position = Data.Position
		ServerInstance.Parent = workspace.CurrentCamera.ServerProjectiles
		self._ServerInstance = ServerInstance
	end

	local DistanceTraveled = 0

	self._Cleaner:Add(
		task.spawn(function()
			while true do
				Net.update.sendToAll({
					Id = Data.Id,
					Position = Data.Position,
					Direction = Data.Direction,
				})

				local Result

				if self._ServerInstance then
					self._ServerInstance.Position = Data.Position
					Result = workspace:Shapecast(ServerInstance, Vector3.one * Data.Size, Data.__RaycastParams)
				else
					Result = workspace:Blockcast(
						CFrame.lookAt(Data.Position, Data.Position + Data.Direction),
						Vector3.one * Data.Size,
						Data.__RaycastParams
					)
				end

				if Result then
					task.spawn(RegisterHit, {
						Id = Data.Id,
						Time = workspace:GetServerTimeNow(),
						Normal = Result.Normal,
						Object = Result.Instance,
						Position = Result.Position,
					}, "Server")
				end

				if Data.MaxDistance and DistanceTraveled >= Data.MaxDistance then
					self:Destroy()
					break
				end

				local DeltaTime = task.wait()
				local Step = Data.Direction * Data.Speed * DeltaTime
				Data.Position += Step
				DistanceTraveled += Step.Magnitude
			end
		end),
		true
	)

	Projectiles[Data.Id] = self

	return self
end

--[=[
	@method GetDirection
	@within Projectile
	@return Vector3
	Returns the direction of the projectile.	
]=]
function Projectile:GetDirection()
	return self._Data.Direction
end

--[=[
	@method UpdateDirection
	@within Projectile
	@param Direction Vector3
]=]
function Projectile:UpdateDirection(Direction: Vector3)
	self._Data.Direction = Direction
end

--[=[
	@method Destroy
	@within Projectile

	Destroys the projectile.
	this method will destroy the projectile and all of its connections.
	It's auto called if there is a max distance specified and the projectile reaches it.
]=]
function Projectile:Destroy()
	Projectiles[self._Data.Id] = nil
	Net.destroy.sendToAll(self._Data.Id)
	self.Hit:Destroy()
	if self._Cleaner then
		self._Cleaner:Destroy()
	end
	table.clear(self :: any)
end

Net.hit.listen(function(Data)
	local Success, Error = pcall(RegisterHit, Data)

	if not Success then
		warn(Error)
	end
end)

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
