// Libc includes
#include <err.h>
#include <arpa/inet.h> // for htons
#include <sys/socket.h>
#include <net/if.h>

#include "rilproxy.h"

int
open_interface (const char *ifname)
{
    int sockopt = 1;
    int rv = -1;

    // Open socket
    int fd = socket (PF_PACKET, SOCK_RAW, htons (RILPROXY_ETHER_TYPE));
    if (fd < 0)
    {
        warn ("Opening raw socket");
        return -1;
    }

    // Make socket reusable
    rv = setsockopt (fd, SOL_SOCKET, SO_REUSEADDR, &sockopt, sizeof(sockopt));
    if (rv < 0)
    {
        warn ("setsockopt(SO_REUSEADDR)");
        return -1;
    }

    // Bind to device
    rv = setsockopt (fd, SOL_SOCKET, SO_BINDTODEVICE, ifname, IFNAMSIZ - 1);
    if (rv < 0)
    {
        warn ("setsockopt(SO_BINDTODEVICE)");
        return -1;
    }

    return fd;
}
