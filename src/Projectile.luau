--!strict
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require(script.Parent.Net.Server)
local Trajectory = require(script.Parent.Trajectory)
local Trove = require(script.Parent.Parent.Trove)
local Signal = require(script.Parent.Parent.Signal)

--[[
	Replication model
	-----------------
	Projectiles replicate as trajectory segments (see Trajectory.luau), not as a
	stream of per-frame positions. A packet only goes out when the trajectory
	itself changes -- creation, a direction change, destruction -- because between
	those points both peers derive the same position from the shared clock. There
	is no drift to correct, so there is nothing to correct every frame.

	Every live projectile is stepped by one shared connection rather than by its
	own coroutine. Casting N projectiles used to allocate ~3N coroutines per frame;
	the resulting GC pressure was itself a source of frame hitching, independent of
	the network traffic.
]]

local HIT_GRACE = 0.25
local SURFACE_OFFSET = 0.01

local Projectile = {}
Projectile.__index = Projectile

export type Segment = {
	Id: number,
	Seq: number,
	Size: number,
	Speed: number,
	Time: number,
	Origin: Vector3,
	Direction: Vector3,
	Distance: number,
	MaxDistance: number?,
	Visual: Instance?,
	Config: Instance?,
	Ignore: { Instance }?,
	__RaycastParams: RaycastParams,
	__LastPosition: Vector3,
	__LastTime: number,
	__ImpactTime: number?,
	__DebugInstance: BasePart?,
}

type Projectile = typeof(setmetatable(
	{} :: {
		Hit: typeof(Signal.new()),
		Destroying: typeof(Signal.new()),
		_Data: Segment?,
		_Cleaner: typeof(Trove.new()),
	},
	Projectile
))

type HitReport = {
	Time: number,
	Position: Vector3,
	Normal: Vector3,
	Source: Player | "Server",
}

type HitBucket = {
	Deadline: number,
	Reports: { HitReport },
}

local Projectiles: { [number]: Projectile } = {}
local HitRegistry: { [number]: { [Instance]: HitBucket } } = {}

local NextId = 0

local function AllocateId(): number
	NextId = (NextId + 1) % 4294967296
	return NextId
end

local ServerInstance = Instance.new("Part")
ServerInstance.Anchored = true
ServerInstance.CanCollide = false
ServerInstance.CanQuery = false
ServerInstance.CanTouch = false
ServerInstance.Transparency = 0.5

local function BuildPacket(Data: Segment)
	return {
		Id = Data.Id,
		Seq = Data.Seq,
		Size = Data.Size,
		Time = Data.Time,
		Speed = Data.Speed,
		Origin = Data.Origin,
		Direction = Data.Direction,
		Distance = math.floor(Data.Distance),
		Config = Data.Config,
		Visual = Data.Visual,
		Ignore = Data.Ignore,
		MaxDistance = Data.MaxDistance,
	}
end

local function RegisterHit(
	Data: { Id: number, Time: number, Position: Vector3, Normal: Vector3, Object: Instance },
	Source: Player | "Server"
)
	if not Projectiles[Data.Id] then
		return
	end

	local Buckets = HitRegistry[Data.Id]

	if not Buckets then
		Buckets = {}
		HitRegistry[Data.Id] = Buckets
	end

	local Bucket = Buckets[Data.Object]

	if not Bucket then
		Bucket = {
			Deadline = workspace:GetServerTimeNow() + HIT_GRACE,
			Reports = {},
		}
		Buckets[Data.Object] = Bucket
	end

	for _, Report in Bucket.Reports do
		if Report.Source == Source then
			return
		end
	end

	table.insert(Bucket.Reports, {
		Time = Data.Time,
		Position = Data.Position,
		Normal = Data.Normal,
		Source = Source,
	})
end

local function CompareReports(A: HitReport, B: HitReport): boolean
	if (A.Source == "Server") ~= (B.Source == "Server") then
		return A.Source == "Server"
	end

	return A.Time < B.Time
