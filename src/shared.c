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
#include <sys/stat.h>
#include <sys/un.h>
#include <net/if.h>

#include "rilproxy.h"

#define MAX(a,b) (((a)>(b))?(a):(b))

int
socket_make_reusable (int fd)
{
    int rv = -1;
    int enable = 1;

    rv = setsockopt (fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));
    if (rv < 0)
    {
        warn ("setsockopt(SO_REUSEADDR)");
        return -1;
    }

    return 0;
}

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

    rv = socket_make_reusable (fd);
    if (rv < 0) err (2, "socket_make_reusable");
	
	memset (&addr, 0, sizeof (addr));
	
	addr.sin_family      = AF_INET;
	addr.sin_port        = htons(port);
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	
	rv = bind (fd, (struct sockaddr*)&addr, sizeof(addr));
	if (rv < 0) err (2, "udp_server_socket.bind to %d", port);

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
        err (2, "unix_client_socket.connect to %s", socket_path);
    }

    fprintf (stderr, "Connected to %s\n", socket_path);
    return fd;
}

int
unix_server_socket (const char *socket_path, const char *user)
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
    if (rv < 0) err (2, "unix_server_socket.bind to %s", socket_path);

    // Change user
    rv = chown (socket_path, get_uid (user), -1);
    if (rv < 0) err (3, "unix_server_socket.chown of %s", socket_path);

    // Change mode
    rv = chmod (socket_path, 0666);
    if (rv < 0) err (4, "unix_server_socket.chmod of %s", socket_path);

    rv = listen (fd, 1);
    if (rv < 0) err (5, "unix_server_socket.listen for %s", socket_path);

    msgfd = accept (fd, NULL, NULL);
    if (msgfd < 0) err (5, "unix_server_socket.accept to %s", socket_path);

    rv = close (fd);
    if (rv < 0) err (6, "unix_server_socket.close for %s", socket_path);

    rv = unlink (socket_path);
    if (rv < 0) err (7, "unix_server_socket.unlink for %s", socket_path);

    return (msgfd);
}

int
get_uid (const char *username)
{
    struct passwd *radio_user;

    radio_user = getpwnam (username);
    if (radio_user == NULL)
    {
        warn ("getpwnam(%s)", username);
        return -1;
    }

    return radio_user->pw_uid;
}

int
send_control_message (int fd, uint32_t message_type)
{
    int rv = -1;
    message_t message;

    message.length = 4;
    message.id     = message_type;

    rv = write (fd, &message, sizeof (message));
    if (rv < 0)
    {
        warn ("send_control_message.write message %u", message_type);
        return -1;
    }

    return 0;
}

int
socket_copy (int source_fd, int dest_fd)
{
    ssize_t bytes_written = -1;
    ssize_t bytes_read = -1;
    char buffer[1500];

    bytes_read = read (source_fd, &buffer, sizeof (buffer));
    if (bytes_read < 0)
    {
        warn ("socket_copy: error reading source socket");
        return -SOCKET_COPY_READ_ERROR;
    }

    if (bytes_read == 0)
    {
        warn ("socket_copy: reading socket closed");
        return -SOCKET_COPY_READ_CLOSED;
    }

    warnx ("read %zd bytes", bytes_read);

    bytes_written = write (dest_fd, &buffer, bytes_read);
    if (bytes_written < 0)
    {
        warn ("socket_copy: error writing destination socket");
        return -SOCKET_COPY_WRITE_ERROR;
    }

    if (bytes_written < bytes_read)
    {
        warn ("socket_copy: read %zd bytes, wrote %zd bytes", bytes_read, bytes_written);
        return 0;
    }

    warnx ("wrote %zd bytes", bytes_written);
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

        rv = select (MAX(local_fd, remote_fd) + 1, &fds, NULL, NULL, NULL);
        if (rv < 0)
        {
            warn ("select failed");
            continue;
        }

        if (FD_ISSET (local_fd, &fds))
        {
            printf ("Server: local -> remote\n");
            socket_copy (local_fd, remote_fd);
        }

        if (FD_ISSET (remote_fd, &fds))
        {
            printf ("Server: remote -> local\n");
            socket_copy (remote_fd, local_fd);
        }
    }
}

void
wait_control_message (int fd, uint32_t message_type)
{
    ssize_t msize;
    char buffer[1500];
    message_t *message;

    for (;;)
    {
        msize = read (fd, &buffer, sizeof (buffer));
        if (msize < 0)
        {
            err (1, "read");
        }

        message = (message_t *)&buffer;
        if (message->length == 4 && message->id == message_type)
        {
            return;
        }

        printf ("Got unknown message (len=%d, id=%x)\n", message->length, message->id);
    }
}
