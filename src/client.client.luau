local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Net = require(script.Parent.Net)
local Trove = require(script.Parent.Parent.Trove)

local Projectiles = {}

local Projectile = {}
Projectile.__index = Projectile

type ProjectileData = {
	Id: string,
	Size: number,
	Time: number,
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
	table.clear(self)
end

function Projectile:Update(DeltaTime: number)
	if self and self.Position and self.Direction and self.Speed then
		local newCFrame = CFrame.lookAt(self.Position, self.Position + self.Direction)

		if self.Visual and self.Visual:IsA("Model") then
			self.Visual:PivotTo(newCFrame)
		else
			self.Visual.CFrame = newCFrame
		end

		local Result = workspace:Blockcast(
			CFrame.lookAt(self.Position, self.Position + self.Direction),
			Vector3.one * self.Size,
			self.Direction,
			self.__RaycastParams
		)

		if Result and Result.Instance then
			local Hit = Result.Instance

			Net.hit.send({
				Id = self.Id,
				Time = workspace:GetServerTimeNow(),
				Normal = Result.Normal,
				Object = if Hit and Hit:IsDescendantOf(VisualFolder) then tostring(Hit) else Hit,
				Position = Result.Position,
			})
		end

		if self.MaxDistance and self.DistanceTraveled >= self.MaxDistance then
			self:Destroy()
		end

		local Step = self.Direction * self.Speed * DeltaTime
		self.Position += Step
		self.DistanceTraveled += Step.Magnitude
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

	if Data.Config then
		self.Config = require(Data.Config)
	end

	self.Cleaner = Trove.new()

	if Data.Visual then
		self.Visual = self.Cleaner:Add(Data.Visual:Clone(), "Destroy")
		self.Visual.CFrame = CFrame.new(self.Position, self.Position + self.Direction)
			* CFrame.new(0, 0, workspace:GetServerTimeNow() - Data.Time) -- account for any latency
		self.Visual.Parent = VisualFolder
	end

	local IgnoreList = CollectionService:GetTagged("ProjectileCasterIgnore")

	for _, Instance in pairs(Data.Ignore or {}) do
		table.insert(IgnoreList, Instance)
	end

	IgnoreList[#IgnoreList + 1] = VisualFolder

	local _RaycastParams = RaycastParams.new()
	_RaycastParams.FilterDescendantsInstances = IgnoreList
	_RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.__RaycastParams = _RaycastParams

	self.Cleaner:Connect(RunService.RenderStepped, function(DeltaTime)
		self:Update(DeltaTime)
	end)

	Projectiles[Data.Id] = self

	return self
end

Net.update.listen(function(Data: { Id: string, Position: Vector3, Direction: Vector3 })
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

Net.destroy.listen(
	function(Id: string) -- add a destroy case incase the server wants the projectile to end earlier MaxDistance
		local _Projectile = Projectiles[Id]

		if _Projectile then
			_Projectile:Destroy()
		end

		Projectiles[Id] = nil
	end
)

Net.create.listen(Projectile.new)
