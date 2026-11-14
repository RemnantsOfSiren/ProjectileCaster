--!strict
local Trajectory = {}

Trajectory.Epsilon = 1e-4

export type Segment = {
	Time: number,
	Speed: number,
	Origin: Vector3,
	Direction: Vector3,
	Distance: number,
	MaxDistance: number?,
}

function Trajectory.PositionAt(Segment: Segment, Clock: number): Vector3
	if Segment.Speed <= 0 then
		return Segment.Origin
	end

	local Elapsed = math.max(Clock - Segment.Time, 0)

	if Segment.MaxDistance then
		local Remaining = math.max(Segment.MaxDistance - Segment.Distance, 0)
		Elapsed = math.min(Elapsed, Remaining / Segment.Speed)
	end

	return Segment.Origin + Segment.Direction * (Segment.Speed * Elapsed)
end

function Trajectory.DistanceAt(Segment: Segment, Clock: number): number
	return Segment.Distance + (Trajectory.PositionAt(Segment, Clock) - Segment.Origin).Magnitude
end

function Trajectory.Rotation(Direction: Vector3): CFrame
	local Unit = Direction.Unit
	local Up = if math.abs(Unit.Y) > 0.999 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(Vector3.zero, Unit, Up)
end

function Trajectory.LookAlong(From: Vector3, Direction: Vector3): CFrame
	return Trajectory.Rotation(Direction) + From
end

function Trajectory.IsNewer(Sequence: number, Than: number): boolean
	local Difference = (Sequence - Than + 256) % 256
	return Difference > 0 and Difference < 128
end

function Trajectory.IsValidDirection(Direction: Vector3): boolean
	if Direction ~= Direction then
		return false
	end

	local Magnitude = Direction.Magnitude
	return Magnitude > Trajectory.Epsilon and Magnitude < math.huge
end

function Trajectory.ImpactNormal(Normal: Vector3, Displacement: Vector3): Vector3
	if Trajectory.IsValidDirection(Normal) then
		return Normal.Unit
	end

	return -Displacement.Unit
end

function Trajectory.IsFinite(Vector: Vector3): boolean
	return Vector == Vector and Vector.Magnitude < math.huge
end

return Trajectory
