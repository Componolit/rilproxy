-- This is Wireshark/tshark packet dissector for RILd messages. Place it into
-- your local plugin directory (e.g. $HOME/.wireshark/plugins/)

local rilproxy = Proto("rild", "RILd socket");
local src_ip_addr_f = Field.new("ip.src")
local dst_ip_addr_f = Field.new("ip.dst")

MessageID = {
    [0xC715] = "SETUP",
    [0xC717] = "TEARDOWN"
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
rilproxy.fields.id      = ProtoField.uint32('rilproxy.id', 'ID', base.HEX, MessageID)
rilproxy.fields.content = ProtoField.bytes('rilproxy.content', 'Content', base.HEX)

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

function message_type(id)
    if MessageID[id] ~= nil
    then
        return MessageID[id]
    end

    return "UNKNOWN_MESSAGE_" .. id
end

function rilproxy.init()
    cache = ByteArray.new()
    bytesMissing = 0
    subDissector = false
    ap_ip = nil
    bp_ip = nil
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

    mt = message_type(buffer:range(4,4):le_uint())

    if mt == "SETUP"
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

    info.cols.info:append(mt)
    info.cols.protocol = 'RILProxy'

    local subtree = tree:add(rilproxy, buffer:range(0, header_len + 4), mt)
    subtree:add(rilproxy.fields.length, buffer(0,4))
    subtree:add_le(rilproxy.fields.id, buffer(4,4))

    if header_len - 4 > 0
    then
        subtree:add(rilproxy.fields.content, buffer:range(8, header_len - 4))
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
