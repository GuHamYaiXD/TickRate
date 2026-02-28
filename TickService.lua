-- ---------------------------------------------------------------------------
--  Deterministic tick loop (Minecraft‑style 20 TPS baseline)
--  Tick counter wraps back to 0 after reaching 23 999  (24 000 total ticks)
--  Real‑time day length scales with live TPS
--  Public helpers: bind / unbind • setTPS • getTick • getClockTime
-- ---------------------------------------------------------------------------

local RunService   = game:GetService("RunService")
local Lighting     = game:GetService("Lighting")

local TICK_WRAP    = 999999995901            -- reset tick after [TICK_WRAP]

local TickRate = {}
TickRate.__index = TickRate

-------------------------------------------------------------------------------
--  new( tps [, baseDaySec [, BASE_TPS [, startHour ]]] )
--      tps          : live ticks‑per‑second you want right now
--      baseDaySec   : real‑seconds a full day lasts *when TPS = BASE_TPS*
--      BASE_TPS     : reference TPS you balance timings against (default 20)
--      startHour    : initial Lighting.ClockTime (default 6 > 06:00)
-------------------------------------------------------------------------------
function TickRate.new(tps, baseDaySec, BASE_TPS, startHour)
	BASE_TPS    = BASE_TPS  or 20
	startHour   = startHour or 6

	local self  = setmetatable({}, TickRate)

	-- core config ------------------------------------------------------------
	self.TPS            = tps or BASE_TPS
	self.BaseDaySec     = baseDaySec or 600         -- 10 min @ 20 TPS
	self.DayLengthTicks = self.BaseDaySec * BASE_TPS
	self._interval      = 1 / self.TPS

	self._tickCount     = math.floor(
		(startHour % 24) / 24 * self.DayLengthTicks
	) % TICK_WRAP
	
	self._listeners     = {}
	self._running       = false
	self._left          = 0                         -- time accumulator
	
	Lighting.ClockTime  = startHour                 -- immediate visual sync
	self:_start()
	return self
end

-------------------------------------------------------------------------------
--  private main loop
-------------------------------------------------------------------------------
function TickRate:_start()
	if self._running then return end
	self._running = true

	RunService.Heartbeat:Connect(function(dt)
		self._left += dt
		while self._left >= self._interval do
			self._left -= self._interval

			-- ==== tick counter with Minecraft‑style wrap ====================
			self._tickCount = (self._tickCount + 1) % TICK_WRAP

			-- advance listeners ---------------------------------------------
			for _, cb in pairs(self._listeners) do
				cb()
			end
		end
	end)
end

-------------------------------------------------------------------------------
--  public API
-------------------------------------------------------------------------------
function TickRate:bind(id, fn)         self._listeners[id] = fn     end
function TickRate:unbind(id)           self._listeners[id] = nil    end

function TickRate:setTPS(newTPS)
	assert(type(newTPS) == "number" and newTPS > 0,
		"TickRate:setTPS › TPS must be positive")
	self.TPS       = newTPS
	self._interval = 1 / newTPS
	print(("TickRate : TPS set to %.0f"):format(newTPS))
end

function TickRate:getTick()            return self._tickCount       end
function TickRate:getClockTime()       return Lighting.ClockTime    end

return TickRate
