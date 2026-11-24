-- Lighter on phones and slow devices. Touch-only devices start on "low"; anything else drops to "low"
-- once its frame rate stays under LowFps, and stays there for the session so it never flip-flops.
return {
	LowFps = 40,
	Window = 5, -- seconds the frame rate is averaged over
	Grace = 10, -- seconds after joining before it starts judging (streaming in is always slow)

	-- On low: dust under the lights emits at most this many particles a second
	MaxParticleRate = 1.5,
}
