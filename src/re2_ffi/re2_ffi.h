/*
 * Minimal C API for Google RE2. For use by Zig only.
 * Implemented in re2_ffi.cpp; link with -lre2 (system RE2 + Abseil).
 */
#ifndef RE2_FFI_H
#define RE2_FFI_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

typedef struct re2_regexp re2_regexp_t;

/* Options: 0 = default (UTF-8). No options struct for minimal API. */
re2_regexp_t *re2_new(const char *pattern, size_t pattern_len);
void re2_delete(re2_regexp_t *re);

/* 1 = ok, 0 = compile error */
int re2_ok(re2_regexp_t *re);
int re2_error_code(re2_regexp_t *re);
/* Error message (static buffer, do not free). Empty if ok. */
const char *re2_error_string(re2_regexp_t *re);

/* Match: text[start..end). anchor: 0=unanchored, 1=anchor start, 2=anchor both.
 * match_begin[i], match_end[i] filled for i in [0, nmatch). Returns 1 if match, 0 if no match. */
int re2_match(re2_regexp_t *re, const char *text, size_t text_len,
              size_t start, size_t end, int anchor,
              size_t *match_begin, size_t *match_end, int nmatch);

/* Replace: subject in, rewrite string. replace_all: 0=first only, 1=global.
 * Caller provides out_buf and *out_len (capacity). On success *out_len = written length.
 * Returns 1 on success, 0 no match (single) or error, -1 buffer too small (*out_len set to required). */
int re2_replace(re2_regexp_t *re, const char *subject, size_t subject_len,
                const char *rewrite, size_t rewrite_len, int replace_all,
                char *out_buf, size_t *out_len);

#ifdef __cplusplus
}
#endif

#endif
