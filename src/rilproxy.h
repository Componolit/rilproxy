#ifndef __RILPROXY_H__
#define __RILPROXY_H__

enum
{
    RILPROXY_PORT = 18912,
    RILPROXY_BUFFER_SIZE = 3000
};

int udp_socket (const char *host, unsigned short port);
int unix_client_socket (const char *socket_path);
int unix_server_socket (const char *socket_path, const char *user);
int get_uid (const char *username);
int get_gid (const char *username);
int send_control_message (int fd, uint32_t message_type);
void wait_control_message (int fd, uint32_t message_type);
void proxy (int local_fd, int remote_fd);

typedef struct
{
    uint32_t length;
    uint32_t id;
} message_t;

enum { MESSAGE_SETUP_ID = 0xC715, MESSAGE_TEARDOWN_ID = 0xC717 };

enum
{
    SOCKET_COPY_READ_ERROR,
    SOCKET_COPY_READ_CLOSED,
    SOCKET_COPY_WRITE_ERROR,
    SOCKET_COPY_WRITE_CLOSED
};

#endif // __RILPROXY_H__
