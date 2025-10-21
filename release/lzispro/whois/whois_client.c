//1. Header includes and macro definitions
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <getopt.h>
#include <netdb.h>
#include <ctype.h>
#include <pthread.h>
#include <time.h>
#include <limits.h>

// Macro definitions
#define DEFAULT_WHOIS_PORT 43
#define BUFFER_SIZE 524288
#define MAX_RETRIES 2
#define TIMEOUT_SEC 5
#define DNS_CACHE_SIZE 10
#define CONNECTION_CACHE_SIZE 5
#define CACHE_TIMEOUT 300
#define DEBUG 0

// Redirect related constants
#define MAX_REDIRECTS 5
#define REDIRECT_WARNING "Warning: Maximum redirects reached (%d).\nYou may need to manually query the final server for complete information.\n\n"

// Response processing constants
#define RESPONSE_SEPARATOR "\n=== %s query to %s ===\n"
#define FINAL_QUERY_TEXT "Final"
#define REDIRECTED_QUERY_TEXT "Redirected"
#define ADDITIONAL_QUERY_TEXT "Additional"

// Configuration structure - stores all configurable parameters
typedef struct {
    int whois_port;              // WHOIS server port
    size_t buffer_size;           // Response buffer size
    int max_retries;             // Maximum retry count
    int timeout_sec;             // Timeout in seconds
    size_t dns_cache_size;       // DNS cache entries count
    size_t connection_cache_size;// Connection cache entries count
    int cache_timeout;           // Cache timeout in seconds
    int debug;                   // Debug mode flag
} Config;

// Global configuration, initialized with macro definitions
Config g_config = {
    .whois_port = DEFAULT_WHOIS_PORT,
    .buffer_size = BUFFER_SIZE,
    .max_retries = MAX_RETRIES,
    .timeout_sec = TIMEOUT_SEC,
    .dns_cache_size = DNS_CACHE_SIZE,
    .connection_cache_size = CONNECTION_CACHE_SIZE,
    .cache_timeout = CACHE_TIMEOUT,
    .debug = DEBUG
};

// DNS cache structure - stores domain to IP mapping
typedef struct {
    char *domain;                // Domain name
    char *ip;                    // IP address
    time_t timestamp;            // Cache timestamp
} DNSCacheEntry;

// Connection cache structure - stores connections to servers
typedef struct {
    char *host;                  // Hostname or IP
    int port;                    // Port number
    int sockfd;                  // Socket descriptor
    time_t last_used;            // Last used time
} ConnectionCacheEntry;

// WHOIS server structure - stores WHOIS server information
typedef struct {
    const char *name;            // Server short name
    const char *domain;          // Server domain
    const char *description;     // Server description
} WhoisServer;

// WHOIS server list - all supported WHOIS servers
WhoisServer servers[] = {
    {"arin", "whois.arin.net", "American Registry for Internet Numbers"},
    {"apnic", "whois.apnic.net", "Asia-Pacific Network Information Centre"},
    {"ripe", "whois.ripe.net", "RIPE Network Coordination Centre"},
    {"lacnic", "whois.lacnic.net", "Latin America and Caribbean Network Information Centre"},
    {"afrinic", "whois.afrinic.net", "African Network Information Centre"},
    {"iana", "whois.iana.org", "Internet Assigned Numbers Authority"},
    {NULL, NULL, NULL}  // End of list marker
};
// Global cache variables
static DNSCacheEntry *dns_cache = NULL;
static ConnectionCacheEntry *connection_cache = NULL;
static pthread_mutex_t cache_mutex = PTHREAD_MUTEX_INITIALIZER;
static size_t allocated_dns_cache_size = 0;
static size_t allocated_connection_cache_size = 0;

//3. Function declarations
// Utility functions
size_t parse_size_with_unit(const char *str);
void print_usage(const char *program_name);
void print_version();
void print_servers();
int is_private_ip(const char *ip);
int validate_config();  // 确保返回0表示失败，1表示成功
void init_caches();
void cleanup_caches();
size_t get_free_memory();  // Changed to size_t for consistency
void report_memory_error(const char *function, size_t size);

// DNS and connection cache functions
char *get_cached_dns(const char *domain);
void set_cached_dns(const char *domain, const char *ip);
int is_connection_alive(int sockfd);
int get_cached_connection(const char *host, int port);
void set_cached_connection(const char *host, int port, int sockfd);
const char *get_known_ip(const char *domain);

// Network connection functions
char *resolve_domain(const char *domain);
int connect_to_server(const char *host, int port, int *sockfd);
int connect_with_fallback(const char *domain, int port, int *sockfd);
int send_query(int sockfd, const char *query);
char *receive_response(int sockfd);

// WHOIS protocol processing functions
char *extract_refer_server(const char *response);
int is_authoritative_response(const char *response);
int needs_redirect(const char *response);
char *perform_whois_query(const char *target, int port, const char *query);
char *get_server_target(const char *server_input);

// Main function
int main(int argc, char *argv[]);

//4. Utility function implementations
size_t parse_size_with_unit(const char *str) {
    if (str == NULL || *str == '\0') {
        return 0;
    }
    
    // Skip leading whitespace
    while (isspace(*str)) str++;
    
    if (*str == '\0') {
        return 0;
    }
    
    char *end;
    errno = 0;
    unsigned long long size = strtoull(str, &end, 10);
    
    // Check for conversion errors
    if (errno == ERANGE) {
        return SIZE_MAX;
    }
    
    if (end == str) {
        return 0; // Invalid number
    }
    
    // Skip whitespace after number
    while (isspace(*end)) end++;
    
    // Process units
    if (*end) {
        char unit = toupper(*end);
        switch (unit) {
            case 'K': 
                if (size > SIZE_MAX / 1024) return SIZE_MAX;
                size *= 1024;
                end++;
                break;
            case 'M': 
                if (size > SIZE_MAX / (1024 * 1024)) return SIZE_MAX;
                size *= 1024 * 1024;
                end++;
                break;
            case 'G': 
                if (size > SIZE_MAX / (1024 * 1024 * 1024)) return SIZE_MAX;
                size *= 1024 * 1024 * 1024;
                end++;
                break;
            default: 
                // Invalid unit, but may just be a number
                if (g_config.debug) {
                    printf("[DEBUG] Unknown unit '%c' in size specification, ignoring\n", unit);
                }
                break;
        }
        
        // Check for extra characters (like "B" in "10MB")
        if (*end && !isspace(*end)) {
            if (g_config.debug) {
                printf("[DEBUG] Extra characters after unit: '%s'\n", end);
            }
        }
    }
    
    // Check if it exceeds size_t maximum value
    if (size > SIZE_MAX) {
        return SIZE_MAX;
    }
    
    if (g_config.debug) {
        printf("[DEBUG] Parsed size: '%s' -> %llu bytes\n", str, size);
    }
    
    return (size_t)size;
}

