/*
 * NTLM-disabled stub backend.
 *
 * Compiled only when `CRYPT_DISABLED` is defined. Every entry point
 * returns failure — NTLM auth on this platform is intentionally
 * unsupported. See `crypt_disabled.h` for the rationale.
 */

#include "ntlmclient.h"
#include "ntlm.h"
#include "crypt.h"

#ifdef CRYPT_DISABLED

bool ntlm_crypt_init(ntlm_client *ntlm)
{
	(void)ntlm;
	return true;
}

bool ntlm_random_bytes(
	unsigned char *out,
	ntlm_client *ntlm,
	size_t len)
{
	(void)out; (void)ntlm; (void)len;
	return false;
}

bool ntlm_des_encrypt(
	ntlm_des_block *out,
	ntlm_client *ntlm,
	ntlm_des_block *plaintext,
	ntlm_des_block *key)
{
	(void)out; (void)ntlm; (void)plaintext; (void)key;
	return false;
}

bool ntlm_md4_digest(
	unsigned char out[CRYPT_MD4_DIGESTSIZE],
	ntlm_client *ntlm,
	const unsigned char *in,
	size_t in_len)
{
	(void)out; (void)ntlm; (void)in; (void)in_len;
	return false;
}

bool ntlm_hmac_md5_init(
	ntlm_client *ntlm,
	const unsigned char *key,
	size_t key_len)
{
	(void)ntlm; (void)key; (void)key_len;
	return false;
}

bool ntlm_hmac_md5_update(
	ntlm_client *ntlm,
	const unsigned char *data,
	size_t data_len)
{
	(void)ntlm; (void)data; (void)data_len;
	return false;
}

bool ntlm_hmac_md5_final(
	unsigned char *out,
	size_t *out_len,
	ntlm_client *ntlm)
{
	(void)out; (void)out_len; (void)ntlm;
	return false;
}

void ntlm_crypt_shutdown(ntlm_client *ntlm)
{
	(void)ntlm;
}

#endif /* CRYPT_DISABLED */
