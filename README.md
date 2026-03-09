# Regular Expression for Zig

Zig library for regular expressions, exposing both PCRE2 and RE2 as modules, not just as bindings but also conventional Zig APIs.

## Regarding RE2

RE2 is desired to have, but it's quite complex to get it working, considering it's a C++ library plus the fact that it depends on an even larger C++ library (Abseil), which I'm not really willing to spend time on, I have somewhat just put it as disabled for now, but if someone is willing to help to get it working, then it would be very much appreciated.

The main strategy I would get to it, is:

- Adding another git submodule for Abseil
- Getting its tag the same required by RE2
- Using Zig as the build system for RE2 and Abseil (instead of CMake)
- Adding the necessary C bindings for RE2 and Abseil
- Setting up the C interop for RE2
- And that should be it.

## License

Check the license file.
