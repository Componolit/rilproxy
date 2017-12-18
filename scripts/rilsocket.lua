-- This is Wireshark/tshark packet dissector for RILd messages. Place it into
-- your local plugin directory (e.g. $HOME/.wireshark/plugins/)

-- Load ril.h definitions generated by scripts/parse_ril_h.py
-- Place the resulting file as ril_h.lua into your plugin directory
local ril_h = require 'ril_h'

local rilproxy = Proto("rild", "RILd socket");

-- Register expert info fields
local rild_error = ProtoExpert.new("rild.error", "Error decoding RIL message", expert.group.MALFORMED, expert.severity.ERROR)
rilproxy.experts = { rild_error }

-----------------------------------------------------------------------------------------------------------------------
-- Helper functions
-----------------------------------------------------------------------------------------------------------------------
function parse_int_list(buffer)
    result = {}
    assert(buffer:len() > 3)
    local len = buffer:range(0,4):le_uint()
    assert(4 * len + 4 <= buffer:len())
    for i = 1, len
    do
        table.insert(result, buffer:range(4*i, 4):le_uint())
    end
    return result
end

-----------------------------------------------------------------------------------------------------------------------
-- hexdump dissector
-----------------------------------------------------------------------------------------------------------------------
local rild_content = Proto("rild.content", "Hexdump content");

rild_content.fields.content = ProtoField.bytes("rild.hexdump", "Hexdump", base.HEX)

function rild_content.dissector(buffer, info, tree)
    tree:add(rild_content.fields.content, buffer:range(0,-1))
end

-----------------------------------------------------------------------------------------------------------------------
-- UNSOL(RIL_CONNECTED) dissector
-----------------------------------------------------------------------------------------------------------------------
local unsol_ril_connected = Proto("rild.unsol.ril_connected", "RIL_CONNECTED");

unsol_ril_connected.fields.version = ProtoField.uint32('rild.unsol_ril_connected.version', 'RIL version', base.DEC)

