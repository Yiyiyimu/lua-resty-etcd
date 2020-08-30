local etcdv2      = require("resty.etcd.v2")
local etcdv3      = require("resty.etcd.v3")
local utils       = require("resty.etcd.utils")
local decode_json = require("cjson.safe").decode
local typeof      = require("typeof")
local require     = require
local pcall       = pcall
local io          = io
local prefix_v3   = {
    ["3.5."] = "/v3",
    ["3.4."] = "/v3",
    ["3.3."] = "/v3beta",
    ["3.2."] = "/v3alpha",
}

local _M = {version = 0.9}

-- get version without create etcd client
local function etcd_version(opts)
    local http_host  = opts.http_host
    if not typeof.string(http_host) and not typeof.table(http_host) then
        return nil, 'opts.http_host must be string or string array'
    end
    if type(http_host) == 'table' then -- multi nodes
        http_host = http_host[1]
    end

    local cmd = "curl " .. http_host .. "/version"
    local t, err = io.popen(cmd)
    if not t then
        return nil, "failed to get etcd version"
    end
    local res = t:read("*all")
    t:close()
    
    if res == "" then
        return nil, "failed to get etcd version"
    end

    res = decode_json(res)
    
    return res
end

local function require_serializer(serializer_name)
    if serializer_name then
        local ok, module = pcall(require, "resty.etcd.serializers." .. serializer_name)
        if ok then
            return module
        end
    end

    return require("resty.etcd.serializers.json")
end

function _M.new(opts)
    opts = opts or {}
    if not typeof.table(opts) then
        return nil, 'opts must be table'
    end

    opts.timeout = opts.timeout or 5    -- 5 sec
    opts.http_host = opts.http_host or "http://127.0.0.1:2379"
    opts.ttl  = opts.ttl or -1

    local protocol = opts and opts.protocol or "v2"

    if protocol == "v3" then
        -- if opts special the api_prefix,no need to check version
        if not opts.api_prefix or not utils.has_value(prefix_v3, opts.api_prefix) then
            local ver, err = etcd_version(opts)
            if not ver then
                return nil, err
            end
            local sub_ver = ver.etcdserver:sub(1, 4)
            opts.api_prefix = prefix_v3[sub_ver]
        end
        return etcdv3.new(opts)
    end

    opts.api_prefix = "/v2"
    local serializer_name = typeof.string(opts.serializer) and opts.serializer
    opts.serializer = require_serializer(serializer_name)

    return etcdv2.new(opts)
end


return _M
