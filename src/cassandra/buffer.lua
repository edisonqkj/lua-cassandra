local Buffer = require "cassandra.utils.buffer"
local t_utils = require "cassandra.utils.table"
local types = require "cassandra.types"
local cql_types = types.cql_types

local math_floor = math.floor
local type = type

--- Frame types
-- @section frame_types

local TYPES = {
  "byte",
  "int",
  -- "long",
  "short",
  "string",
  "long_string",
  "uuid",
  -- "string_list",
  "bytes",
  -- "short_bytes",
  "options",
  -- "options_list"
  "inet",
  -- "consistency"
  "string_map",
  -- "string_multimap"
}

for _, buf_type in ipairs(TYPES) do
  local mod = require("cassandra.types."..buf_type)
  Buffer["read_"..buf_type] = mod.read
  Buffer["repr_"..buf_type] = mod.repr
  Buffer["write_"..buf_type] = function(self, val)
    local repr = mod.repr(self, val)
    self:write(repr)
  end
end

--- CQL Types
-- @section cql_types

local CQL_DECODERS = {
  -- custom = 0x00,
  [cql_types.ascii] = "raw",
  -- [cql_types.bigint] = "bigint",
  [cql_types.blob] = "raw",
  [cql_types.boolean] = "boolean",
  -- [cql_types.counter] = "counter",
  -- decimal 0x06
  -- [cql_types.double] = "double",
  -- [cql_types.float] = "float",
  [cql_types.inet] = "inet",
  [cql_types.int] = "int",
  [cql_types.text] = "raw",
  [cql_types.list] = "set",
  [cql_types.map] = "map",
  [cql_types.set] = "set",
  [cql_types.uuid] = "uuid",
  -- [cql_types.timestamp] = "timestamp",
  [cql_types.varchar] = "raw",
  -- [cql_types.varint] = "varint",
  -- [cql_types.timeuuid] = "timeuuid",
  -- [cql_types.udt] = "udt",
  -- [cql_types.tuple] = "tuple"
}

for _, cql_decoder in pairs(CQL_DECODERS) do
  local mod = require("cassandra.types."..cql_decoder)
  Buffer["repr_cql_"..cql_decoder] = function(self, ...)
    local repr = mod.repr(self, ...)
    return self:repr_bytes(repr)
  end
  Buffer["write_cql_"..cql_decoder] = function(self, ...)
    local repr = mod.repr(self, ...)
    self:write_bytes(repr)
  end
  Buffer["read_cql_"..cql_decoder] = function(self, ...)
    local bytes = self:read_bytes()
    local buf = Buffer(self.version, bytes)
    return mod.read(buf, ...)
  end
end

function Buffer:repr_cql_value(value)
  local infered_type
  local lua_type = type(value)

  if lua_type == "number" then
    if math_floor(value) == value then
      infered_type = cql_types.int
    else
      --infered_type = cql_types.float
    end
  elseif lua_type == "table" then
    if t_utils.is_array(value) then
      infered_type = cql_types.set
    elseif value.value ~= nil and value.type_id ~= nil then
      infered_type = value.type_id
      value = value.value
    else
      infered_type = cql_types.map
    end
  else
    infered_type = cql_types.varchar
  end

  local encoder = "repr_cql_"..CQL_DECODERS[infered_type]
  return Buffer[encoder](self, value)
end

function Buffer:write_cql_value(...)
  self:write(self:repr_cql_value(...))
end

function Buffer:read_cql_value(assumed_type)
  local decoder = "read_cql_"..CQL_DECODERS[assumed_type.type_id]
  return Buffer[decoder](self, assumed_type.value_type_id)
end

function Buffer:write_cql_values(values)
  self:write_short(#values)
  for _, value in ipairs(values) do
    self:write_cql_value(value)
  end
end

return Buffer
