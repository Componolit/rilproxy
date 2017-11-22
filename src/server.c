// Libc includes
#include <err.h>
#include <stdio.h>
#include <arpa/inet.h> // for htons
#include <sys/socket.h>

#define RILPROXY_ETHER_TYPE 0x1234  // FIXME

int
main (void)
{
    int fd = socket (PF_PACKET, SOCK_RAW, htons (RILPROXY_ETHER_TYPE));
    if (fd < 0)
    {
        err(1, "Opening raw socket");
    }

    printf ("Main\n");
    return 0;
}