function unsol_ril_connected.dissector(buffer, info, tree)
    values = parse_int_list(buffer)
    if #values == 1
    then
        tree:add_le(unsol_ril_connected.fields.version, buffer:range(4,4))
    else
        tree:add_tvb_expert_info(rild_error, buffer:range(0,4), "Expected integer list with 1 element (got " .. #values .. ")")
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- UNSOL(RESPONSE_RADIO_STATE_CHANGED) dissector
-----------------------------------------------------------------------------------------------------------------------

local unsol_response_radio_state_changed = Proto("rild.unsol.response_radio_state_changed", "RESPONSE_RADIO_STATE_CHANGED");

-- According to ril.h, RESPONSE_RADIO_STATE_CHANGED has no data payload.
-- However, older RIL.java sources mention that is "has bonus radio state int" which is casted into RadioState.
-- Try to extract and convert this additional field.
unsol_response_radio_state_changed.fields.version =
    ProtoField.uint32('rild.unsol.response_radio_state_changed.state', 'Radio state', base.DEC, RADIO_STATE)

function unsol_response_radio_state_changed.dissector(buffer, info, tree)
    if buffer:len() > 3
    then
        tree:add_le(unsol_response_radio_state_changed.fields.version, buffer:range(0,4))
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- REQUEST(RADIO_POWER) dissector
-----------------------------------------------------------------------------------------------------------------------

local request_radio_power = Proto("rild.request.radio_power", "REQUEST_RADIO_POWER");

-- FIXME: 'on' actually means > 0
RADIO_POWER = {
    [0] = "OFF",
    [1] = "ON"
}

request_radio_power.fields.power =
    ProtoField.uint32('rild.request.radio_power.power', 'Radio power', base.DEC, RADIO_POWER)

function request_radio_power.dissector(buffer, info, tree)
    values = parse_int_list(buffer)
    if #values == 1
    then
        tree:add(request_radio_power.fields.power, values[1])
    else
        tree:add_tvb_expert_info(rild_error, buffer:range(0,4), "Expected integer list with 1 element (got " .. #values .. ")")
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- REQUEST(CDMA_SET_SUBSCRIPTION_SOURCE) dissector
-----------------------------------------------------------------------------------------------------------------------

local request_cdma_set_subscription_source = Proto("rild.request.cdma_set_subscription_source", "REQUEST_CDMA_SET_SUBSCRIPTION_SOURCE");

request_cdma_set_subscription_source.fields.subscription =
    ProtoField.uint32('rild.request.cdma_set_subscription_source.fields.subscription', 'Subscription source', base.DEC, CDMA_SUBSCRIPTION)

function request_cdma_set_subscription_source.dissector(buffer, info, tree)
    values = parse_int_list(buffer)
    if #values == 1
    then
        tree:add(request_cdma_set_subscription_source.fields.subscription, values[1])
    else
        tree:add_tvb_expert_info(rild_error, buffer:range(0,4), "Expected integer list with 1 element (got " .. #values .. ")")
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- RILd dissector
-----------------------------------------------------------------------------------------------------------------------
local src_ip_addr_f = Field.new("ip.src")
local dst_ip_addr_f = Field.new("ip.dst")

MTYPE_REPLY = 0
MTYPE_UNSOL = 1

MTYPE = {
    [MTYPE_REPLY] = "REPLY",
    [MTYPE_UNSOL] = "UNSOL"
}

DIR_UNKNOWN = 0
DIR_FROM_AP = 1
DIR_FROM_BP = 2

DirectionLabel = {
    [DIR_UNKNOWN] = "[??->??]",
    [DIR_FROM_AP] = "[AP->BP]",
    [DIR_FROM_BP] = "[BP->AP]"
}

rilproxy.fields.length  = ProtoField.uint32('rilproxy.length', 'Length', base.DEC)
rilproxy.fields.request = ProtoField.uint32('rilproxy.request', 'Request', base.HEX, REQUEST)
rilproxy.fields.mtype   = ProtoField.uint32('rilproxy.mtype', 'Type', base.DEC, MTYPE)
rilproxy.fields.token   = ProtoField.uint32('rilproxy.token', 'Token', base.HEX)
rilproxy.fields.reply   = ProtoField.framenum('rilproxy.reply', 'In reply to frame', base.NONE, frametype.RESPONSE)
rilproxy.fields.result  = ProtoField.uint32('rilproxy.result', 'Result', base.DEC, RIL_E)
rilproxy.fields.event   = ProtoField.uint32('rilproxy.event', 'Event', base.DEC, UNSOL)

all_dissectors = {}

function direction()
    local src_ip = tostring(src_ip_addr_f())
    local dst_ip = tostring(dst_ip_addr_f())

    if (src_ip == ap_ip and dst_ip == bp_ip)
    then
        return DIR_FROM_AP
    end

    if (src_ip == bp_ip and dst_ip == ap_ip)
    then
        return DIR_FROM_BP
    end

    return DIR_UNKNOWN
end

function maybe_unknown(value)
    if value ~= nil
    then
        return value:lower()
    end

    return "unknown"
end

function query_dissector(name)

    name = name:lower()
    if all_dissectors[name] ~= nil
    then
        dissector = Dissector.get(name)
    else
        print("Missing dissector " .. name)
        dissector = Dissector.get("rild.content")
    end

    return dissector
end

function rilproxy.init()
    cache = ByteArray.new()
    bytesMissing = 0
    subDissector = false
    ap_ip = nil
    bp_ip = nil
    frames = {}

    for key,value in pairs(Dissector.list())
    do
        all_dissectors[value] = key
    end
end

function add_default_fields(tree, message, buffer, length)
    local subtree = tree:add(rilproxy, buffer:range(0, length), "RILd, " .. message)
    subtree:add(rilproxy.fields.length, buffer(0,4))
    return subtree
end

function rilproxy.dissector(buffer, info, tree)

    -- Follow-up to a message where length header indicates
    -- more bytes than available in the message.
    if bytesMissing > 0
    then

        if buffer:len() > bytesMissing
        then
            print("Follow-up message longer (" .. buffer:len() .. ") than missing bytes (" .. bytesMissing .. "), ignoring")
            bytesMissing = 0
            cache = ByteArray.new()
            return
        end

        cache:append(buffer(0):bytes())
        bytesMissing = bytesMissing - buffer:len()

        -- Still fragments missing, wait for next packet
        if bytesMissing > 0
        then
            return
        end

        buffer = ByteArray.tvb(cache, "Packet")
        cache = nil
    end

    local buffer_len = buffer:len()

    -- Message must be at least 4 bytes
    if buffer_len < 4 then
        print("Dropping short buffer of len " .. buffer_len)
        return
    end

    local header_len = buffer:range(0,4):uint()

    if header_len < 4 then
        print("Dropping short header len of " .. header_len)
        return
    end

    --  FIXME: Upper limit?
    if header_len > 1492
    then
        print("Skipping long buffer of length " .. header_len)
        bytesMissing = 0
        cache = ByteArray.new()
        return
    end

    if buffer_len <= (header_len - 4)
    then
        bytesMissing = header_len - buffer_len + 4
        cache:append(buffer(0):bytes())
        buffer = nil
        return
    end

    cache = ByteArray.new()
    bytesMissing = 0

    local rid = buffer(4,4):le_uint()
    if (rid == REQUEST_SETUP)
    then
        ap_ip = tostring(src_ip_addr_f())
        bp_ip = tostring(dst_ip_addr_f())
    end        

    if subDissector == true
    then
        info.cols.info:append (", ")
    else
        info.cols.info = DirectionLabel[direction()] .. " "
    end

    info.cols.protocol = 'RILProxy'

    if (direction() == DIR_FROM_AP)
    then
        -- Request
        message = "REQUEST(" .. maybe_unknown(REQUEST[rid]) .. ")"
        info.cols.info:append(message)
        subtree = add_default_fields(tree, message, buffer, header_len + 4)
        subtree:add_le(rilproxy.fields.request, buffer(4,4))
        if (buffer_len > 8)
        then
            frames[buffer(8,4):le_uint()] = info.number
            subtree:add_le(rilproxy.fields.token, buffer(8,4))
        end
        if (buffer_len > 12)
        then
            dissector = query_dissector("rild.request." .. REQUEST[rid])
            dissector:call(buffer(12, header_len - 12 + 4):tvb(), info, subtree)
        end
    elseif direction() == DIR_FROM_BP
    then
        local mtype = buffer(4,4):le_uint()
        if (mtype == MTYPE_REPLY)
        then
            local result = buffer(12,4):le_uint()
            message = "REPLY(" .. maybe_unknown(RIL_E[result]) ..")"
            info.cols.info:append(message)
            subtree = add_default_fields(tree, message, buffer, header_len + 4)
            subtree:add_le(rilproxy.fields.mtype, buffer(4,4))
            subtree:add_le(rilproxy.fields.token, buffer(8,4))
            if frames[buffer(8,4):le_uint()] ~= nil
            then
                subtree:add(rilproxy.fields.reply, frames[buffer(8,4):le_uint()])
            end
            subtree:add_le(rilproxy.fields.result, buffer(12,4))
            if (buffer_len > 16)
            then
                dissector = query_dissector("rild.reply." .. RIL_E[result])
                dissector:call(buffer(16, header_len - 16 + 4):tvb(), info, subtree)
            end
        elseif (mtype == MTYPE_UNSOL)
        then
            local event = buffer(8,4):le_uint()
            message = "UNSOL(" .. maybe_unknown(UNSOL[event]) .. ")"
            info.cols.info:append(message)
            subtree = add_default_fields(tree, message, buffer, header_len + 4)
            subtree:add_le(rilproxy.fields.mtype, buffer(4,4))
            subtree:add_le(rilproxy.fields.event, buffer(8,4))
            if (buffer_len > 12)
            then
                dissector = query_dissector("rild.unsol." .. UNSOL[event])
                dissector:call(buffer(12, header_len - 12 + 4):tvb(), info, subtree)
            end
        else
            info.cols.info:append("UNKNOWN REPLY")
        end
    else
        info.cols.info:append("INVALID DIRECTION")
    end


    -- If data is left in buffer, run dissector on it
    if buffer_len > header_len + 4
    then
        local previous = subDissector
        subDissector = true
        rilproxy.dissector (buffer:range(header_len + 4, -1):tvb(), info, tree)
        subDissector = previous
    end
end

local udp_port_table = DissectorTable.get("udp.port")
udp_port_table:add(18912, rilproxy.dissector)
