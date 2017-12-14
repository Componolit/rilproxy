-- This is Wireshark/tshark packet dissector for RILd messages. Place it into
-- your local plugin directory (e.g. $HOME/.wireshark/plugins/)

local rilproxy = Proto("rild", "Android RILd socket");

rilproxy.fields.length  = ProtoField.uint32('rilproxy.length', 'Length', base.DEC)
rilproxy.fields.content = ProtoField.string('rilproxy.content', 'Content', base.HEX)

function rilproxy.init()
    cache = ByteArray.new()
    bytesMissing = 0
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

    local header_len = buffer(0,4):uint()

    if header_len < 4 then
        print("Dropping short header len of " .. header_len)
        return
    end

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

    info.cols['protocol'] = 'RILProxy'
    info.cols['info'] = 'RIL[' .. header_len .. ']'

    local t = tree:add(rilproxy, buffer, "RIL Proxy")
    t:add(rilproxy.fields.length, header_len)
    t:add(rilproxy.fields.content, buffer(4, header_len))
end

local udp_port_table = DissectorTable.get("udp.port")
udp_port_table:add(18912, rilproxy.dissector)