void print_usage(const char *program_name) {
    printf("Usage: %s [OPTIONS] <IP or domain>\n", program_name);
    printf("Options:\n");
    printf("  -h, --host HOST          Specify whois server (name or domain)\n");
    printf("  -p, --port PORT          Specify port number (default: %d)\n", DEFAULT_WHOIS_PORT);
    printf("  -b, --buffer-size SIZE   Set buffer size (default: %d)\n", BUFFER_SIZE);
    printf("  -r, --retries COUNT      Set maximum retry count (default: %d)\n", MAX_RETRIES);
    printf("  -t, --timeout SECONDS    Set timeout in seconds (default: %d)\n", TIMEOUT_SEC);
    printf("  -d, --dns-cache SIZE     Set DNS cache size (default: %d)\n", DNS_CACHE_SIZE);
    printf("  -c, --conn-cache SIZE    Set connection cache size (default: %d)\n", CONNECTION_CACHE_SIZE);
    printf("  -T, --cache-timeout SEC  Set cache timeout in seconds (default: %d)\n", CACHE_TIMEOUT);
    printf("  -D, --debug              Enable debug mode (default: %s)\n", DEBUG ? "on" : "off");
    printf("  -l, --list               List available whois servers\n");
    printf("  -v, --version            Show version information\n");
    printf("  -H, --help               Show this help message\n\n");
    printf("Examples:\n");
    printf("  %s 8.8.8.8\n", program_name);
    printf("  %s --host apnic 103.89.208.0\n", program_name);
    printf("  %s --timeout 10 --retries 3 8.8.8.8\n", program_name);
    printf("  %s --debug --buffer-size 1048576 8.8.8.8\n", program_name);
}

void print_version() {
    printf("whois client 3.0 (Optimized Redirect)\n");
    printf("High-performance whois query tool with reliable redirect handling\n");
}

void print_servers() {
    printf("Available whois servers:\n\n");
    for (int i = 0; servers[i].name != NULL; i++) {
        printf("  %-12s - %s\n", servers[i].name, servers[i].description);
        printf("            Domain: %s\n\n", servers[i].domain);
    }
}

int validate_config() {
    if (g_config.whois_port <= 0 || g_config.whois_port > 65535) {
        fprintf(stderr, "Error: Invalid port number in config\n");
        return 0;
    }
    if (g_config.buffer_size == 0) {  // Changed to check 0, as size_t is unsigned
        fprintf(stderr, "Error: Invalid buffer size in config\n");
        return 0;
    }
    if (g_config.max_retries < 0) {
        fprintf(stderr, "Error: Invalid retry count in config\n");
        return 0;
    }
    if (g_config.timeout_sec <= 0) {
        fprintf(stderr, "Error: Invalid timeout value in config\n");
        return 0;
    }
    if (g_config.dns_cache_size == 0) {  // Changed to check 0
        fprintf(stderr, "Error: Invalid DNS cache size in config\n");
        return 0;
    }
    if (g_config.connection_cache_size == 0) {  // Changed to check 0
        fprintf(stderr, "Error: Invalid connection cache size in config\n");
        return 0;
    }
    if (g_config.cache_timeout <= 0) {
        fprintf(stderr, "Error: Invalid cache timeout in config\n");
        return 0;
    }
    return 1;
}

int is_private_ip(const char *ip) {
    struct in_addr addr4;
    struct in6_addr addr6;
    
    // Check IPv4 private addresses
    if (inet_pton(AF_INET, ip, &addr4) == 1) {
        unsigned long ip_addr = ntohl(addr4.s_addr);
        return ((ip_addr >= 0x0A000000 && ip_addr <= 0x0AFFFFFF) || 
                (ip_addr >= 0xAC100000 && ip_addr <= 0xAC1FFFFF) || 
                (ip_addr >= 0xC0A80000 && ip_addr <= 0xC0A8FFFF));
    }
    
    // Check IPv6 private addresses
    if (inet_pton(AF_INET6, ip, &addr6) == 1) {
        // Unique Local Address (ULA): fc00::/7
        if ((addr6.s6_addr[0] & 0xFE) == 0xFC) {
            return 1;
        }
        // Link-local address: fe80::/10
        if (addr6.s6_addr[0] == 0xFE && (addr6.s6_addr[1] & 0xC0) == 0x80) {
            return 1;
        }
    }
    
    // Documentation addresses (2001:db8::/32) and loopback (::1)
    if (strncmp(ip, "2001:db8:", 9) == 0) return 1;
    if (strcmp(ip, "::1") == 0) return 1;
    
    return 0;
}

void init_caches() {
    pthread_mutex_lock(&cache_mutex);
    
    // Allocate DNS cache
    dns_cache = malloc(g_config.dns_cache_size * sizeof(DNSCacheEntry));
    if (dns_cache) {
        memset(dns_cache, 0, g_config.dns_cache_size * sizeof(DNSCacheEntry));
        allocated_dns_cache_size = g_config.dns_cache_size;  // Set allocated size
        if (g_config.debug) printf("[DEBUG] DNS cache allocated for %zu entries\n", g_config.dns_cache_size);
    } else {
        fprintf(stderr, "Error: Failed to allocate DNS cache (%zu entries)\n", g_config.dns_cache_size);
        allocated_dns_cache_size = 0;
    }
    
    // Allocate connection cache
    connection_cache = malloc(g_config.connection_cache_size * sizeof(ConnectionCacheEntry));
    if (connection_cache) {
        memset(connection_cache, 0, g_config.connection_cache_size * sizeof(ConnectionCacheEntry));
        for (int i = 0; i < g_config.connection_cache_size; i++) {
            connection_cache[i].sockfd = -1;
        }
        allocated_connection_cache_size = g_config.connection_cache_size;  // Set allocated size
        if (g_config.debug) printf("[DEBUG] Connection cache allocated for %zu entries\n", g_config.connection_cache_size);
    } else {
        fprintf(stderr, "Error: Failed to allocate connection cache (%zu entries)\n", g_config.connection_cache_size);
        allocated_connection_cache_size = 0;
    }
    
    pthread_mutex_unlock(&cache_mutex);
}

void cleanup_caches() {
    pthread_mutex_lock(&cache_mutex);
    
    // Clean up DNS cache
    if (dns_cache) {
        for (int i = 0; i < allocated_dns_cache_size; i++) {
            if (dns_cache[i].domain) {
                free(dns_cache[i].domain);
                dns_cache[i].domain = NULL;
            }
            if (dns_cache[i].ip) {
                free(dns_cache[i].ip);
                dns_cache[i].ip = NULL;
            }
        }
        free(dns_cache);
        dns_cache = NULL;
        allocated_dns_cache_size = 0;
    }
    
    // Clean up connection cache
    if (connection_cache) {
        for (int i = 0; i < allocated_connection_cache_size; i++) {
            if (connection_cache[i].host) {
                free(connection_cache[i].host);
                connection_cache[i].host = NULL;
            }
            if (connection_cache[i].sockfd != -1) {
                close(connection_cache[i].sockfd);
                connection_cache[i].sockfd = -1;
            }
        }
        free(connection_cache);
        connection_cache = NULL;
        allocated_connection_cache_size = 0;
    }
    
    pthread_mutex_unlock(&cache_mutex);
}