end

local function ResolveHits(Now: number)
	local PlayerCount = #PlayerService:GetPlayers()

	for Id, Buckets in HitRegistry do
		local _Projectile = Projectiles[Id]

		for Object, Bucket in Buckets do
			local Reports = Bucket.Reports
			local HasServer = false

			for _, Report in Reports do
				if Report.Source == "Server" then
					HasServer = true
					break
				end
			end


			local Confirmed = HasServer or (#Reports >= 2 and #Reports > PlayerCount * 0.1)

			if not Confirmed and Now < Bucket.Deadline then
				continue
			end

			if Confirmed and _Projectile and _Projectile.Hit then
				table.sort(Reports, CompareReports)

				local Best = Reports[1]
				local Data = _Projectile._Data

				if Data then
					Data.__ImpactTime = math.clamp(Best.Time, Data.Time, Now)
				end

				_Projectile.Hit:Fire(Object, Best.Position, Best.Normal)

				if Data then
					Data.__ImpactTime = nil
				end
			end

			Buckets[Object] = nil
		end

		if next(Buckets) == nil then
			HitRegistry[Id] = nil
		end
	end
end

local Expired: { Projectile } = {}

local function Step()
	local Now = workspace:GetServerTimeNow()

	for Id, _Projectile in Projectiles do
		local Data = _Projectile._Data

		if not Data then
			Projectiles[Id] = nil
			continue
		end

		local Position = Trajectory.PositionAt(Data, Now)
		local Previous = Data.__LastPosition
		local Displacement = Position - Previous

		if Displacement.Magnitude > Trajectory.Epsilon then
			local Result

			if Data.__DebugInstance then
				Data.__DebugInstance.Position = Previous
				Result = workspace:Shapecast(Data.__DebugInstance, Displacement, Data.__RaycastParams)
			else
				Result = workspace:Blockcast(
					Trajectory.LookAlong(Previous, Displacement),
					Vector3.one * Data.Size,
					Displacement,
					Data.__RaycastParams
				)
			end

			if Result and Result.Instance then
				RegisterHit({
					Id = Id,
					Time = Data.__LastTime + Result.Distance / Data.Speed,
					Normal = Result.Normal,
					Object = Result.Instance,
					Position = Result.Position,
				}, "Server")
			end
		end

		Data.__LastPosition = Position
		Data.__LastTime = Now

		if Data.MaxDistance and Trajectory.DistanceAt(Data, Now) >= Data.MaxDistance then
			table.insert(Expired, _Projectile)
		end
	end

	ResolveHits(Now)

	if #Expired > 0 then
		for _, _Projectile in Expired do
			_Projectile:Destroy()
		end

		table.clear(Expired)
	end
end

RunService.PostSimulation:Connect(Step)

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
	@prop Destroying Signal
	@within Projectile
	Signal that fires when the projectile is being destroyed.
	```lua
	Projectile.Destroying:Connect(function()
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
	assert(Trajectory.IsValidDirection(Data.Direction), "@[ProjectileCaster] - Direction must be finite and non-zero.")

	local Now = workspace:GetServerTimeNow()

	local Segment: Segment = {
		Id = AllocateId(),
		Seq = 0,
		Size = Data.Size,
		Speed = Data.Speed,
		Time = Now,
		Origin = Data.Start,
		Direction = Data.Direction.Unit,
		Distance = 0,
		MaxDistance = Data.MaxDistance,
		Visual = Data.Visual,
		Config = Data.Config,
		Ignore = Data.Ignore,
		__RaycastParams = Data.__RaycastParams,
		__LastPosition = Data.Start,
		__LastTime = Now,
	}

	local self = setmetatable({
		Hit = Signal.new(),
		Destroying = Signal.new(),
		_Data = Segment,
		_Cleaner = Trove.new(),
	}, Projectile)

	self._Cleaner:Add(self.Hit, "Destroy")
	self._Cleaner:Add(self.Destroying, "Destroy")

	if Data.Debug then
		local _ServerInstance = self._Cleaner:Add(ServerInstance:Clone(), "Destroy")
		_ServerInstance.Name = tostring(Segment.Id)
		_ServerInstance.Size = Vector3.one * Segment.Size
		_ServerInstance.CFrame = Trajectory.LookAlong(Segment.Origin, Segment.Direction)
		_ServerInstance.Parent = workspace.ServerProjectiles
		Segment.__DebugInstance = _ServerInstance
	end

	Projectiles[Segment.Id] = self
	Net.create.fireAll(BuildPacket(Segment))

	return self
end

--[=[
	@method GetPosition
	@within Projectile
	@return Vector3
	Returns the position of the projectile.
]=]
function Projectile:GetPosition(): Vector3?
	local Data = self._Data
	return Data and Trajectory.PositionAt(Data, workspace:GetServerTimeNow())
end

--[=[
	@method GetDirection
	@within Projectile
	@return Vector3
	Returns the direction of the projectile.
]=]
function Projectile:GetDirection(): Vector3?
	local Data = self._Data
	return Data and Data.Direction
end

--[=[
	@method UpdateDirection
	@within Projectile
	@param Direction Vector3

	Starts a new trajectory segment from wherever the projectile is right now.
	This is the only thing that puts an update on the wire.

	Called from a `Hit` handler it instead rebases to the exact point and moment of
	contact, so a deflection does not depend on which sub-frame phase the projectile
	happened to be cast on. Two identical shots into identical geometry then leave
	in identical directions.
]=]
function Projectile:UpdateDirection(Direction: Vector3)
	local Data = self._Data

	if not Data then
		return
	end

	if not Trajectory.IsValidDirection(Direction) then
		warn("@[ProjectileCaster] - Direction must be finite and non-zero, ignoring.")
		return
	end

	local Impact = Data.__ImpactTime
	local Now = Impact or workspace:GetServerTimeNow()
	local Position = Trajectory.PositionAt(Data, Now)

	Data.Distance += (Position - Data.Origin).Magnitude
	Data.Direction = Direction.Unit
	Data.Origin = if Impact then Position + Data.Direction * SURFACE_OFFSET else Position
	Data.Time = Now
	Data.Seq = (Data.Seq + 1) % 256
	Data.__LastPosition = Data.Origin
	Data.__LastTime = Now

	Net.update.fireAll({
		Id = Data.Id,
		Seq = Data.Seq,
		Time = Now,
		Origin = Data.Origin,
		Direction = Data.Direction,
		Distance = math.floor(Data.Distance),
	})
end

--[=[
	@method Destroy
	@within Projectile

	Destroys the projectile.
	this method will destroy the projectile and all of its connections.
	It's auto called if there is a max distance specified and the projectile reaches it.
]=]
function Projectile:Destroy()
	local Data = self._Data

	if not Data then
		return
	end

	Projectiles[Data.Id] = nil
	HitRegistry[Data.Id] = nil

	Net.destroy.fireAll(Data.Id)
	self.Destroying:Fire()

	if self._Cleaner then
		task.defer(self._Cleaner.Destroy, self._Cleaner)
	end

	table.clear(self :: any)
end

Net.hit.on(function(Player, Data)
	local Success, Error = pcall(RegisterHit, Data, Player)

	if not Success then
		warn(Error)
	end
end)

local function OnPlayerAdded(Player: Player)
	for _, _Projectile in Projectiles do
		local Data = _Projectile._Data

		if Data then
			Net.create.fire(Player, BuildPacket(Data))
		end
	end
end

for _, Player in PlayerService:GetPlayers() do
	task.spawn(OnPlayerAdded, Player)
end

PlayerService.PlayerAdded:Connect(OnPlayerAdded)

return Projectile
