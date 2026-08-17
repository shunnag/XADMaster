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
| 11 | `CRC.m` | performance / apple-silicon | Add a guarded (`#if defined(__ARM_FEATURE_CRC32)`) single-stream ARMv8 hardware CRC32 path for the reflected `edb88320` poly used by zip/gzip/rar CRC verification, gated to the one `XADCRCTable_sliced16_edb88320` table and falling back to the existing sliced-by-16 code on non-arm builds / any other table. Byte-identical to the table (validated by `CRCCalculationTests` + offline differential fuzzing, 20k cases) and ~2.3× faster (10.6 vs 4.6 GB/s) on Apple Silicon. | upstreamable |
| 12 | `Scanning.m` | security / correctness | Use `memmove` instead of `memcpy` for the archive-scan carry-over window shift; source and destination overlap when `actual < 2*maximumlength-2`, so the `memcpy` was undefined behavior. Found by AddressSanitizer fuzzing of the open+extract path. | upstreamable |
| 13 | `XADRAR5Parser.m` | hardening | Bound two attacker-controlled shifts flagged by UBSan fuzzing: the RAR5 varint reader (`res \|= bits << pos`) no longer shifts a `uint64` by `>=64` (accumulates only the low 64 bits, keeps the stream in sync); and the RAR5 KDF count exponent is rejected outside `[0,24]` (`1<<strength` was UB for `strength>=31` and a `2^strength`-iteration DoS). | upstreamable |
| 14 | `XADZipCryptHandle.m` | hardening | Compute the PKZIP decrypt key-stream product in unsigned arithmetic; `temp*(temp^1)` promoted to `int` and overflowed (signed-overflow UB, found by UBSan fuzzing). | upstreamable |
| 15 | `XADSqueezeHandle.m` | security (CWE-787) | Reject `numnodes<2` in the Squeeze/SQ decoder. `numnodes` is attacker-controlled and only had an upper bound; `numnodes==0` makes `int nodes[numnodes]` a zero-length VLA and the `nodes[0]=nodes[1]=…` writes overflow the stack (ASan dynamic-stack-buffer-overflow). A valid Squeeze tree always has ≥2 nodes. | upstreamable |
| 16 | `CSInputBuffer.h` | hardening | Return the peeked byte as `uint32_t` from `_CSInputPeekByteWithoutEOF`, so the bit-buffer fills shift it in unsigned arithmetic; `byte<<24` computed in `int` overflowed a signed int for bytes ≥ 0x80 (UB). One-point fix for every fill site. | upstreamable |
| 17 | `XADRAR5Parser.m` | hardening (DoS) | Guarantee forward progress in the RAR5 block loop: a crafted stream could make `skipBlock` seek to a non-advancing offset, re-reading the same block forever (infinite loop / hang). Require each block to start strictly after the previous one. | upstreamable |
| 18 | `CSHandle.m` | hardening (DoS) | `remainingFileContents` appended `readAtMost:`'s count without a sign check; a negative count became a huge `NSUInteger` and an impossible allocation (ASan allocation-size-too-big). Only append positive reads. | upstreamable |
| 19 | `XADTarParser.m` | security (CWE-125) | Guard the trailing-slash directory-typeflag check against an empty tar entry name; `name[strlen(name)-1]` underflowed to `name[-1]`, an out-of-bounds stack read (ASan stack-buffer-overflow). | upstreamable |
| 20 | `CSStreamHandle.m` | security (CWE-787/CWE-190) | Fix the read clamp in `readAtMost:`. A bogus/attacker-controlled `streamlength` (negative, or > `INT_MAX`) made `num=(int)(streamlength-streampos)` wrap to a value **larger** than the caller's buffer, so the "clamp" grew the request and a downstream decode overflowed the caller's stack buffer (a crafted LZMA/7z entry drove `LzmaDec_DecodeToBuf` to write past a 16 KiB buffer in `remainingFileContents`). Only ever shrink `num`; treat a non-positive valid remaining length as EOF; ignore a negative (bogus) length so reads proceed to the decoder's real end. The overflow is entirely wrapper-side — the vendored LZMA SDK is unchanged. | upstreamable |
| 21 | `XADCompressHandle.m` | hardening (CWE-190/DoS) | Bound the `.Z` LZW maxbits (low 5 bits of the flags, attacker-controlled) to its valid 9–16 range before `1<<maxbits`; a value of 31 made `1<<31` undefined behavior and 17–30 requested a multi-GB LZW table. | upstreamable |
| 22 | `XAD7ZipParser.m` | hardening | Reject a negative or overflowing 7z next-header offset before computing `startoffset+32+nextheaderoffs` (attacker-controlled `off_t`, signed-overflow UB). | upstreamable |
| 23 | `XADLZHStaticHandle.m` | security (CWE-787) | Clamp the LZH pt-len table zero-run in `allocAndParseCodeOfWidth:specialIndex:` to the `int codelengths[num]` VLA. The sibling `allocAndParseLiteralCode` already bounds its own zero-run, but this variant did not, so a crafted pt-len table wrote past the stack VLA (ASan dynamic-stack-buffer-overflow). Clamp to `num` to match the reference LHA `read_pt_len` (whose fixed-size `pt_len[NPT]` silently absorbs the overrun) without rejecting valid archives. Found by ASan fuzzing. | upstreamable |
| 24 | `XADLZHParser.m` | hardening | Replace the level-0/1 filename VLA `uint8_t namebuffer[namelen]` (a zero-length VLA when `namelen==0`, undefined behaviour flagged by UBSan) with a fixed 256-byte buffer like the reference LHA header reader — `namelen` is a `uint8` so it always fits. | upstreamable |
| 25 | `XADRARParser.m` | hardening | Compute the RAR `LHD_LARGE` 64-bit size extension with an unsigned shift; `(off_t)[fh readUInt32LE]<<32` overflowed `int64` for a high size word ≥ 2³¹ (signed-shift UB, found by UBSan fuzzing). The value only occupies bits 32–63; downstream size/bounds checks already reject bogus totals. | upstreamable |
| 26 | `XADLZHOldHandles.m` | security (CWE-787) | Fix a heap-buffer-overflow in the old-LZH (lh1/lh2/lh3) decoder. `LHAready_made` filled `pt_len[]`/`pt_code[]` for `dat->d.st.np` codes — `1<<(MAX_DICBIT-6)` = 1024 on the st0 (lh3) path — but both arrays hold only `NPT` (128) entries, so a crafted lh3 stream taking the ready-made branch wrote ~900 entries past the end of the `LhADecrST` struct (ASan). `make_table` only consumes the first `NP` (17), so bounding the fill to `NPT` is behaviour-preserving. Also bound the `make_table` tree-node counter `avail` to the shared `left[]`/`right[]` size (`2*NC-1`), the classic LHArc make_table overrun. This is XADMaster's own C port of the LZH decoder (not the bundled libxad `LhA.c`, which is a static-only copy and was left untouched). Found by ASan fuzzing. | upstreamable |
| 27 | `XADXZHandle.m` | hardening (DoS) | Stop an infinite loop in the XZ block decoder: `BlockDataState` re-read the filter chain forever when it returned 0 bytes without being at EOF (a crafted block that neither advances nor ends), hanging the app. Treat no-progress-without-EOF as illegal data — for a valid stream `actual==0` only coincides with EOF, so no decodable block is rejected. Found by fuzzing (`.xz` seed). | upstreamable |
| 28 | `XADDeflateHandle.m` | hygiene | Autorelease the dynamic-Huffman `metacode` at allocation so the throwing paths that follow (two `raiseDecrunchException`, the literal/distance `XADPrefixCode` inits) cannot leak it. The autorelease variant needs no reindent — it supersedes the earlier deferral. Surfaces under LeakSanitizer. | upstreamable |
| 29 | `XADXZHandle.m` | hardening | Read the XZ variable-length integer as `uint64_t`, accumulating only the low 64 bits; `(b&0x7f)<<pos` was an `int` shift that overflowed for `pos>=28` on a crafted overlong varint (UB, found by UBSan). Mirrors the RAR5 varint fix (#13). | upstreamable |
| 30 | `XADStuffIt13Handle.m` | security (CWE-787) | Bound the StuffIt method-13 code-length run fills to `numcodes`. The case-34/35/36 runs advanced `i` past the `for(i<numcodes)` head test, overflowing the `int lengths[numcodes]` stack VLA (as small as 10 for the offset code; a case-36 run writes up to 73) — a controlled stack write. The bit reads still run so the stream stays in sync. Found by memory-safety audit; mirrors the `XADLZHStaticHandle` guard. | upstreamable |
| 31 | `XADNowCompressHandle.m` | security (CWE-787) | Reject an out-of-range scatter index in the NowCompress code reader: `lengths[*source++]+=16` used a raw 0–255 stream byte as an index into `int lengths[numentries]`, and the 20-entry header code overflowed the stack VLA by up to ~940 bytes. The 256-entry callers are unaffected (0–255 < 256). Found by memory-safety audit. | upstreamable |
| 32 | `libxad/clients/LhA.c` | security (CWE-787) | Bound the vendored libxad LHArc decoder like change #26's XADMaster copy: clamp `LHAread_c_len`'s count/zero-run to `NC` (heap overflow of `c_len[]`), and bound `make_table`'s tree-node counter `avail` to `2*NC-1` (`left[]`/`right[]` overrun). Bundled libxad (LGPL-2.1, © Dirk Stöcker); the `// [cooViewer] 2026` markers are the §2(a) change notices; kept fork-local. Found by memory-safety audit. | fork-local |
| 33 | `libxad/clients/DMS.c` | security (CWE-787) | Reject over-long Huffman code counts in the vendored DMS (DiskMasher) decoder: `DMSread_tree_c` `n` (9 bits, up to 511) exceeded `c_len[DMSNC=510]`, and `DMSread_tree_p` `n` (5 bits, up to 31) exceeded `pt_len[DMSNPT=30]` — the latter the struct's last field, so one byte past the heap allocation. Bundled libxad; fork-local. Found by memory-safety audit. | fork-local |
| 34 | `XADStuffItOldHandles.m` | hardening | Bound the StuffIt method-14 (`SIT14_ReadTree`) run-copy to `codesize`; a crafted tree pushed `i` past `code[]` into adjacent fields of the same struct (contained within the allocation, hence lower severity). Found by memory-safety audit. | upstreamable |

## Fuzzing

Changes 12–34 came from an AddressSanitizer + UndefinedBehaviorSanitizer campaign plus a targeted
static memory-safety audit: the framework is built with `-fsanitize=address,undefined` and a harness
drives `XADArchive initWithData:` (format detect → parse → per-entry decompress) on mutated seed
archives (zip/gzip/bzip2/StuffIt/WARC + real xz/tar + crafted RAR/7z/CAB/LHA/ALZ magic), with a
per-input watchdog that catches decode hangs. Fuzzing found and fixed wrapper-side stack-buffer
overflows (Squeeze, Tar, a crafted LZMA/7z entry driving a wrapper clamp overflow, an LZH pt-len
table), a heap-buffer-overflow in XADMaster's own old-LZH decoder (change 26), three denial-of-service
conditions (a RAR5 parse hang, an XZ block-decode infinite loop, a negative-length huge allocation),
and several undefined-behavior sites (overlapping `memcpy`, out-of-range shifts incl. the XZ/RAR5
varints, signed overflow, a zero-length VLA). A follow-up audit of the remaining Huffman/run
decoders then found controlled stack/heap overflows of the same class in StuffIt method 13
(change 30), NowCompress (31), the vendored libxad LhA/DMS length tables (32, 33) and StuffIt
method 14 (34). After these fixes the open+extract path runs clean under ASan across multi-million-
iteration runs. Fuzzing is nondeterministic — longer runs against a mature parser may still surface
deeper edge cases; this harness lives in the cooViewer scratch tree for reuse. UBSan also flags
benign enum-range loads inside the vendored `UniversalDetector` (Mozilla `universalchardet`); those
are fixed in that library's own fork, not here.

## Deferred (candidates for a future iteration)

Intentionally NOT changed yet, to keep this iteration low-risk and highly mergeable:

- **`NSDateXAD.m` `NSGregorianCalendar`→`NSCalendarIdentifierGregorian`** needs a `#if` guard
  (the constant is 10.10+, upstream targets 10.6) and only affects entry mod-times, which
  cooViewer never reads. Low value / added churn; deferred.
- **`wavpack/unpack_seek.c` unused variable** — third-party vendored code; report to the WavPack
  project rather than diverge the fork.
- **3-stream hardware CRC32 + GF(2) combine** in `CRC.m`: benchmarked at ~7× the sliced-16
  baseline (33 vs 4.6 GB/s), but NOT adopted — CRC is not the decode bottleneck (zlib inflate
  dominates cbz time), so the ~3× gain over the adopted single-stream path (change #11) does not
  move end-to-end time enough to justify the ~40-line GF(2) combine and its rebase friction.
  Revisit only if profiling shows CRC becoming hot. (The single-stream HW CRC32 and the
  `EmitLZSSMatch` fast path once listed here have both landed — changes #11 and #10.)