size_t get_free_memory() {  // Changed to return size_t
    FILE *meminfo = fopen("/proc/meminfo", "r");
    if (!meminfo) return 0;
    
    char line[256];
    size_t free_mem = 0;
    
    while (fgets(line, sizeof(line), meminfo)) {
        if (strncmp(line, "MemFree:", 8) == 0) {
            sscanf(line + 8, "%zu", &free_mem);
            break;
        }
    }
    
    fclose(meminfo);
    return free_mem;
}

void report_memory_error(const char *function, size_t size) {
    fprintf(stderr, "Error: Memory allocation failed in %s for %zu bytes\n", function, size);
    fprintf(stderr, "       Reason: %s\n", strerror(errno));
    
    // If in debug mode, provide more information
    if (g_config.debug) {
        fprintf(stderr, "       Available memory might be limited on this system\n");
    }
}

int validate_cache_sizes() {
    size_t free_mem = get_free_memory();
    if (free_mem == 0) {
        return 1; // Unable to get memory info, assume valid
    }
    
    // Calculate required memory, add 10% safety margin
    size_t required_mem = (g_config.dns_cache_size * sizeof(DNSCacheEntry)) +
                          (g_config.connection_cache_size * sizeof(ConnectionCacheEntry));
    required_mem = required_mem * 110 / 100; // Add 10% safety margin
    
    if (required_mem > free_mem * 1024) { // free_mem is in KB
        fprintf(stderr, "Warning: Requested cache size (%zu bytes) exceeds available memory (%zu KB)\n",
                required_mem, free_mem);
        return 0;
    }
    
    return 1;
}

//5. Cache management function implementations
const char *get_known_ip(const char *domain) {
    if (strcmp(domain, "whois.apnic.net") == 0) return "202.12.29.20";
    if (strcmp(domain, "whois.ripe.net") == 0) return "193.0.6.135";
    if (strcmp(domain, "whois.arin.net") == 0) return "199.212.0.43";
    if (strcmp(domain, "whois.lacnic.net") == 0) return "200.3.14.10";
    if (strcmp(domain, "whois.afrinic.net") == 0) return "196.216.2.6";
    return NULL;
}

char *get_cached_dns(const char *domain) {
    pthread_mutex_lock(&cache_mutex);

    if (dns_cache == NULL) {
        pthread_mutex_unlock(&cache_mutex);
        return NULL;
    }
    
    time_t now = time(NULL);
    for (int i = 0; i < allocated_dns_cache_size; i++) {
        if (dns_cache[i].domain && strcmp(dns_cache[i].domain, domain) == 0) {
            if (now - dns_cache[i].timestamp < g_config.cache_timeout) {
                char *result = strdup(dns_cache[i].ip);
                pthread_mutex_unlock(&cache_mutex);
                return result;
            }
        }
    }
    
    pthread_mutex_unlock(&cache_mutex);
    return NULL;
}

void set_cached_dns(const char *domain, const char *ip) {
    pthread_mutex_lock(&cache_mutex);

    if (dns_cache == NULL) {
        pthread_mutex_unlock(&cache_mutex);
        return;
    }
    
    // 查找空槽或最旧的缓存项
    int oldest_index = 0;
    time_t oldest_time = time(NULL);
    
    for (int i = 0; i < allocated_dns_cache_size; i++) {  // 使用 allocated_dns_cache_size
        if (dns_cache[i].domain == NULL) {
            // 找到空槽
            dns_cache[i].domain = strdup(domain);
            dns_cache[i].ip = strdup(ip);
            dns_cache[i].timestamp = time(NULL);
            pthread_mutex_unlock(&cache_mutex);
            return;
        }
        
        if (dns_cache[i].timestamp < oldest_time) {
            oldest_time = dns_cache[i].timestamp;
            oldest_index = i;
        }
    }
    
    // Replace the oldest cache entry
    free(dns_cache[oldest_index].domain);
    free(dns_cache[oldest_index].ip);
    dns_cache[oldest_index].domain = strdup(domain);
    dns_cache[oldest_index].ip = strdup(ip);
    dns_cache[oldest_index].timestamp = time(NULL);
    
    pthread_mutex_unlock(&cache_mutex);
}

int is_connection_alive(int sockfd) {
    int error = 0;
    socklen_t len = sizeof(error);
    if (getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &error, &len) == 0) {
        return error == 0;
    }
    return 0;
}

int get_cached_connection(const char *host, int port) {
    pthread_mutex_lock(&cache_mutex);

    if (connection_cache == NULL) {
        pthread_mutex_unlock(&cache_mutex);
        return -1;
    }
    
    time_t now = time(NULL);
    for (int i = 0; i < allocated_connection_cache_size; i++) {
        if (connection_cache[i].host && 
            strcmp(connection_cache[i].host, host) == 0 && 
            connection_cache[i].port == port) {
            if (now - connection_cache[i].last_used < g_config.cache_timeout) {
                // Check if connection is still valid
                if (is_connection_alive(connection_cache[i].sockfd)) {
                    connection_cache[i].last_used = now;
                    int sockfd = connection_cache[i].sockfd;
                    pthread_mutex_unlock(&cache_mutex);
                    return sockfd;
                } else {
                    // Connection is invalid, close and clean up
                    close(connection_cache[i].sockfd);
                    free(connection_cache[i].host);
                    connection_cache[i].host = NULL;
                    connection_cache[i].sockfd = -1;
                }
            } else {
                // Connection expired, close and clean up
                close(connection_cache[i].sockfd);
                free(connection_cache[i].host);
                connection_cache[i].host = NULL;
                connection_cache[i].sockfd = -1;
            }
        }
    }
    
    pthread_mutex_unlock(&cache_mutex);
    return -1;
}

void set_cached_connection(const char *host, int port, int sockfd) {
    pthread_mutex_lock(&cache_mutex);
    
    // Find empty slot or oldest connection
    int oldest_index = 0;
    time_t oldest_time = time(NULL);
    
    for (int i = 0; i < allocated_connection_cache_size; i++) {  // 使用 allocated_connection_cache_size
        if (connection_cache[i].host == NULL) {
            // Found empty slot
            connection_cache[i].host = strdup(host);
            connection_cache[i].port = port;
            connection_cache[i].sockfd = sockfd;
            connection_cache[i].last_used = time(NULL);
            pthread_mutex_unlock(&cache_mutex);
            return;
        }
        
        if (connection_cache[i].last_used < oldest_time) {
            oldest_time = connection_cache[i].last_used;
            oldest_index = i;
        }
    }
    
    // Replace the oldest connection
    close(connection_cache[oldest_index].sockfd);
    free(connection_cache[oldest_index].host);
    connection_cache[oldest_index].host = strdup(host);
    connection_cache[oldest_index].port = port;
    connection_cache[oldest_index].sockfd = sockfd;
    connection_cache[oldest_index].last_used = time(NULL);
    
    pthread_mutex_unlock(&cache_mutex);
}

