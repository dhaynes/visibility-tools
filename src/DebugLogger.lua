local Config = require(script.Parent.Config)

local DebugLogger = {
	debug = Config.Debug,
}

function DebugLogger:log(message)
	if self.debug then
		print(message)
	end
end

return DebugLogger
