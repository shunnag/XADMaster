# cooViewer fork — change log & maintenance notes

This is a **downstream fork** of [MacPaw/XADMaster](https://github.com/MacPaw/XADMaster),
vendored by the macOS app [cooViewer](https://github.com/shunnag/cooViewer). It exists only
to carry a small, surgical set of fixes and improvements on top of upstream until (and if)
they are accepted upstream. **All credit for XADMaster belongs to its authors** (Dag Ågren /
MacPaw and the many contributors); this fork merely stands on their work.

## Guiding principles (why this file exists)

Upstream XADMaster is an **actively maintained** project. Every change here is written to be
**re-mergeable with future upstream**:

- **Surgical, not sweeping.** No rewrites, no reformatting, no mass renames. Each change is the
  smallest edit that fixes the issue, kept local to one function so it rebases cleanly.
- **One concern per commit.** Each commit maps to exactly one entry in the table below and,
  where possible, is independently upstreamable (a clean PR to MacPaw/XADMaster).
- **Portability preserved.** XADMaster targets macOS (down to 10.6), Linux, Windows and
  GNUstep, and is deliberately manual-retain-release (not ARC). We keep it that way. Any
  Apple-Silicon / arm64 optimization is guarded with `#if defined(__aarch64__)` /
  `#if defined(__ARM_FEATURE_CRC32)` and always keeps the portable fallback.
- **Correctness first.** This library parses untrusted input. Changes favor hardening and
  clearly-correct bounds checks over clever optimizations. Optimizations are only adopted after
  differential validation (byte-identical output) and, for hot loops, benchmarking.
- **In-code marking.** Every modification is marked at the change site with a `// [cooViewer]`
  comment so it is obvious what diverges from upstream and why.

## License

XADMaster is **LGPL 2.1** (see `LICENSE`); the vendored `libxad/`, `lzma/`, `wavpack/` and
`Crypto/` subtrees carry their own upstream licenses and are **not modified by this fork**.
Per LGPL 2.1 §2(a), modified files carry a notice of the change and its date — recorded in the
table below (authoritative dates) and marked inline with `// [cooViewer]`. The library remains
**dynamically linked** by cooViewer (embedded framework), and this fork's source is public, so
the LGPL obligations are met. Upstream copyright and license notices are preserved unchanged.

## Base

- Forked from upstream commit `38f2c0e6e906de781bf991d0a2d037a18955972d`
  (`v1.10.7-66-g38f2c0e`).

## How to resync with upstream

1. `git remote add upstream https://github.com/MacPaw/XADMaster.git` (once).
2. `git fetch upstream`.
3. `git rebase upstream/master` onto the new base (the commits below are small and localized,
   so conflicts are minimal; resolve per-commit).
4. Drop any commit whose fix has landed upstream in the meantime (check the table's "Upstream"
   column / open PRs), and update the "Base" line above.
5. Rebuild cooViewer's frameworks (`rm -rf Frameworks` then build) and run cooViewer's test
   suite; update the submodule pin in the parent repo.

## Verification

Each change is verified by (a) a clean framework rebuild and (b) cooViewer's XCTest suite,
which exercises real zip/cbz, rar/cbr and nested archives through `XADArchive`. Security fixes
tighten bounds that only trigger on malformed input, so well-formed archives are unaffected
(the suite confirms no regression).

## Changes (newest last)

All dates 2026-08-17. Each row is one commit; each is written to be an independent PR to
upstream. Findings came from a read-only security/modernization survey of the reachable
decoders; fixes tighten bounds that only fire on malformed input, so well-formed archives are
unaffected (cooViewer's XCTest suite confirms no regression).

| # | File(s) | Category | Change | Upstream |
|---|---------|----------|--------|----------|
| 1 | `XADRAR30Handle.m` | security (CWE-787) | Clamp the RAR3 filter block length against `RARProgramMemorySize` before `CopyBytesFromLZSSWindow`, preventing a heap out-of-bounds write on a crafted archive. | upstreamable |
| 2 | `XADRAR30Handle.m` | security (CWE-787/CWE-190) | Fix off-by-one filter-number bound (`num>1024`→`num>=1024`; arrays are `[1024]`) that allowed an out-of-bounds write into `oldfilterlength`/`usagecount`; also reject a negative (high-bit) data-section length that became a huge allocation. | upstreamable |
| 3 | `XADRARVirtualMachine.m` | security (CWE-843/CWE-787) | Fix the RAR VM global-data readback: pass the `NSMutableData` object (the code passed its raw `mutableBytes` pointer, then messaged it as an object — type confusion) and size the buffer to the requested length first so the readback cannot overflow. | upstreamable |
| 4 | `XADRAR50Handle.m` | security (CWE-190/CWE-409) | Bound the attacker-controlled RAR5 filter length to the LZSS window before it is used as an `int` copy count and an allocation size (a value ≥ 2³¹ truncated to negative / attempted a huge alloc). Mirrors the RAR3 clamp. | upstreamable |
| 5 | `XADZipParser.m` | security (CWE-125) | Fix an out-of-bounds heap read in the ZIP directory-detection name compare: the loop walked two non-NUL-terminated `NSData` buffers relying on a terminator; bound it by `prevlength` (preserving the exact prefix heuristic). Reachable on ordinary cbz. | upstreamable |
| 6 | `XADMSLZXHandle.m`, `XADLZXHandle.m` | security (CWE-787) | Add the missing `i+n>count` bounds guard before the length-table write in `XADMSLZXHandle` (its sibling `XADLZXHandle` already had it) — a crafted CAB/LZX stream could write past `lengths[]`. Add a defensive `else`-raise for `val>19` (prevents an `i+=0` infinite loop) and zero-init `n`/`length` to satisfy `-Wsometimes-uninitialized` — the only substantive code warnings in cooViewer's build. | upstreamable |
| 7 | `XADDeflateHandle.m` | hardening (CWE-125) | Reject the reserved Deflate literals 286/287 (a Deflate64 table can encode them) instead of silently mis-decoding them as symbol 285; bound the StuffItX 6-bit distance symbol before indexing the 28-entry `baseoffsets[]` (was an out-of-bounds read). | upstreamable |
| 8 | `CSMemoryHandle.m` | modernization | Replace deprecated `+dataWithContentsOfMappedFile:` (10.10) with `+dataWithContentsOfFile:options:NSDataReadingMappedIfSafe error:` (since 10.6) — behavior-equivalent and safer (declines to mmap truncation-prone volumes). | upstreamable |
| 9 | `XADArchiveParser.m` | modernization | Replace deprecated `+propertyListFromData:mutabilityOption:format:errorDescription:` (10.10) with `+propertyListWithData:options:format:error:` (since 10.6); behavior-equivalent. | upstreamable |
| 10 | `LZSS.h` | performance / apple-silicon | Add a fast path to `EmitLZSSMatch` (the RAR window-copy hot loop shared by all RAR decoders): when neither the source nor destination range wraps the window, use `memcpy` (non-overlapping match) / `memset` (`offset==1` run) / a forward byte loop (overlapping match) instead of the per-byte masked copy; falls back to the original masked loop on wrap. `memcpy`/`memset` are NEON-accelerated on Apple Silicon. Validated **byte-identical** against the original by differential fuzzing (1.5M cases across window sizes 64 B–1 MB) and ~1.4× faster on a RAR-like match workload. | upstreamable |

## Deferred (candidates for a future iteration)

Intentionally NOT changed yet, to keep this iteration low-risk and highly mergeable:

- **`XADDeflateHandle.m` leak-on-throw** (dynamic-Huffman `metacode` on a malformed Deflate64
  block). The only correct fix (`@try/@finally`) reindents the whole block, churning the diff
  against upstream for a tiny leak on a rare malformed path. Low value; deferred.
- **`NSDateXAD.m` `NSGregorianCalendar`→`NSCalendarIdentifierGregorian`** needs a `#if` guard
  (the constant is 10.10+, upstream targets 10.6) and only affects entry mod-times, which
  cooViewer never reads. Low value / added churn; deferred.
- **`wavpack/unpack_seek.c` unused variable** — third-party vendored code; report to the WavPack
  project rather than diverge the fork.
- **Apple-Silicon hardware CRC32** in `CRC.m`, guarded by `#if defined(__ARM_FEATURE_CRC32)`
  with the sliced-16 fallback: uncertain benefit — the baseline is already a sliced-by-16 table
  and zlib `inflate` (not CRC) dominates cbz time; a real win needs the 3-independent-stream +
  GF(2) combine technique. Deferred pending a benchmark showing it beats the current table.
  (The `EmitLZSSMatch` fast path once listed here has now landed — change #10 above.)