//6. 网络连接函数实现
char *resolve_domain(const char *domain) {
    if (g_config.debug) printf("[DEBUG] Resolving domain: %s\n", domain);
    
    // First check cache
    char *cached_ip = get_cached_dns(domain);
    if (cached_ip) {
        if (g_config.debug) printf("[DEBUG] Using cached DNS: %s -> %s\n", domain, cached_ip);
        return cached_ip;
    }
    
    struct addrinfo hints, *res = NULL, *p;
    int status;
    char *ip = NULL;
    
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    status = getaddrinfo(domain, NULL, &hints, &res);
    if (status != 0) {
        if (g_config.debug) printf("[DEBUG] Failed to resolve %s: %s\n", domain, gai_strerror(status));
        return NULL;
    }

    // 尝试所有地址
    for (p = res; p != NULL; p = p->ai_next) {
        void *addr;
        char ipstr[INET6_ADDRSTRLEN];
        
        if (p->ai_family == AF_INET) {
            struct sockaddr_in *ipv4 = (struct sockaddr_in *)p->ai_addr;
            addr = &(ipv4->sin_addr);
        } else {
            struct sockaddr_in6 *ipv6 = (struct sockaddr_in6 *)p->ai_addr;
            addr = &(ipv6->sin6_addr);
        }
        
        inet_ntop(p->ai_family, addr, ipstr, sizeof ipstr);
        char *current_ip = strdup(ipstr);
        if (current_ip == NULL) {
            continue; // Memory allocation failed, skip
        }
        
        // 简单测试连接性（可选）
        int test_sock = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (test_sock != -1) {
            close(test_sock);
            ip = current_ip;
            break;
        }
        free(current_ip);
    }
    
    freeaddrinfo(res);
    
    // Store result in cache
    if (ip) {
        set_cached_dns(domain, ip);
        if (g_config.debug) printf("[DEBUG] Resolved %s to %s (cached)\n", domain, ip);
    }
    
    return ip;
}

