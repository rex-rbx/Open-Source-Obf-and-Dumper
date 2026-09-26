do
	local serde = require("@lune/serde")
	local b
	local loadfn = loadstring
	local gsub = ("").gsub
	local typeof = typeof
	local tostring = tostring
	local error = error
	local _debug = debug
	local freeze = table.freeze
	local _rawset = rawset
	local _rawget = rawget
	local _setmetatable = setmetatable
	local _getmetatable = getmetatable
	local _setfenv = setfenv
	local sbdbg = _setmetatable({}, {
		__metatable = false,
		__tostring = function()
			return "debug"
		end,
		__index = function(self, key)
			if typeof(key) ~= "string" then
				return error("not allowed", 2)
			end;
			--// allow 0% risk access to certain debug libraries that only read.
			if key == "info" then
				return _debug.info
			elseif key == "traceback" then
				return _debug.traceback
			else
				return error("not supported", 2)
			end
			return nil -- should never reach here
		end
	})
	local sfenv = function(fn, a)
		for i, v in next, a do
			if typeof(i) ~= "string" and typeof(i) ~= "number" then
				return error("not allowed", 2)
			end;
			if typeof(i) == "string" then
				i = gsub(i, "%z", "")
			end
			rawset(b, i, v)
		end
		return typeof(fn) == "function" and fn or nil
	end
	debug = sbdbg
	local lsf
	local req = function(...)
		return error("not allowed", 2)
	end;
	require = req;
	local load_fn = function()
		return error("load doesnt exist in luau; please use loadstring (not supported)", 2)
	end
	local fakeRawGet = function(t, k)
		return _rawget(t, k)
	end
	local fakeRawSet = function(t, k, v)
		local mt = _getmetatable(t)
		if typeof(mt) ~= "table" and typeof(mt) ~= "nil" and (typeof(mt) ~= "string" or mt ~= "super secret sandbox metatable") then
			return error("not allowed", 2) -- prevent rawset on a protected __metatable table
		end
		mt = nil
		return _rawset(t, k, v)
	end
	local INTERNAL_SHAREDTBL; INTERNAL_SHAREDTBL = _setmetatable({}, {
		__metatable = false,
		__tostring = function()
			return "shared"
		end,
		__index = function(self, key)
			if typeof(key) ~= "string" and typeof(key) ~= "number" then
				return error("not allowed", 2)
			end;
			return _rawget(INTERNAL_SHAREDTBL, key)
		end	,
		__newindex = function(self, key, value)
			if typeof(key) ~= "string" and typeof(key) ~= "number" then
				return error("not allowed", 2)
			end;
			return _rawset(INTERNAL_SHAREDTBL, key, value)
		end
	})
	load = load_fn
	local a = table.clone(getfenv())
	local fenvFunc = function()
		return b
	end
	getfenv = fenvFunc
	b = _setmetatable({_G = b}, freeze({
		__index = function(c, d)
			if typeof(d) ~= "string" and typeof(d) ~= "number" then
				return error("not allowed", 2)
			end;
			if typeof(d) == "number" then
				d = tostring(d)
			end
			d = gsub(d, "%z", "")
			if d == "require" then
				return req
			end;
			if d == "loadstring" then
				return lsf
			end;
			if d == "load" then
				return load_fn
			end;
			if d == "debug" then
				return sbdbg
			end;
			if d == "getfenv" then
				return fenvFunc
			end;
			if d == "setfenv" then
				return sfenv
			end;
			if d == "rawget" then
				return fakeRawGet
			end;
			if d == "rawset" then
				return fakeRawSet
			end;
			if d == "_G" then
				return b
			end;
			if d == "shared" then
				return INTERNAL_SHAREDTBL
			end;
			if d == "_VERSION" then
				return "Luau"
			end;
			return _rawget(b, d) or _rawget(a, d) or a[d]
		end,
		__newindex = function(c, d, e)
			_rawset(b, d, e)
		end,
		__tostring = function()
			return "sandbox"
		end,
		__metatable = "super secret sandbox metatable"
	}))
	_setfenv(0, b)
	_setfenv(1, b)
	setfenv = sfenv
	lsf = function(...)
		local f, e = loadfn(...)
		return f and _setfenv(f, b) or nil, e
	end;
	loadstring = lsf
	rawset = fakeRawSet
	rawget = fakeRawGet
	_G = b
	shared = INTERNAL_SHAREDTBL
	INTERNAL_SHAREDTBL.tomldecode = function(d)
		return serde.decode("toml", d)
	end
	INTERNAL_SHAREDTBL.tomlencode = function(t)
		return serde.encode("toml", t)
	end
	INTERNAL_SHAREDTBL.jsondecode = function(d)
		return serde.decode("json", d)
	end
	INTERNAL_SHAREDTBL.jsonencode = function(t)
		return serde.encode("json", t)
	end
	INTERNAL_SHAREDTBL.yamlencode = function(t)
		return serde.encode("yaml", t)
	end
	INTERNAL_SHAREDTBL.yamldecode = function(d)
		return serde.decode("yaml", d)
	end
	_VERSION = "Luau"
end

