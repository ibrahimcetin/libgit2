/*
 * NTLM-disabled stub backend.
 *
 * Provides the `ntlm_crypt_ctx` struct that `ntlm.h` embeds. The real
 * `ntlm_*` symbols are stubbed out in `crypt_disabled.c` and always
 * return failure — they're only reachable when callers explicitly
 * request NTLM authentication, which doesn't happen in our consumers.
 *
 * We need this arm because the SwiftPM build always compiles
 * `deps/ntlmclient`, but on platforms without OpenSSL / mbedTLS /
 * CommonCrypto headers (e.g. Bionic / Android NDK without an OpenSSL
 * fork) the original CRYPT_* arms hit unavailable system headers.
 */

#ifndef PRIVATE_CRYPT_DISABLED_H__
#define PRIVATE_CRYPT_DISABLED_H__

#include <stdint.h>

typedef struct {
	int placeholder;
} ntlm_hmac_ctx;

struct ntlm_crypt_ctx {
	ntlm_hmac_ctx hmac;
};

#endif /* PRIVATE_CRYPT_DISABLED_H__ */
