Program to proxy packets transmitted between Android's native radio interfaces
layer daemon (RILd) and the com.android.phone service. Traffic is intersected
at the `/dev/socket/rild` UNIX domain socket and forwarded via UDP. Socket path
and UDP port are configurable.

Additional control messages ensure that the RILd socket on the device providing
the radio functionality is opened *after* the socket has been opened on the
other device. This is required to ensure that the initial unsolicited startup
message from RILd is received by the phone process.

A rudimentary Wirkeshark dissector for the protocol run on `/dev/socket/rild` is
available in `scripts/rilsocket.lua`. To install it run the follwing steps:

 - Get the the Android RIL source by `git clone https://android.googlesource.com/platform/hardware/ril`
 - Generate `ril_h.lua` with `./scripts/convert_ril_h.py --output ril_h.lua /path/to/ril/source/.../include/telephony/ril.h`
 - Copy `ril_h.lua` and `rilsocket.lua` to the Wireshark plugins directory (which can be found in Wireshark under Help->About Wireshark->Directories->Personal Plugins)


Shortcomings/future work:

* Implement fragmentation for messages greater MTU (minus overhead)
* Signal direction through a flag
* Implement raw Ethernet transport in addition to UDP
* Dissect multiple RIL packets in one UDP message
* Dissect more protocol messages

(C) 2017, Alexander Senier <senier@componolit.com>
