// Libc includes
#include <err.h>
#include <stdio.h>
#include <string.h>
#include <pwd.h>
#include <unistd.h>
#include <arpa/inet.h> // for htons
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <net/if.h>

#include "rilproxy.h"

int
udp_client_socket (const char *host, unsigned short port)
{
    struct sockaddr_in addr;
    int fd, rv;

    fprintf (stderr, "Opening %s:%d\n", host, port);

    fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (fd < 0) err (2, "socket");

    memset (&addr, 0, sizeof (addr));

    addr.sin_family = AF_INET;
    addr.sin_port   = htons(port);
    addr.sin_addr.s_addr = inet_addr(host);

    rv = connect (fd, (struct sockaddr *)&addr, sizeof(addr));
    if (rv < 0) err (2, "connect");

    return fd;
}

int
udp_server_socket (unsigned short port)
{
    struct sockaddr_in addr;
	int fd, rv;

	fd = socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (fd < 0) err (1, "socket");
	
	memset (&addr, 0, sizeof (addr));
	
	addr.sin_family      = AF_INET;
	addr.sin_port        = htons(port);
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	
	rv = bind (fd, (struct sockaddr*)&addr, sizeof(addr));
	if (rv < 0) err (2, "bind");

	return fd;
}

int
unix_client_socket (const char *socket_path)
{
    int rv = -1;
    int fd = -1;
    struct sockaddr_un addr;

    fd = socket (AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) err (1, "socket");

    addr.sun_family = AF_UNIX;
    strncpy (addr.sun_path, socket_path, sizeof (addr.sun_path));

    rv = connect (fd, (struct sockaddr *)&addr, sizeof (struct sockaddr_un));
    if (rv < 0)
    {
        close (fd);
        err (2, "connect");
    }

    fprintf (stderr, "Connected to %s\n", socket_path);
    return fd;
}

int
unix_server_socket (const char *socket_path)
{
    int rv = -1;
    int fd = -1;
    int msgfd = -1;
    struct sockaddr_un addr;

    fd = socket (AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) err (1, "socket");

    addr.sun_family = AF_UNIX;
    strncpy (addr.sun_path, socket_path, sizeof (addr.sun_path));

    rv = bind (fd, (struct sockaddr *)&addr, sizeof (struct sockaddr_un));
    if (rv < 0) err (2, "bind");

    listen (fd, 1);
    msgfd = accept (fd, NULL, NULL);
    if (msgfd < 0) err (2, "accept");

    close (fd);
    unlink (socket_path);
    return (msgfd);
}

int
get_uid (const char *username)
{
    struct passwd *radio_user;

    radio_user = getpwnam (username);
    if (radio_user == NULL)
    {
        warn ("getpwnam(radio)");
        return -1;
    }

    return radio_user->pw_uid;
}

int
send_control_message (int fd, int message_type)
{
    int rv = -1;
    message_t message;

    message.length = 4;
    message.id     = message_type;

    rv = write (fd, &message, sizeof (message));
    if (rv < 0)
    {
        warn ("write");
        return -1;
    }

    return 0;
}

void
proxy (int local_fd, int remote_fd)
{
    int rv = -1;
    fd_set fds;

    for (;;)
    {
        FD_ZERO (&fds);
        FD_SET (local_fd, &fds);
        FD_SET (remote_fd, &fds);

        rv = select (2, &fds, NULL, NULL, NULL);
        if (rv < 0)
        {
            warn ("select");
            continue;
        }

        printf ("Select returned\n");

        if (FD_ISSET (local_fd, &fds))
        {
            printf ("Would proxy local -> remote\n");
        }

        if (FD_ISSET (remote_fd, &fds))
        {
            printf ("Would proxy remote -> local\n");
        }
    }
}
