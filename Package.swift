// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// =============================================================================
// PLATFORM CONFIGURATION
// =============================================================================
//
// libgit2 requires different configurations for different platforms due to:
// - Different TLS/SSL backends (SecureTransport on Apple, OpenSSL on Linux,
//   WinHTTP on Windows, none on Android)
// - Different hash implementations (CommonCrypto on Apple, builtin on
//   Linux/Android, Win32 BCrypt on Windows)
// - Different system library availability and source layouts
//   (`src/util/unix/*` on Apple/Linux/Android vs `src/util/win32/*` on Windows)
//
// =============================================================================

// =============================================================================
// PLATFORM-SPECIFIC CONFIGURATION
// =============================================================================

// Always-excluded files (CMake build-system files, OS-irrelevant headers).
var excludedPaths: [String] = [
	// CMake and build system files
	"deps/llhttp/CMakeLists.txt",
	"deps/llhttp/LICENSE-MIT",
	"deps/pcre/CMakeLists.txt",
	"deps/pcre/COPYING",
	"deps/pcre/LICENCE",
	"deps/pcre/cmake/",
	"deps/pcre/config.h.in",
	"deps/xdiff/CMakeLists.txt",
	"deps/zlib/CMakeLists.txt",
	"deps/zlib/LICENSE",
	"deps/ntlmclient/CMakeLists.txt",
	"src/libgit2/CMakeLists.txt",
	"src/libgit2/experimental.h.in",
	"src/libgit2/git2.rc",
	"src/libgit2/config.cmake.in",
	"src/util/CMakeLists.txt",
	"src/util/git2_features.h.in",

	// mbedTLS backend (not used on any of our platforms — Apple/Linux/Windows
	// have native HTTPS and Android disables HTTPS for now).
	"src/util/hash/mbedtls.c",
	"src/util/hash/mbedtls.h",
	"deps/ntlmclient/crypt_mbedtls.c",
	"deps/ntlmclient/crypt_mbedtls.h",
	// crypt_builtin_md4.c is only used with mbedTLS backend
	"deps/ntlmclient/crypt_builtin_md4.c",

	// Unicode iconv backend - we use UNICODE_BUILTIN instead
	"deps/ntlmclient/unicode_iconv.c",
	"deps/ntlmclient/unicode_iconv.h",
]

// Cross-platform C settings shared by every host arm.
var cSettings: [CSetting] = [
	// Header search paths
	.headerSearchPath("deps/llhttp"),
	.headerSearchPath("deps/pcre"),
	.headerSearchPath("deps/xdiff"),
	.headerSearchPath("deps/zlib"),
	.headerSearchPath("deps/ntlmclient"),
	.headerSearchPath("src/libgit2"),
	.headerSearchPath("src/util"),

	// Core configuration
	.define("LIBGIT2_NO_FEATURES_H"),
	.define("GIT_THREADS", to: "1"),
	.define("GIT_THREADS_PTHREADS", to: "1",
	        .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux, .android])),
	.define("GIT_ARCH_64", to: "1"),

	// PCRE regex configuration (builtin)
	.define("GIT_REGEX_BUILTIN", to: "1"),
	.define("SUPPORT_PCRE8", to: "1"),
	.define("HAVE_STDINT_H", to: "1"),
	.define("HAVE_INTTYPES_H", to: "1"),
	.define("HAVE_MEMMOVE", to: "1"),
	.define("HAVE_STRERROR", to: "1"),
	.define("LINK_SIZE", to: "2"),
	.define("PARENS_NEST_LIMIT", to: "250"),
	.define("MATCH_LIMIT", to: "10000000"),
	.define("MATCH_LIMIT_RECURSION", to: "10000000"),
	.define("NEWLINE", to: "10"),  // LF
	.define("NO_RECURSE", to: "1"),
	.define("POSIX_MALLOC_THRESHOLD", to: "10"),
	.define("BSR_ANYCRLF", to: "0"),
	.define("MAX_NAME_SIZE", to: "32"),
	.define("MAX_NAME_COUNT", to: "10000"),

	// SSH transport (exec-based, uses system ssh command).
	// Not enabled on Windows (no system ssh on stock Windows) or Android.
	.define("GIT_SSH", to: "1", .when(platforms: [.macOS, .iOS, .linux])),
	.define("GIT_SSH_EXEC", to: "1", .when(platforms: [.macOS, .iOS, .linux])),

	// HTTP request parser (always builtin — llhttp).
	.define("GIT_HTTPPARSER_BUILTIN", to: "1"),

	// HTTPS gate. Enabled everywhere except Android (no available backend
	// in the swift-android toolchain right now). Backend choice
	// (`GIT_HTTPS_*`) lives in the per-host arms below.
	.define("GIT_HTTPS", to: "1",
	        .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux, .windows])),

	// I/O configuration
	.define("GIT_IO_POLL", to: "1",
	        .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux, .android])),
	.define("GIT_IO_SELECT", to: "1", .when(platforms: [.windows])),

	// Nanosecond timestamp support
	.define("GIT_NSEC", to: "1"),
	.define("GIT_FUTIMENS", to: "1",
	        .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .linux, .android])),

	// NTLM authentication (builtin)
	.define("GIT_AUTH_NTLM", to: "1"),
	.define("GIT_AUTH_NTLM_BUILTIN", to: "1"),
	.define("NTLM_STATIC", to: "1"),
	.define("UNICODE_BUILTIN", to: "1"),

	// Compression (builtin zlib)
	.define("GIT_COMPRESSION_BUILTIN", to: "1"),
]

