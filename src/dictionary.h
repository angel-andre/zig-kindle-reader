#ifndef ZR_DICTIONARY_H
#define ZR_DICTIONARY_H
int zrd_open(const char *path);
void zrd_close(void);
/* Returns definition UTF-8 byte length, 0 = unknown word, -1 = unavailable.
 * Normalized lemma is returned separately; lookup uses no network and writes no files. */
int zrd_define(const char *word, int len, char *lemma, int lemma_cap, char *out, int out_cap);
#endif
