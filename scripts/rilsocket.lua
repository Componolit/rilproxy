-- This is Wireshark/tshark packet dissector for RILd messages. Place it into
-- your local plugin directory (e.g. $HOME/.wireshark/plugins/)

local rilproxy = Proto("rild", "Android RILd socket");

rilproxy.fields.length  = ProtoField.uint32('rilproxy.length', 'Length', base.DEC)
rilproxy.fields.content = ProtoField.string('rilproxy.content', 'Content', base.HEX)

function rilproxy.init()
    pktState = {}
    bytesMissing = 0
end

function rilproxy.dissector(buffer, info, tree)

    if buffer:len() < 4 then return end

    local buffer_len = buffer:len()

    if bytesMissing > 0
    then
        -- FIXME: length must be <= bytesMissing
        cache:append(buffer(0):bytes())
        bytesMissing = bytesMissing - buffer_len
        buffer = ByteArray.tvb(cache, "Packet")
        return
    end

    local header_len = buffer(0,4):uint()

    print("header_len=" .. header_len .. " buffer_len=" .. buffer_len)
    if buffer_len < header_len - 4
    then
        print("Short buffer of length " .. buffer_len .. " (header len " .. header_len .. ")")
        bytesMissing = header_len - buffer_len - 4
        cache:append(buffer(0):bytes())
        return
    end


    local state = pktState[info.number]

    --if state ~= nil
    --then
    --    -- Packet has already been processed previously
    --    if state.complete == true
    --    then
    --        info.info = "Command [complete]"
    --        buffer = ByteArray.tvb(state.buffer, "Complete command")
    --    else
    --        info.info = "Command [incomplete]"
    --        return
    --    end
    --else
    --    -- Packet is handled for the first time
    --    state = {}

    --    if cache == nil
    --    then
    --        cache = buffer(0):bytes()
    --    else
    --        cache:append(buffer(0):bytes())
    --        -- New tvb for packet
    --        buffer = ByteArray.tvb(cache, "Command")
    --    end
    --end

    local t = tree:add(rilproxy, buffer, "RIL Proxy")
    t:add(rilproxy.fields.length, length)
    t:add(rilproxy.fields.content, buffer(4, len))
end

local udp_port_table = DissectorTable.get("udp.port")
udp_port_table:add(18912, rilproxy.dissector)