int connect_to_server(const char *host, int port, int *sockfd) {
    // First check connection cache
    int cached_sockfd = get_cached_connection(host, port);
    if (cached_sockfd != -1) {
        // Check if connection is still valid
        fd_set check_fds;
        struct timeval timeout = {0, 1000}; // 1ms超时
        
        FD_ZERO(&check_fds);
        FD_SET(cached_sockfd, &check_fds);
        
        if (select(cached_sockfd + 1, NULL, &check_fds, NULL, &timeout) > 0) {
            *sockfd = cached_sockfd;
            if (g_config.debug) printf("[DEBUG] Using cached connection to %s:%d\n", host, port);
            return 0;
        } else {
            // Connection is invalid, remove from cache
            close(cached_sockfd);
            pthread_mutex_lock(&cache_mutex);
            for (int i = 0; i < allocated_connection_cache_size; i++) {
                if (connection_cache[i].sockfd == cached_sockfd) {
                    free(connection_cache[i].host);
                    connection_cache[i].host = NULL;
                    connection_cache[i].sockfd = -1;
                    break;
                }
            }
            pthread_mutex_unlock(&cache_mutex);
        }
    }
    
    // Cache miss or connection invalid, create new connection
    struct addrinfo hints, *res, *p;
    int status;
    char port_str[6];
    
    snprintf(port_str, sizeof(port_str), "%d", port);
    
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    
    if ((status = getaddrinfo(host, port_str, &hints, &res)) != 0) {
        if (g_config.debug) printf("[DEBUG] getaddrinfo failed for %s: %s\n", host, gai_strerror(status));
        return -1;
    }
    
    for (p = res; p != NULL; p = p->ai_next) {
        *sockfd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (*sockfd == -1) {
            if (g_config.debug) printf("[DEBUG] socket creation failed: %s\n", strerror(errno));
            continue;
        }
        
        struct timeval timeout = {g_config.timeout_sec, 0};
        setsockopt(*sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
        setsockopt(*sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        
        if (connect(*sockfd, p->ai_addr, p->ai_addrlen) != -1) {
            freeaddrinfo(res);
            
            // Add new connection to cache
            set_cached_connection(host, port, *sockfd);
            if (g_config.debug) printf("[DEBUG] New connection successful to %s:%d (cached)\n", host, port);
            return 0;
        }
        
        if (g_config.debug) printf("[DEBUG] Connection failed to %s:%d: %s\n", host, port, strerror(errno));
        close(*sockfd);
    }
    
    freeaddrinfo(res);
    return -1;
}

int connect_with_fallback(const char *domain, int port, int *sockfd) {
    // First try direct connection to domain
    if (connect_to_server(domain, port, sockfd) == 0) {
        return 0;
    }
    
    // If domain connection fails, try resolving domain and use IP
    char *ip = resolve_domain(domain);
    if (ip) {
        if (connect_to_server(ip, port, sockfd) == 0) {
            free(ip);
            return 0;
        }
        free(ip);
    }
    
    // If resolution fails, try using known backup IP
    const char *known_ip = get_known_ip(domain);
    if (known_ip) {
        if (g_config.debug) printf("[DEBUG] Trying known IP %s for %s\n", known_ip, domain);
        if (connect_to_server(known_ip, port, sockfd) == 0) {
            return 0;
        }
    }
    
    return -1;
}

int send_query(int sockfd, const char *query) {
    char query_msg[256];
    snprintf(query_msg, sizeof(query_msg), "%s\r\n", query);
    int sent = send(sockfd, query_msg, strlen(query_msg), 0);
    if (g_config.debug) printf("[DEBUG] Sending query: %s (%d bytes)\n", query, sent);
    return sent;
}

char *receive_response(int sockfd) {
    if (g_config.debug) {
        printf("[DEBUG] Attempting to allocate response buffer of size %zu bytes\n", g_config.buffer_size);
    }
    
    // Check if buffer size exceeds reasonable limits
    if (g_config.buffer_size > 100 * 1024 * 1024) {
        if (g_config.debug) {
            printf("[WARNING] Requested buffer size is very large (%zu MB)\n", 
                   g_config.buffer_size / (1024 * 1024));
        }
    }
    
    char *buffer = malloc(g_config.buffer_size);
    if (!buffer) {
        // Detailed memory allocation error information
        fprintf(stderr, "Error: Failed to allocate %zu bytes for response buffer\n", g_config.buffer_size);
        fprintf(stderr, "       Reason: %s\n", strerror(errno));
        
        // Try allocating smaller buffer
        size_t fallback_size = 10 * 1024 * 1024; // 10MB
        if (g_config.debug) {
            printf("[WARNING] Trying fallback buffer size %zu bytes\n", fallback_size);
        }
        
        buffer = malloc(fallback_size);
        if (!buffer) {
            fprintf(stderr, "Error: Fallback allocation of %zu bytes also failed\n", fallback_size);
            fprintf(stderr, "       Reason: %s\n", strerror(errno));
            return NULL;
        }
        
        if (g_config.debug) {
            printf("[DEBUG] Using fallback buffer size %zu bytes\n", fallback_size);
        }
        g_config.buffer_size = fallback_size;
    }
    
    ssize_t total_bytes = 0;
    fd_set read_fds;
    struct timeval timeout;
    
    // Important improvement: keep reading until timeout, don't rely on double newline to exit early
    while (total_bytes < g_config.buffer_size - 1) {
        FD_ZERO(&read_fds);
        FD_SET(sockfd, &read_fds);
        timeout.tv_sec = g_config.timeout_sec;
        timeout.tv_usec = 0;
        
        int ready = select(sockfd + 1, &read_fds, NULL, NULL, &timeout);
        if (ready < 0) {
            if (g_config.debug) printf("[DEBUG] Select error after %zd bytes: %s\n", total_bytes, strerror(errno));
            break;
        } else if (ready == 0) {
            if (g_config.debug) printf("[DEBUG] Select timeout after %zd bytes\n", total_bytes);
            break;
        }
        
        ssize_t n = read(sockfd, buffer + total_bytes, g_config.buffer_size - total_bytes - 1);
        if (n < 0) {
            if (g_config.debug) printf("[DEBUG] Read error after %zd bytes: %s\n", total_bytes, strerror(errno));
            break;
        } else if (n == 0) {
            if (g_config.debug) printf("[DEBUG] Connection closed by peer after %zd bytes\n", total_bytes);
            break;
        }
        
        total_bytes += n;
        if (g_config.debug) printf("[DEBUG] Received %zd bytes, total %zd bytes\n", n, total_bytes);
        
        // Important improvement: don't exit early, ensure complete response is received
        // 只检查基本结束条件，但继续读取直到超时
        if (total_bytes > 1000) {
            // 检查是否已经收到完整的WHOIS响应
            if (strstr(buffer, "source:") || strstr(buffer, "person:") || 
                strstr(buffer, "inetnum:") || strstr(buffer, "NetRange:")) {
                // If contains key fields, can be considered complete response
                if (g_config.debug) printf("[DEBUG] Detected complete WHOIS response\n");
                // Even if complete response is detected, continue reading until timeout to ensure all data is received
            }
        }
    }

    if (total_bytes > 0) {
        buffer[total_bytes] = '\0';

        if (g_config.debug) {
            printf("[DEBUG] Response received successfully (%zd bytes)\n", total_bytes);
            printf("[DEBUG] ===== RESPONSE PREVIEW =====\n");
            printf("%.500s\n", buffer);
            if (total_bytes > 500) printf("... (truncated)\n");
            printf("[DEBUG] ===== END PREVIEW =====\n");
        }

        return buffer;
    }
    
    free(buffer);
    if (g_config.debug) printf("[DEBUG] No response received\n");
    return NULL;
}

//7. WHOIS协议处理函数实现
char *extract_refer_server(const char *response) {
    if (g_config.debug) printf("[DEBUG] ===== EXTRACTING REFER SERVER =====\n");
    
    // Check for invalid IPv4 response
    if (strstr(response, "0.0.0.0 - 255.255.255.255") != NULL) {
        if (g_config.debug) printf("[DEBUG] Invalid IPv4 response detected, redirecting to IANA\n");
        return strdup("whois.iana.org");
    }
    
    if (strstr(response, "0.0.0.0/0") != NULL) {
        if (g_config.debug) printf("[DEBUG] Invalid IPv4 response detected, redirecting to IANA\n");
        return strdup("whois.iana.org");
    }
    
    // New: check for invalid IPv6 response
    if (strstr(response, "::/0") != NULL) {
        if (g_config.debug) printf("[DEBUG] Invalid IPv6 response detected (::/0), redirecting to IANA\n");
        return strdup("whois.iana.org");
    }
    
    // Detection for IPv6 full range addresses
    if (strstr(response, "0:0:0:0:0:0:0:0") != NULL && (strstr(response, "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff") != NULL || strstr(response, "::") != NULL)) {
        if (g_config.debug) printf("[DEBUG] Invalid IPv6 response detected (full range), redirecting to IANA\n");
        return strdup("whois.iana.org");
    }
    
    // Check IANA default block
    if (strstr(response, "IANA-BLK") != NULL && strstr(response, "whole IPv4 address space") != NULL) {
        if (g_config.debug) printf("[DEBUG] Invalid response detected, redirecting to IANA\n");
        return strdup("whois.iana.org");
    }
    
    // Handle APNIC responses specifically
    if (strstr(response, "APNIC")) {
        const char *apnic_not_managed_patterns[] = {
            "not allocated to",
            "not registered in",
            "not managed by",
            "does not belong to",
            "is not assigned to",
            "This network range is not allocated to",
            "allocated by another Regional Internet Registry",
            "IP address block not managed by",
            NULL
        };
        
        int not_managed_by_apnic = 0;
        for (int i = 0; apnic_not_managed_patterns[i] != NULL; i++) {
            if (strstr(response, apnic_not_managed_patterns[i])) {
                not_managed_by_apnic = 1;
                if (g_config.debug) printf("[DEBUG] APNIC indicates IP is not managed by them: %s\n", apnic_not_managed_patterns[i]);
                break;
            }
        }
        
        if (not_managed_by_apnic) {
            // Try to extract suggested RIR
            const char *suggested_rirs[] = {
                "ARIN", "whois.arin.net",
                "RIPE", "whois.ripe.net",
                "LACNIC", "whois.lacnic.net",
                "AFRINIC", "whois.afrinic.net",
                NULL
            };
            
            for (int i = 0; suggested_rirs[i] != NULL; i += 2) {
                if (strstr(response, suggested_rirs[i])) {
                    if (g_config.debug) printf("[DEBUG] APNIC suggests querying %s (%s)\n", suggested_rirs[i+1], suggested_rirs[i]);
                    return strdup(suggested_rirs[i+1]);
                }
            }
            
            // If no specific RIR suggested, redirect to IANA by default
            if (g_config.debug) printf("[DEBUG] No specific RIR suggested by APNIC, redirecting to IANA\n");
            return strdup("whois.iana.org");
        }
    }
    
    // 原有的解析逻辑保持不变
    char *response_copy = strdup(response);
    if (!response_copy) {
        if (g_config.debug) printf("[DEBUG] Memory allocation failed for response copy\n");
        return NULL;
    }
    
    char *line = strtok(response_copy, "\n");
    char *whois_server = NULL;
    char *web_link = NULL;
    
    while (line != NULL) {
        // Skip empty lines and comment lines
        if (strlen(line) > 0 && line[0] != '#') {
            if (g_config.debug) printf("[DEBUG] Analyzing line: %s\n", line);
            
            // Find ReferralServer line (WHOIS protocol)
            char *pos = strstr(line, "ReferralServer:");
            if (pos) {
                pos += strlen("ReferralServer:");
                while (*pos == ' ' || *pos == '\t' || *pos == ':') pos++;
                
                if (strlen(pos) > 0) {
                    char *end = pos;
                    while (*end && *end != ' ' && *end != '\t' && *end != '\r' && *end != '\n') end++;
                    
                    size_t len = end - pos;
                    whois_server = malloc(len + 1);
                    strncpy(whois_server, pos, len);
                    whois_server[len] = '\0';
                    
                    // Clean up server name
                    char *p = whois_server + strlen(whois_server) - 1;
                    while (p >= whois_server && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '.' || *p == ',')) {
                        *p-- = '\0';
                    }
                    
                    // Handle whois:// prefix
                    if (strncmp(whois_server, "whois://", 8) == 0) {
                        memmove(whois_server, whois_server + 8, strlen(whois_server) - 7);
                    }
                    
                    if (g_config.debug) printf("[DEBUG] Found ReferralServer: %s\n", whois_server);
                }
            }
            
            // Find other WHOIS server indicators
            if (!whois_server) {
                pos = strstr(line, "whois:");
                if (pos) {
                    pos += strlen("whois:");
                    while (*pos == ' ' || *pos == '\t' || *pos == ':') pos++;
                    
                    if (strlen(pos) > 0) {
                        char *end = pos;
                        while (*end && *end != ' ' && *end != '\t' && *end != '\r' && *end != '\n') end++;
                        
                        size_t len = end - pos;
                        whois_server = malloc(len + 1);
                        strncpy(whois_server, pos, len);
                        whois_server[len] = '\0';
                        
                        if (g_config.debug) printf("[DEBUG] Found whois: directive: %s\n", whois_server);
                    }
                }
            }
        }
        line = strtok(NULL, "\n");
    }
    
    free(response_copy);
    
    // Return WHOIS server with priority
    if (whois_server && strchr(whois_server, '.') != NULL && strlen(whois_server) > 3) {
        if (g_config.debug) printf("[DEBUG] Extracted refer server: %s\n", whois_server);
        if (web_link) free(web_link);
        return whois_server;
    }
    
    // If no explicit server found but invalid response detected, redirect to IANA
    if (web_link) {
        free(web_link);
    }
    
    // If no explicit server found, infer from response content
    if (g_config.debug) printf("[DEBUG] No explicit refer server found, trying to infer from content\n");
    
    if (strstr(response, "APNIC") || strstr(response, "Asia Pacific") || strstr(response, "whois.apnic.net")) {
        if (g_config.debug) printf("[DEBUG] Inferred server: whois.apnic.net (APNIC)\n");
        return strdup("whois.apnic.net");
    } else if (strstr(response, "RIPE") || strstr(response, "Europe") || strstr(response, "Middle East") || strstr(response, "whois.ripe.net")) {
        if (g_config.debug) printf("[DEBUG] Inferred server: whois.ripe.net (RIPE)\n");
        return strdup("whois.ripe.net");
    } else if (strstr(response, "LAC") || strstr(response, "Latin America") || strstr(response, "Caribbean") || strstr(response, "whois.lacnic.net")) {
        if (g_config.debug) printf("[DEBUG] Inferred server: whois.lacnic.net (LACNIC)\n");
        return strdup("whois.lacnic.net");
    } else if (strstr(response, "AFRINIC") || strstr(response, "Africa") || strstr(response, "whois.afrinic.net")) {
        if (g_config.debug) printf("[DEBUG] Inferred server: whois.afrinic.net (AFRINIC)\n");
        return strdup("whois.afrinic.net");
    } else if (strstr(response, "ARIN") || strstr(response, "North America") || strstr(response, "whois.arin.net")) {
        if (g_config.debug) printf("[DEBUG] Inferred server: whois.arin.net (ARIN)\n");
        return strdup("whois.arin.net");
    }
    
    if (g_config.debug) printf("[DEBUG] No refer server found in response\n");
    return NULL;
}

int is_authoritative_response(const char *response) {
    if (g_config.debug) printf("[DEBUG] ===== CHECKING AUTHORITATIVE RESPONSE =====\n");
    
    const char *authoritative_indicators[] = {
        "inetnum:", "inet6num:", "netname:", "descr:", 
        "country:", "status:", "person:", "role:", "irt:", 
        "admin-c:", "tech-c:", "abuse-c:", "mnt-by:", 
        "mnt-irt:", "mnt-lower:", "mnt-routes:", "source:", 
        "last-modified:", "NetRange:", "CIDR:", "NetName:", 
        "NetHandle:", "NetType:", "Organization:", "OrgName:", 
        "OrgId:", "Address:", "City:", "StateProv:", "PostalCode:", 
        "Country:", "RegDate:", "Updated:", "Comment:", "Ref:", NULL
    };
    
    for (int i = 0; authoritative_indicators[i] != NULL; i++) {
        if (strstr(response, authoritative_indicators[i])) {
            if (g_config.debug) printf("[DEBUG] Authoritative indicator found: %s\n", authoritative_indicators[i]);
            return 1;
        }
    }
    
    if (g_config.debug) printf("[DEBUG] No authoritative indicators found\n");
    return 0;
}

int needs_redirect(const char *response) {
    if (g_config.debug) printf("[DEBUG] ===== CHECKING REDIRECT NEED =====\n");
    
    // Check for invalid IPv4 response
    if (strstr(response, "0.0.0.0 - 255.255.255.255") != NULL) {
        if (g_config.debug) printf("[DEBUG] Redirect flag found: Whole IPv4 address space returned\n");
        return 1;
    }
    
    if (strstr(response, "0.0.0.0/0") != NULL) {
        if (g_config.debug) printf("[DEBUG] Redirect flag found: Invalid IPv4 range 0.0.0.0/0\n");
        return 1;
    }
    
    // Check for invalid IPv6 response
    if (strstr(response, "::/0") != NULL) {
        if (g_config.debug) printf("[DEBUG] Redirect flag found: Invalid IPv6 range ::/0\n");
        return 1;
    }
    
    if (strstr(response, "0:0:0:0:0:0:0:0") != NULL && (strstr(response, "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff") != NULL || strstr(response, "::") != NULL)) {
        if (g_config.debug) printf("[DEBUG] Redirect flag found: Whole IPv6 address space returned\n");
        return 1;
    }
    
    // Check IANA default block
    if (strstr(response, "IANA-BLK") != NULL && strstr(response, "whole IPv4 address space") != NULL) {
        if (g_config.debug) printf("[DEBUG] Redirect flag found: IANA default block returned\n");
        return 1;
    }
    
    // Check APNIC specific response patterns
    const char *apnic_redirect_flags[] = {
        "not registered in the APNIC database",
        "This IP address range is not registered",
        "not allocated to APNIC",
        "allocated by another Regional Internet Registry",
        "This network range is not allocated to",
        "IP address block not managed by APNIC",
        NULL
    };
    
    for (int i = 0; apnic_redirect_flags[i] != NULL; i++) {
        if (strstr(response, apnic_redirect_flags[i])) {
            if (g_config.debug) printf("[DEBUG] APNIC redirect flag found: %s\n", apnic_redirect_flags[i]);
            return 1;
        }
    }
    
    // Check other common redirect flags
    const char *redirect_flags[] = {
        "not in database", "No match", "not found", "refer:", 
        "ReferralServer:", "whois:", "Whois Server:", 
        "This IP address range is not registered",
        "NON-RIPE-NCC-MANAGED-ADDRESS-BLOCK",
        "IP address block not managed by",
        "Allocated to", 
        "not registered in the",
        "Maintained by",
        "For more information, see",
        "For details, refer to",
        "See also",
        "Please query",
        "Query terms are ambiguous",
        NULL
    };
    
    for (int i = 0; redirect_flags[i] != NULL; i++) {
        if (strstr(response, redirect_flags[i])) {
            if (g_config.debug && i < 10) { // Only output first 10 matching flags
                printf("[DEBUG] Redirect flag found: %s\n", redirect_flags[i]);
            }
            return 1;
        }
    }
    
    // Finally check if it's an authoritative response
    if (!is_authoritative_response(response)) {
        if (g_config.debug) printf("[DEBUG] Response is not authoritative, needs redirect\n");
        return 1;
    }
    
    if (g_config.debug) printf("[DEBUG] No redirect needed\n");
    return 0;
}

char *perform_whois_query(const char *target, int port, const char *query) {
    int redirect_count = 0;
    char *current_target = strdup(target);
    int current_port = port;
    char *current_query = strdup(query);
    char *combined_result = NULL;
    const char *redirect_server = NULL;

    
    if (!current_target || !current_query) {
        if (g_config.debug) printf("[DEBUG] Memory allocation failed for query parameters\n");
        if (current_target) free(current_target);
        if (current_query) free(current_query);
        return NULL;
    }
    
    if (g_config.debug) printf("[DEBUG] Starting WHOIS query to %s:%d for %s\n", current_target, current_port, current_query);
    
    while (redirect_count <= MAX_REDIRECTS) {
        if (g_config.debug) printf("[DEBUG] ===== QUERY ATTEMPT %d =====\n", redirect_count + 1);
        if (g_config.debug) printf("[DEBUG] Current target: %s, Query: %s\n", current_target, current_query);
        
        // Execute query
        int sockfd = -1;
        int retry_count = 0;
        char *result = NULL;
        
        // Retry mechanism
        while (retry_count < g_config.max_retries) {
            if (g_config.debug) printf("[DEBUG] Query attempt %d/%d to %s\n", retry_count + 1, g_config.max_retries, current_target);
            
            if (connect_with_fallback(current_target, current_port, &sockfd) == 0) {
                if (send_query(sockfd, current_query) > 0) {
                    result = receive_response(sockfd);
                    close(sockfd);
                    sockfd = -1;
                    break;
                }
                close(sockfd);
                sockfd = -1;
            }
            
            retry_count++;
            usleep(300000); // 300ms delay before retry
        }
        
        if (result == NULL) {
            if (g_config.debug) printf("[DEBUG] Query failed to %s after %d attempts\n", current_target, g_config.max_retries);
            
            // If this is the first query, return error
            if (redirect_count == 0) {
                free(current_target);
                free(current_query);
                if (combined_result) free(combined_result);
                return NULL;
            }
            
            // If not the first, return collected results
            break;
        }
        
        // Check if redirect is needed
        if (needs_redirect(result)) {
            if (g_config.debug) printf("[DEBUG] ==== REDIRECT REQUIRED ====\n");
            redirect_server = extract_refer_server(result);
            
            if (redirect_server) {
                if (g_config.debug) printf("[DEBUG] Redirecting to: %s\n", redirect_server);
                
                // Check if redirecting to same server
                if (strcmp(redirect_server, current_target) == 0) {
                    if (g_config.debug) printf("[DEBUG] Redirect server same as current target, stopping redirect\n");
                    free((void*)redirect_server);
                    redirect_server = NULL;
                    
                    // Add current result to final result
                    if (combined_result == NULL) {
                        combined_result = result;
                    } else {
                        size_t new_len = strlen(combined_result) + strlen(result) + 100;
                        char *new_combined = malloc(new_len);
                        if (new_combined) {
                            snprintf(new_combined, new_len, "%s\n=== Additional query to %s ===\n%s",
                                     combined_result, current_target, result);
                            free(combined_result);
                            free(result);
                            combined_result = new_combined;
                        } else {
                            free(result);
                        }
                    }
                    break;
                }
                
                // Save current result
                if (combined_result == NULL) {
                    combined_result = result;
                } else {
                    size_t new_len = strlen(combined_result) + strlen(result) + 100;
                    char *new_combined = malloc(new_len);
                    if (new_combined) {
                        snprintf(new_combined, new_len, "%s\n=== Redirected query to %s ===\n%s",
                                 combined_result, current_target, result);
                        free(combined_result);
                        free(result);
                        combined_result = new_combined;
                    } else {
                        free(result); // Ensure memory is freed
                    }
                }
                
                // Prepare for next query
                free(current_target);
                current_target = strdup(redirect_server);
                free((void*)redirect_server);
                redirect_server = NULL;
                
                if (!current_target) {
                    if (g_config.debug) printf("[DEBUG] Memory allocation failed for redirect target\n");
                    break;
                }
                
                redirect_count++;
                continue;
            } else {
                if (g_config.debug) printf("[DEBUG] No redirect server found, stopping redirect\n");
                if (combined_result == NULL) {
                    combined_result = result;
                } else {
                    size_t new_len = strlen(combined_result) + strlen(result) + 100;
                    char *new_combined = malloc(new_len);
                    if (new_combined) {
                        snprintf(new_combined, new_len, "%s\n=== Final query to %s ===\n%s",
                                 combined_result, current_target, result);
                        free(combined_result);
                        free(result);
                        combined_result = new_combined;
                    } else {
                        free(result);
                    }
                }
                break;
            }
        } else {
            if (g_config.debug) printf("[DEBUG] No redirect needed, returning result\n");
            if (combined_result == NULL) {
                combined_result = result;
            } else {
                size_t new_len = strlen(combined_result) + strlen(result) + 100;
                char *new_combined = malloc(new_len);
                if (new_combined) {
                    snprintf(new_combined, new_len, "%s\n=== Final query to %s ===\n%s",
                             combined_result, current_target, result);
                    free(combined_result);
                    free(result);
                    combined_result = new_combined;
                } else {
                    free(result);
                }
            }
            break;
        }
    }
    
    if (redirect_count > MAX_REDIRECTS) {
        if (g_config.debug) printf("[DEBUG] Maximum redirects reached (%d)\n", MAX_REDIRECTS);
        
        // Add warning message
        if (combined_result) {
            size_t new_len = strlen(combined_result) + 200;
            char *new_result = malloc(new_len);
            if (new_result) {
                snprintf(new_result, new_len, "Warning: Maximum redirects reached (%d).\n"
                         "You may need to manually query the final server for complete information.\n\n%s",
                         MAX_REDIRECTS, combined_result);
                free(combined_result);
                combined_result = new_result;
            }
        }
    }
    
    // Cleanup resources
    if (redirect_server) free((void*)redirect_server);
    free(current_target);
    free(current_query);
    
    return combined_result;
}

char *get_server_target(const char *server_input) {
    struct in_addr addr4;
    struct in6_addr addr6;
    
    // Check if it's an IP address
    if (inet_pton(AF_INET, server_input, &addr4) == 1) {
        return strdup(server_input);
    }
    if (inet_pton(AF_INET6, server_input, &addr6) == 1) {
        return strdup(server_input);
    }
    
    // Check if it's a known server name
    for (int i = 0; servers[i].name != NULL; i++) {
        if (strcmp(server_input, servers[i].name) == 0) {
            return strdup(servers[i].domain);
        }
    }
    
    // Check if it's domain format
    if (strchr(server_input, '.') != NULL || strchr(server_input, ':') != NULL) {
        return strdup(server_input);
    }
    
    return NULL;
}

int main(int argc, char *argv[]) {
    // 1. Parse command line arguments
    const char *server_host = NULL;
    int port = g_config.whois_port;
    int show_help = 0, show_version = 0, show_servers = 0;
    
    // Extended command line options
    static struct option long_options[] = {
        {"host", required_argument, 0, 'h'},
        {"port", required_argument, 0, 'p'},
        {"buffer-size", required_argument, 0, 'b'},
        {"retries", required_argument, 0, 'r'},
        {"timeout", required_argument, 0, 't'},
        {"dns-cache", required_argument, 0, 'd'},
        {"conn-cache", required_argument, 0, 'c'},
        {"cache-timeout", required_argument, 0, 'T'},
        {"debug", no_argument, 0, 'D'},
        {"list", no_argument, 0, 'l'},
        {"version", no_argument, 0, 'v'},
        {"help", no_argument, 0, 'H'},
        {0, 0, 0, 0}
    };
        
    int opt;
    int option_index = 0;

    // Parse command line arguments
    while ((opt = getopt_long(argc, argv, "h:p:b:r:t:d:c:T:DlvH", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'h': server_host = optarg; break;
            case 'p': 
                port = atoi(optarg);
                if (port <= 0 || port > 65535) {
                    fprintf(stderr, "Error: Invalid port number\n");
                    return 1;
                }
                break;
            case 'b': 
                {
                    size_t new_size = parse_size_with_unit(optarg);
                    if (new_size == 0) {
                        fprintf(stderr, "Error: Invalid buffer size '%s'\n", optarg);
                        fprintf(stderr, "       Valid formats: 1024, 1K, 1M, 1G\n");
                        return 1;
                    }
            
                    // Set reasonable upper limit (e.g. 1GB)
                    if (new_size > 1024 * 1024 * 1024) {
                        fprintf(stderr, "Warning: Buffer size capped at 1GB\n");
                        new_size = 1024 * 1024 * 1024;
                    }
                
                    // Check minimum value
                    if (new_size < 1024) {
                        fprintf(stderr, "Warning: Buffer size increased to minimum of 1KB\n");
                        new_size = 1024;
                    }
            
                    g_config.buffer_size = new_size;
                    if (g_config.debug) printf("[DEBUG] Set buffer size to %zu bytes\n", g_config.buffer_size);
                }
                break;
            case 'r': 
                g_config.max_retries = atoi(optarg);
                if (g_config.max_retries < 0) {
                    fprintf(stderr, "Error: Invalid retry count\n");
                    return 1;
                }
                break;
            case 't': 
                g_config.timeout_sec = atoi(optarg);
                if (g_config.timeout_sec <= 0) {
                    fprintf(stderr, "Error: Invalid timeout value\n");
                    return 1;
                }
                break;
            case 'd': 
                g_config.dns_cache_size = atoi(optarg);
                if (g_config.dns_cache_size <= 0) {
                    fprintf(stderr, "Error: Invalid DNS cache size\n");
                    return 1;
                }
                if (g_config.dns_cache_size > 20) {
                    fprintf(stderr, "Warning: DNS cache size capped at 20\n");
                    g_config.dns_cache_size = 20;
                }
                break;
            case 'c': 
                g_config.connection_cache_size = atoi(optarg);
                if (g_config.connection_cache_size <= 0) {
                    fprintf(stderr, "Error: Invalid connection cache size\n");
                    return 1;
                }
                if (g_config.connection_cache_size > 10) {
                    fprintf(stderr, "Warning: Connection cache size capped at 10\n");
                    g_config.connection_cache_size = 10;
                }
                break;
            case 'T': 
                g_config.cache_timeout = atoi(optarg);
                if (g_config.cache_timeout <= 0) {
                    fprintf(stderr, "Error: Invalid cache timeout\n");
                    return 1;
                }
                break;
            case 'D': g_config.debug = 1; break;
            case 'l': show_servers = 1; break;
            case 'v': show_version = 1; break;
            case 'H': show_help = 1; break;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }

    // Validate configuration
    if (!validate_config()) {
        return 1;
    }

    // Check if cache sizes are reasonable
    if (!validate_cache_sizes()) {
        fprintf(stderr, "Error: Invalid cache sizes, using defaults\n");
        g_config.dns_cache_size = DNS_CACHE_SIZE;
        g_config.connection_cache_size = CONNECTION_CACHE_SIZE;
    }

    if (g_config.debug) printf("[DEBUG] Parsed command line arguments\n");
    if (g_config.debug) {
        printf("[DEBUG] Final configuration:\n");
        printf("        Buffer size: %zu bytes\n", g_config.buffer_size);
        printf("        DNS cache size: %zu entries\n", g_config.dns_cache_size);
        printf("        Connection cache size: %zu entries\n", g_config.connection_cache_size);
        printf("        Timeout: %d seconds\n", g_config.timeout_sec);
        printf("        Max retries: %d\n", g_config.max_retries);
    }
        
    // 2. Handle display options (help, version, server list)
    if (show_help) { 
        print_usage(argv[0]); 
        return 0; 
    }
    if (show_version) { 
        print_version(); 
        return 0; 
    }
    if (show_servers) { 
        print_servers(); 
        return 0; 
    }
    
    // 3. Validate arguments
    if (optind >= argc) {
        fprintf(stderr, "Error: Missing query argument\n");
        print_usage(argv[0]);
        return 1;
    }
    
    const char *query = argv[optind];
    
    // Check if it's a private IP address
    if (is_private_ip(query)) {
        printf("%s is a private IP address\n", query);
        return 0;
    }

    // 4. Initialize caches now (using final configuration values)
    if (g_config.debug) printf("[DEBUG] Initializing caches with final configuration...\n");
    init_caches();
    atexit(cleanup_caches);
    
    if (g_config.debug) printf("[DEBUG] Caches initialized successfully\n");
    
    // 5. Continue with main logic...
    char *target = NULL;
    if (server_host) {
        // Get specified server target
        target = get_server_target(server_host);
        if (!target) {
            fprintf(stderr, "Error: Unknown server '%s'\n", server_host);
            cleanup_caches();
            return 1;
        }
    } else {
        // Use IANA as default starting query point
        target = strdup("whois.iana.org");
        if (!target) {
            fprintf(stderr, "Error: Memory allocation failed for default target\n");
            cleanup_caches();
            return 1;
        }
    }
    
    if (g_config.debug) printf("[DEBUG] ===== MAIN QUERY START =====\n");
    if (g_config.debug) printf("[DEBUG] Final target: %s, Query: %s\n", target, query);
    
    // 6. Execute query
    // Execute WHOIS query
    char *result = perform_whois_query(target, port, query);
    free(target);
    
    if (result) {
        printf("%s", result);
        free(result);
    } else {
        fprintf(stderr, "Error: Query failed for %s\n", query);
        cleanup_caches();
        return 1;
    }


    return 0;
}

