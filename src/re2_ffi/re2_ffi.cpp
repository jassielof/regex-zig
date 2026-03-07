/*
 * Minimal C API for Google RE2. Implemented in C++ and linked with RE2.
 * Requires system RE2 (and Abseil): e.g. vcpkg install re2, or apt install libre2-dev.
 */
#include "re2_ffi.h"
#include <re2/re2.h>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

struct re2_regexp {
    RE2 re;
    re2_regexp(const char* pattern, size_t len)
        : re(re2::StringPiece(pattern, len)) {}
};

re2_regexp* re2_new(const char* pattern, size_t pattern_len) {
    if (!pattern && pattern_len != 0) return nullptr;
    try {
        return new re2_regexp(pattern ? pattern : "", pattern_len);
    } catch (...) {
        return nullptr;
    }
}

void re2_delete(re2_regexp* re) {
    delete re;
}

int re2_ok(re2_regexp* re) {
    return re && re->re.ok() ? 1 : 0;
}

int re2_error_code(re2_regexp* re) {
    return re ? static_cast<int>(re->re.error_code()) : 0;
}

const char* re2_error_string(re2_regexp* re) {
    if (!re) return "";
    const std::string& e = re->re.error();
    return e.empty() ? "" : re->re.error().c_str();
}

static RE2::Anchor to_anchor(int anchor) {
    switch (anchor) {
        case 1: return RE2::ANCHOR_START;
        case 2: return RE2::ANCHOR_BOTH;
        default: return RE2::UNANCHORED;
    }
}

int re2_match(re2_regexp* re, const char* text, size_t text_len,
              size_t start, size_t end, int anchor,
              size_t* match_begin, size_t* match_end, int nmatch) {
    if (!re || !text || !match_begin || !match_end || nmatch < 0) return 0;
    re2::StringPiece sp(text, text_len);
    if (end > text_len) end = text_len;
    if (start > end) return 0;
    std::vector<re2::StringPiece> sub(nmatch);
    bool ok = re->re.Match(sp, start, end, to_anchor(anchor), sub.data(), nmatch);
    if (!ok) return 0;
    const char* base = text;
    for (int i = 0; i < nmatch; i++) {
        if (sub[i].data()) {
            match_begin[i] = static_cast<size_t>(sub[i].data() - base);
            match_end[i] = match_begin[i] + sub[i].size();
        } else {
            match_begin[i] = static_cast<size_t>(-1);
            match_end[i] = static_cast<size_t>(-1);
        }
    }
    return 1;
}

int re2_replace(re2_regexp* re, const char* subject, size_t subject_len,
                const char* rewrite, size_t rewrite_len, int replace_all,
                char* out_buf, size_t* out_len) {
    if (!re || !subject || !rewrite || !out_len) return -1;
    std::string s(subject, subject_len);
    re2::StringPiece rw(rewrite, rewrite_len);
    if (replace_all) {
        int n = RE2::GlobalReplace(&s, re->re, rw);
        if (n == 0 && re->re.Match(re2::StringPiece(subject, subject_len), 0, subject_len, RE2::UNANCHORED, nullptr, 0))
            return 0; /* no replacement but matched (shouldn't happen) */
        if (n < 0) return 0;
    } else {
        if (!RE2::Replace(&s, re->re, rw)) return 0;
    }
    size_t need = s.size();
    if (out_buf && *out_len >= need) {
        s.copy(out_buf, need);
        *out_len = need;
        return 1;
    }
    *out_len = need;
    return -1; /* buffer too small */
}
