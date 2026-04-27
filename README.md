# Regular Expression for Zig

Zig library for regular expressions, built upon PCRE2 and RE2, exposing both as modules, not just as bindings but also conventional Zig APIs.

## Testing

```bash
zig build tests
```

Integration tests live under `tests/` (`suite.zig` pulls in `pcre2.zig` and `re2.zig`).

**PCRE2 width:** each binary is built for one code unit width. To cover 8 / 16 / 32 in CI, run e.g.:

```bash
zig build tests -Dpcre2-width=8
zig build tests -Dpcre2-width=16
zig build tests -Dpcre2-width=32
```

**PCRE2 JIT:** also run with `-Dpcre2-jit=false` if you want to assert behavior without JIT.

**RE2:** optional `-Dre2-icu=true` sets a Zig flag for future `RE2_USE_ICU`; the C++ library is unchanged until ICU is linked in `re2.build.zig`.

## Credits

- <https://github.com/PCRE2Project/pcre2>
- <https://github.com/abseil/abseil-cpp>
- <https://github.com/google/re2>
- <https://github.com/akunaakwei/zig-abseil>

## License

Check the license file.