// Linker settings, populated per-host below.
var linkerSettings: [LinkerSetting] = []

// =============================================================================
// HOST DISPATCH
// =============================================================================
//
// `#if os(...)` here is evaluated when SwiftPM resolves this manifest on
// the *build host*. We use it to pick the source-exclusion set, then use
// `.when(platforms:)` on individual cSettings/linkerSettings to refine
// behaviour for each *target* platform within that host's reachable set.
//
// - macOS host: builds Apple-family targets (macOS/iOS/tvOS/watchOS).
// - Linux host: builds Linux + cross-compiled Android targets.
// - Windows host: builds Windows targets.
//
// =============================================================================

#if os(macOS)
	// Apple host → builds Apple-family targets.
	excludedPaths += [
		// Windows-specific files (never used on Unix-like systems)
		"src/util/hash/win32.c",
		"src/util/hash/win32.h",
		"src/util/win32",

		// Builtin SHA1 (collision detection) - not used on Apple, we use CommonCrypto
		"src/util/hash/builtin.c",
		"src/util/hash/builtin.h",
		"src/util/hash/collisiondetect.c",
		"src/util/hash/collisiondetect.h",
		"src/util/hash/rfc6234",
		"src/util/hash/sha1dc",

		// OpenSSL hash backend - not used on Apple
		"src/util/hash/openssl.c",
		"src/util/hash/openssl.h",

		// OpenSSL NTLM crypto - not used on Apple
		"deps/ntlmclient/crypt_openssl.c",
		"deps/ntlmclient/crypt_openssl.h",
	]

	cSettings += [
		// qsort variant (BSD-style on Apple)
		.define("GIT_QSORT_BSD"),

		// HTTPS via SecureTransport
		.define("GIT_HTTPS_SECURETRANSPORT", to: "1"),

		// Hash implementations via CommonCrypto
		.define("GIT_SHA1_COMMON_CRYPTO", to: "1"),
		.define("GIT_SHA256_COMMON_CRYPTO", to: "1"),

		// NTLM crypto via CommonCrypto
		.define("CRYPT_COMMONCRYPTO"),

		// Nanosecond support via mtimespec (Apple-style)
		.define("GIT_NSEC_MTIMESPEC", to: "1"),

		// Internationalization via iconv
		.define("GIT_I18N", to: "1"),
		.define("GIT_I18N_ICONV", to: "1"),

		// Define a macro for restricted platforms
		.define("GIT_NO_PROCESS_SPAWN", .when(platforms: [.tvOS, .watchOS])),
	]

	linkerSettings += [
		.linkedLibrary("iconv")
	]

#elseif os(Windows)
	// Windows host → builds Windows targets only.
	// Switch source layout: include `src/util/win32/*` and Win32 SHA, exclude
	// the unix path and Apple-specific backends.
	excludedPaths += [
		// Unix POSIX layer is incompatible with Win32.
		"src/util/unix",

		// CommonCrypto hash backends - Apple-only
		"src/util/hash/common_crypto.c",
		"src/util/hash/common_crypto.h",
		"deps/ntlmclient/crypt_commoncrypto.c",
		"deps/ntlmclient/crypt_commoncrypto.h",

		// Builtin / OpenSSL SHA backends - Windows uses the Win32 BCrypt path
		"src/util/hash/builtin.c",
		"src/util/hash/builtin.h",
		"src/util/hash/collisiondetect.c",
		"src/util/hash/collisiondetect.h",
		"src/util/hash/rfc6234",
		"src/util/hash/sha1dc",
		"src/util/hash/openssl.c",
		"src/util/hash/openssl.h",

		// OpenSSL NTLM crypto - not used on Windows
		"deps/ntlmclient/crypt_openssl.c",
		"deps/ntlmclient/crypt_openssl.h",

		// MinGW-only WinHTTP shim. Swift on Windows uses the MSVC SDK
		// which already provides winhttp.h and the import library.
		"deps/winhttp",
	]

	cSettings += [
		// qsort variant (MSVC has qsort_s)
		.define("GIT_QSORT_MSC"),

		// HTTPS via WinHTTP (high-level Windows HTTP API; pulls in
		// winhttp.dll + cert chain validation from the OS).
		.define("GIT_HTTPS_WINHTTP", to: "1"),

		// Hash implementations via Win32 BCrypt.
		.define("GIT_SHA1_WIN32", to: "1"),
		.define("GIT_SHA256_WIN32", to: "1"),

		// NTLM crypto via NTLMClient builtin (uses Win32 BCrypt under the hood).
		.define("CRYPT_BUILTIN"),

		// Windows uses GetSystemTimeAsFileTime (no nanosecond mtim/mtimespec).
		// Leave GIT_NSEC defined but skip the Linux/Apple-specific arms.

		// libgit2 expects these to be defined for any Windows build.
		.define("WIN32"),
		.define("_WIN32_WINNT", to: "0x0600"),
	]

	linkerSettings += [
		// Always-needed Win32 networking + auth bits.
		.linkedLibrary("ws2_32"),
		.linkedLibrary("secur32"),
		// WinHTTP HTTPS transport.
		.linkedLibrary("winhttp"),
		.linkedLibrary("rpcrt4"),
		.linkedLibrary("crypt32"),
		.linkedLibrary("ole32"),
		// BCrypt provides the SHA backends (and is used by NTLMClient).
		.linkedLibrary("bcrypt"),
	]

