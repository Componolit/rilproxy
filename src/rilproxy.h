#ifndef __RILPROXY_H__
#define __RILPROXY_H__

#define RILPROXY_ETHER_TYPE 0x1234  // FIXME
#define RILPROXY_INTERFACE "rndis0"

int open_interface (const char *ifname);

#endif // __RILPROXY_H__
