// Libc includes
#include <err.h>
#include <stdio.h>
#include <string.h>
#include <arpa/inet.h> // for htons
#include <sys/socket.h>
#include <net/if.h>

#define RILPROXY_ETHER_TYPE 0x1234  // FIXME
#define RILPROXY_INTERFACE "rndis0"

int
main (void)
{
    int rv = -1;
    int sockopt = 1;
    char ifname[IFNAMSIZ];

    strncpy (ifname, RILPROXY_INTERFACE, sizeof (RILPROXY_INTERFACE));

    // Open socket
    int fd = socket (PF_PACKET, SOCK_RAW, htons (RILPROXY_ETHER_TYPE));
    if (fd < 0)
    {
        err(1, "Opening raw socket");
    }

    // Make socket reuasable
    rv = setsockopt (fd, SOL_SOCKET, SO_REUSEADDR, &sockopt, sizeof(sockopt));
    if (rv < 0)
    {
        err(2, "setsockopt(SO_REUSEADDR)");
    }

    // Bind to device
    rv = setsockopt (fd, SOL_SOCKET, SO_BINDTODEVICE, ifname, IFNAMSIZ - 1);
    if (rv < 0)
    {
        err(3, "setsockopt(SO_BINDTODEVICE)");
    }

    printf ("Server\n");
    return 0;
}