#else
	// Linux / Android host → builds Linux or cross-compiled Android targets.
	// Both share the unix/* layer and the builtin SHA backend; HTTPS and
	// random-source defines diverge per target via `.when(platforms:)`.
	excludedPaths += [
		// Windows-specific files (never used on Unix-like systems)
		"src/util/hash/win32.c",
		"src/util/hash/win32.h",
		"src/util/win32",

		// CommonCrypto hash backends - Apple-only
		"src/util/hash/common_crypto.c",
		"src/util/hash/common_crypto.h",
		"deps/ntlmclient/crypt_commoncrypto.c",
		"deps/ntlmclient/crypt_commoncrypto.h",
	]

	cSettings += [
		// Enable GNU extensions (required for qsort_r, etc.) — Bionic also
		// honours _GNU_SOURCE for the same set of symbols.
		.define("_GNU_SOURCE"),

		// qsort variant (GNU-style on Linux). Bionic doesn't expose
		// `qsort_r`, so leave GIT_QSORT_* unset on Android — libgit2
		// falls back to its bundled insertion sort (`util.c:insertsort`).
		.define("GIT_QSORT_GNU", .when(platforms: [.linux])),

		// HTTPS via OpenSSL (dynamic loading) — Linux only. Android currently
		// has no HTTPS backend wired in; clones over HTTP work, HTTPS fails
		// at runtime. Track Android HTTPS as a follow-up.
		.define("GIT_HTTPS_OPENSSL_DYNAMIC", to: "1", .when(platforms: [.linux])),

		// Hash implementations via builtin (collision-detecting SHA1, RFC6234 SHA256).
		.define("GIT_SHA1_BUILTIN", to: "1"),
		.define("GIT_SHA256_BUILTIN", to: "1"),

		// SHA1DC configuration for collision detection
		.define("SHA1DC_NO_STANDARD_INCLUDES", to: "1"),
		.define("SHA1DC_CUSTOM_INCLUDE_SHA1_C", to: "\"git2_util.h\""),
		.define("SHA1DC_CUSTOM_INCLUDE_UBC_CHECK_C", to: "\"git2_util.h\""),

		// Header search paths for builtin hash implementations
		.headerSearchPath("src/util/hash/sha1dc"),
		.headerSearchPath("src/util/hash/rfc6234"),

		// NTLM crypto via OpenSSL (dynamic) on Linux; Android falls back to
		// the builtin path which doesn't need libcrypto.
		.define("CRYPT_OPENSSL", .when(platforms: [.linux])),
		.define("CRYPT_OPENSSL_DYNAMIC", .when(platforms: [.linux])),
		.define("OPENSSL_API_COMPAT", to: "0x10100000L", .when(platforms: [.linux])),
		.define("CRYPT_BUILTIN", .when(platforms: [.android])),

		// Nanosecond support via mtim (Linux/Bionic both expose st_mtim).
		.define("GIT_NSEC_MTIM", to: "1"),

		// Random number generation (Linux + Bionic ≥ API 28 have getentropy).
		.define("GIT_RAND_GETENTROPY", to: "1", .when(platforms: [.linux, .android])),
		.define("GIT_RAND_GETLOADAVG", to: "1", .when(platforms: [.linux])),
	]

	linkerSettings += [
		.linkedLibrary("z"),
		// `dl` is needed for the OpenSSL-dynamic dlopen path; Android keeps
		// it because libdl is part of Bionic anyway and other transitive
		// uses may need it.
		.linkedLibrary("dl"),
		.linkedLibrary("pthread", .when(platforms: [.linux])),
	]
#endif

// =============================================================================
// PACKAGE DEFINITION
// =============================================================================

let package = Package(
	name: "libgit2",
	products: [
		.library(name: "libgit2", targets: ["libgit2"])
	],
	targets: [
		.target(
			name: "libgit2",
			path: ".",
			exclude: excludedPaths,
			sources: [
				"deps/llhttp",
				"deps/pcre",
				"deps/xdiff",
				"deps/zlib",
				"deps/ntlmclient",
				"src/libgit2",
				"src/util",
			],
			publicHeadersPath: "include",
			cSettings: cSettings,
			linkerSettings: linkerSettings
		)
	]
)
