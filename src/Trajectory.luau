--!strict
--[=[
	@class Trajectory
	@ignore

	Shared trajectory math.

	A projectile is described as a *segment*: (Origin, Direction, Speed, Time).
	Its position at any point on the shared `workspace:GetServerTimeNow()` clock is
		Origin + Direction * Speed * (Clock - Time)

	Neither peer accumulates delta time, so neither peer can drift from the other,
	and a client that evaluates the segment late lands on the correct extrapolated
	point instead of a stale one. That is what removes the need to stream positions
	every frame and correct them afterwards.

	The client and server MUST evaluate a segment identically -- any disagreement
	here reintroduces the desync this design exists to remove -- so the closed form
	lives in one module rather than being written twice.
]=]

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

--[=[
	@within Trajectory
	Position of a segment at `Clock`, clamped to the segment's remaining range.
]=]
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

--[=[
	@within Trajectory
	Total distance travelled across every segment so far, as of `Clock`.
]=]
function Trajectory.DistanceAt(Segment: Segment, Clock: number): number
	return Segment.Distance + (Trajectory.PositionAt(Segment, Clock) - Segment.Origin).Magnitude
end

--[=[
	@within Trajectory
	`CFrame.lookAt` produces NaN when the look vector is parallel to the up vector,
	which is any projectile fired straight up or down. A NaN CFrame poisons both the
	visual and the shapecast that uses it, so pick a safe up vector instead.
]=]
function Trajectory.LookAlong(From: Vector3, Direction: Vector3): CFrame
	local Unit = Direction.Unit
	local Up = if math.abs(Unit.Y) > 0.999 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(From, From + Unit, Up)
end

--[=[
	@within Trajectory
	Sequence numbers are a single byte on the wire, so compare them with wraparound.
]=]
function Trajectory.IsNewer(Sequence: number, Than: number): boolean
	local Difference = (Sequence - Than + 256) % 256
	return Difference > 0 and Difference < 128
end

--[=[
	@within Trajectory
	True when `Direction` is usable as a heading (finite and non-zero).
]=]
function Trajectory.IsValidDirection(Direction: Vector3): boolean
	if Direction ~= Direction then
		return false
	end

	local Magnitude = Direction.Magnitude
	return Magnitude > Trajectory.Epsilon and Magnitude < math.huge
end

return Trajectory
