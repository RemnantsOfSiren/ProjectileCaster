local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Net = require(script.Parent.Net.Client)
local Trajectory = require(script.Parent.Trajectory)
local Trove = require(script.Parent.Parent.Trove)

local IGNORE_TAG = "ProjectileCasterIgnore"

local MAX_SMOOTHED_ERROR = 24
local SMOOTHING_HALF_LIFE = 0.06

local Projectiles = {}

local Projectile = {}
Projectile.__index = Projectile

type ProjectileData = {
	Id: number,
	Seq: number,
	Size: number,
	Time: number,
	Speed: number,
	Origin: Vector3,
	Direction: Vector3,
	Distance: number,
	Ignore: { Instance }?,
	Visual: Instance?,
	Config: Instance?,
	MaxDistance: number?,
}

local VisualFolder = Instance.new("Folder")
VisualFolder.Name = "Projectiles"
VisualFolder.Parent = workspace

local BaseIgnore: { Instance }? = nil
local SharedParams: RaycastParams? = nil

local function GetBaseIgnore(): { Instance }
	local List = BaseIgnore

	if not List then
		List = CollectionService:GetTagged(IGNORE_TAG)
		table.insert(List :: { Instance }, VisualFolder)
		BaseIgnore = List
	end

	return List :: { Instance }
end

local function GetRaycastParams(Ignore: { Instance }?): RaycastParams
	if not Ignore or #Ignore == 0 then
		local Params = SharedParams

		if not Params then
			Params = RaycastParams.new()
			;(Params :: RaycastParams).FilterType = Enum.RaycastFilterType.Exclude
			;(Params :: RaycastParams).FilterDescendantsInstances = GetBaseIgnore()
			SharedParams = Params
		end

		return Params :: RaycastParams
	end

	local List = table.clone(GetBaseIgnore())
	table.move(Ignore, 1, #Ignore, #List + 1, List)

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = List

	return Params
end

local function InvalidateIgnoreCache()
	BaseIgnore = nil
	SharedParams = nil
end

CollectionService:GetInstanceAddedSignal(IGNORE_TAG):Connect(InvalidateIgnoreCache)
CollectionService:GetInstanceRemovedSignal(IGNORE_TAG):Connect(InvalidateIgnoreCache)

function Projectile:Destroy()
	if self.Cleaner then
		self.Cleaner:Destroy()
	end

	Projectiles[self.Id] = nil
	table.clear(self)
end

function Projectile:Render(Now: number, DeltaTime: number)
	local Visual = self.Visual

	if not Visual then
		return
	end

	local Offset = self.VisualOffset

	if Offset.Magnitude > Trajectory.Epsilon then
		self.VisualOffset = Offset * (0.5 ^ (DeltaTime / SMOOTHING_HALF_LIFE))
	elseif Offset ~= Vector3.zero then
		self.VisualOffset = Vector3.zero
	end

	local Position = Trajectory.PositionAt(self, Now) + self.VisualOffset
	local CFrameAt = Trajectory.LookAlong(Position, self.Direction)

	if Visual:IsA("Model") then
		Visual:PivotTo(CFrameAt)
	else
		Visual.CFrame = CFrameAt
	end
end

function Projectile.new(Data: ProjectileData)
	local Now = workspace:GetServerTimeNow()

	local self = setmetatable({
		Id = Data.Id,
		Seq = Data.Seq,
		Size = Data.Size,
		Time = Data.Time,
		Speed = Data.Speed,
		Origin = Data.Origin,
		Direction = Data.Direction,
		Distance = Data.Distance,
		MaxDistance = Data.MaxDistance,
		VisualOffset = Vector3.zero,
		Cleaner = Trove.new(),
		RaycastParams = GetRaycastParams(Data.Ignore),
	}, Projectile)

	self.LastPosition = Trajectory.PositionAt(self, Now)

	if Data.Config then
		self.Config = require(Data.Config)
	end

	if Data.Visual then
		self.Visual = self.Cleaner:Add(Data.Visual:Clone(), "Destroy")
		self.Visual.Parent = VisualFolder
	end

	Projectiles[Data.Id] = self
	self:Render(Now, 0)

	return self
end

local function Simulate()
	local Now = workspace:GetServerTimeNow()

	for Id, self in Projectiles do
		local Position = Trajectory.PositionAt(self, Now)
		local Displacement = Position - self.LastPosition

		if Displacement.Magnitude > Trajectory.Epsilon then
			local Result = workspace:Blockcast(
				Trajectory.LookAlong(self.LastPosition, Displacement),
				Vector3.one * self.Size,
				Displacement,
				self.RaycastParams
			)

			if Result and Result.Instance then
				Net.hit.fire({
					Id = Id,
					Time = Now,
					Normal = Result.Normal,
					Object = Result.Instance,
					Position = Result.Position,
				})
			end
		end

		self.LastPosition = Position
	end
end

local function Render(DeltaTime: number)
	local Now = workspace:GetServerTimeNow()

	for _, self in Projectiles do
		self:Render(Now, DeltaTime)
	end
end

RunService.PreSimulation:Connect(Simulate)
RunService.PreRender:Connect(Render)

Net.update.on(function(Data: ProjectileData)
	local _Projectile = Projectiles[Data.Id]

	if not _Projectile then
		return
	end

	if not Trajectory.IsNewer(Data.Seq, _Projectile.Seq) then
		return
	end

	local Now = workspace:GetServerTimeNow()
	local Before = Trajectory.PositionAt(_Projectile, Now)

	_Projectile.Seq = Data.Seq
	_Projectile.Time = Data.Time
	_Projectile.Origin = Data.Origin
	_Projectile.Direction = Data.Direction
	_Projectile.Distance = Data.Distance

	local After = Trajectory.PositionAt(_Projectile, Now)

	local Error = _Projectile.VisualOffset + (Before - After)
	_Projectile.VisualOffset = if Error.Magnitude > MAX_SMOOTHED_ERROR then Vector3.zero else Error

	_Projectile.LastPosition = After
end)

Net.destroy.on(
	function(Id: number)
		local _Projectile = Projectiles[Id]

		if _Projectile then
			_Projectile:Destroy()
		end

		Projectiles[Id] = nil
	end
)

Net.create.on(Projectile.new)

--[=[
	@function GetAll
	@within ProjectileCaster
	@return Projectile[]
	@client
	returns all projectiles that are currently active
]=]
return {
	GetAll = function()
		return Projectiles
	end,
}
