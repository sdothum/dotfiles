#include <check.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>

/* 
 * We simulate the vulnerable pattern from ruler.c:
 * sprintf(str, "%s", atom_name);
 * sprintf(str + slen, ",%s", atom_name);
 *
 * The invariant: buffer reads/writes must never exceed the declared buffer size.
 * We implement a safe version and verify that the safe version handles
 * oversized inputs correctly (truncation or rejection), and that the
 * buffer boundary is never exceeded.
 */

#define SAFE_BUFFER_SIZE 256

/* 
 * Safe formatting function that mimics what ruler.c should do.
 * Returns 0 on success, -1 if input would overflow.
 */
static int safe_format_atom(char *buf, size_t buf_size, const char *atom_name) {
    if (!buf || !atom_name || buf_size == 0) return -1;
    
    size_t name_len = strlen(atom_name);
    if (name_len >= buf_size) {
        /* Would overflow - reject */
        return -1;
    }
    
    int ret = snprintf(buf, buf_size, "%s", atom_name);
    if (ret < 0 || (size_t)ret >= buf_size) {
        buf[0] = '\0';
        return -1;
    }
    return 0;
}

static int safe_append_atom(char *buf, size_t buf_size, const char *atom_name) {
    if (!buf || !atom_name || buf_size == 0) return -1;
    
    size_t current_len = strlen(buf);
    size_t name_len = strlen(atom_name);
    
    /* Check: current_len + 1 (comma) + name_len + 1 (null) <= buf_size */
    if (current_len + 1 + name_len + 1 > buf_size) {
        return -1;
    }
    
    int ret = snprintf(buf + current_len, buf_size - current_len, ",%s", atom_name);
    if (ret < 0 || (size_t)ret >= buf_size - current_len) {
        buf[current_len] = '\0';
        return -1;
    }
    return 0;
}

/* 
 * Canary-protected buffer structure to detect overflows.
 */
#define CANARY_VALUE 0xDEADBEEF
#define CANARY_SIZE  8

typedef struct {
    uint32_t pre_canary[CANARY_SIZE];
    char     buffer[SAFE_BUFFER_SIZE];
    uint32_t post_canary[CANARY_SIZE];
} protected_buffer_t;

static void init_protected_buffer(protected_buffer_t *pb) {
    for (int i = 0; i < CANARY_SIZE; i++) {
        pb->pre_canary[i]  = CANARY_VALUE;
        pb->post_canary[i] = CANARY_VALUE;
    }
    memset(pb->buffer, 0, SAFE_BUFFER_SIZE);
}

static int check_canaries(const protected_buffer_t *pb) {
    for (int i = 0; i < CANARY_SIZE; i++) {
        if (pb->pre_canary[i]  != CANARY_VALUE) return 0;
        if (pb->post_canary[i] != CANARY_VALUE) return 0;
    }
    return 1;
}

START_TEST(test_buffer_reads_never_exceed_declared_length)
{
    /* Invariant: Buffer reads/writes must never exceed SAFE_BUFFER_SIZE bytes.
     * Any atom name that would cause an overflow must be rejected or truncated,
     * and canary values surrounding the buffer must remain intact.
     */
    const char *payloads[] = {
        /* Normal inputs */
        "ATOM_NAME",
        "_NET_WM_STATE",
        "",
        /* Boundary inputs */
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",  /* 64 bytes */
        /* 2x buffer size (512 bytes) */
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
        /* 10x buffer size (2560 bytes) */
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC",
        /* Exactly buffer size - 1 (255 bytes) */
        "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
        "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
        "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
        "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD",
        /* Exactly buffer size (256 bytes) - should be rejected */
        "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"
        "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"
        "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"
        "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE",
        /* Attack payloads with special characters */
        "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",
        "%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n%n",
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",
        /* Null-like and whitespace */
        "   ",
        "\t\n\r",
        /* Single char */
        "A",
    };
    int num_payloads = sizeof(payloads) / sizeof(payloads[0]);

    for (int i = 0; i < num_payloads; i++) {
        protected_buffer_t pb;
        init_protected_buffer(&pb);

        const char *atom_name = payloads[i];
        int result = safe_format_atom(pb.buffer, SAFE_BUFFER_SIZE, atom_name);

        /* Canaries must be intact regardless of input */
        ck_assert_msg(check_canaries(&pb),
            "Canary corruption detected after safe_format_atom with payload index %d", i);

        /* Buffer must be null-terminated within bounds */
        int null_found = 0;
        for (size_t j = 0; j < SAFE_BUFFER_SIZE; j++) {
            if (pb.buffer[j] == '\0') {
                null_found = 1;
                break;
            }
        }
        ck_assert_msg(null_found,
            "Buffer not null-terminated within bounds for payload index %d", i);

        /* If format succeeded, the result length must be within buffer */
        if (result == 0) {
            size_t written_len = strlen(pb.buffer);
            ck_assert_msg(written_len < SAFE_BUFFER_SIZE,
                "Written length %zu exceeds buffer size %d for payload index %d",
                written_len, SAFE_BUFFER_SIZE, i);
        }

        /* Test append operation: fill buffer partially then try to append */
        init_protected_buffer(&pb);
        /* First, write a short known-good atom */
        safe_format_atom(pb.buffer, SAFE_BUFFER