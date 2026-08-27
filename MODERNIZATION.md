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

All dates 2026-08-17 (change #49: 2026-08-18, #50: 2026-08-26). Each row is one commit; each is written to be
an independent PR to upstream. Findings came from a read-only security/modernization survey of
the reachable decoders; fixes tighten bounds that only fire on malformed input, so well-formed
archives are unaffected (cooViewer's XCTest suite confirms no regression).

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
| 35 | `XADTarParser.m` | security (CWE-787) | Bound the PAX extended-header pair size before the `char key_val_pair[next_pair_size]` VLA + `memset`. `next_pair_size` is a PAX length field minus the digits read; a negative value wrapped the VLA/memset to a huge size (stack smash) and a large value overflowed the stack. Require it to fit the remaining header. Found by audit. | upstreamable |
| 36 | `XADArParser.m` | security (CWE-787) | Bound the `ar`/`.deb` BSD long-name length (a 12-byte decimal field, unbounded) before the `uint8_t namebuf[namelen]` VLA — a large value overflowed the stack, a negative one was UB. Found by audit. | upstreamable |
| 37 | `XADISO9660Parser.m` | security (CWE-787/DoS/CWE-125) | Three SUSP fixes: bound the "CE" continuation length before the `uint8_t system[currlength]` VLA (attacker uint32 → stack overflow); cap CE→CE chains (a cyclic chain looped forever); and fix the "SL" component guard to `offs+2+complen>length` (the component bytes start at `offs+2`, so the old guard over-read up to 2 bytes). Found by audit. | upstreamable |
| 38 | `XADStuffItXCyanideHandle.m` | security (CWE-190/CWE-787) | Size the Cyanide BWT allocation as `(size_t)blocksize*6` (it was computed in uint32 and wrapped, e.g. `blocksize=0x2AAAAAAB` → `malloc(2)` while the BWT/MTF routines write `blocksize` bytes → heap overflow), null-check it, and bound `firstindex<blocksize`. Mirrors the sibling Iron handle. Found by audit. | upstreamable |
| 39 | `XADStuffItArsenicHandle.m` | security (CWE-190/CWE-787) | Cap the Arsenic zero-run loop: it was uncapped, so ~31 iterations overflowed `zerostate`/`zerocount` to negative, which passed the `>blocksize` guard and made `memset` run with a huge length (heap overflow). Bound `zerostate` (so `2*zerostate` cannot overflow) and reject a run beyond `blocksize`. Found by audit. | upstreamable |
| 40 | `XADStuffItXEnglishHandle.m` | security (CWE-190/CWE-787) | Reject an out-of-range dictionary `index` inside the base-52 accumulation loop; it was uncapped, so ~6 letters overflowed `index` to negative, bypassing the `index>=NumberOfWords` check and making `pointers[index]`/`memcpy` read+write out of bounds (`wordbuf` is 33 bytes). `index` is monotone increasing so a valid word never trips it. Found by audit. | upstreamable |
| 41 | `XAD7ZipParser.m` | hardening (CWE-125) | Fix the 7-Zip SFX recognizer scan bound: `Is7ZipSignature` memcmp's up to 7 bytes at `bytes+offs`, but the loop ran while `offs<length+7`, reading past the buffer for any `MZ` file. Require the whole signature to fit. Found by audit. | upstreamable |
| 42 | `XADBlockHandle.m` | hardening (DoS) | Cap the CFBF FAT-chain walk to the block count: a cyclic/self-referential sector chain otherwise looped forever and overflowed `numblocks`. Found by audit. | upstreamable |
| 43 | `XADStuffItXParser.m` | hardening | Bound two attacker-controlled shift amounts: the Brimstone `exponent` (==31 made `1<<31` signed-overflow UB with a negative alloc size flowing into the PPMd suballocator) and the Darkhorse window shift (`1<<readUInt8`, UB for ≥31). Found by audit. | upstreamable |
| 44 | `XADNowCompressHandle.m` | hardening (CWE-476) | Reject a negative `numentries`, size the block-table `malloc` in `size_t`, and null-check it; `numentries` is derived from attacker offsets and the following `blocks[…]` writes deref a failed (NULL) or wrapped allocation. Found by audit. | upstreamable |
| 45 | `XADARCDistillHandle.m` | hardening (CWE-125) | Guard the ARC/Distill tree walk: an internal node reads both children `tree[node]` and `tree[node+1]`, so `node==numnodes-1` (or a negative node) ran past the `nodes[numnodes]` VLA. Found by audit. | upstreamable |
| 46 | `libxad/clients/LhF.c` | security (CWE-787) | Bound the LhF Huffman code length: `k` is built from an unbounded run of 1-bits, and `++data0[k-1]` (16-entry histogram) writes far past the array for large `k` (heap overflow). Reject `k>16`. Bundled libxad (LGPL-2.1); fork-local. Found by audit. | fork-local |
| 47 | `libxad/clients/Ace.c` | hardening (CWE-787) | Reject `uplim>=ACEsvwd_cnt` in the ACE code reader: `uplim` is a 4-bit field (0..15) but `wd_svwd` has only 15 entries, so `uplim==15` wrote `wd_svwd[15]`, one past the array (corrupting the adjacent struct field). Bundled libxad; fork-local. Found by audit. | fork-local |
| 48 | `libxad/clients/xadIO_Compress.c` | hardening (CWE-190) | Bound the vendored `.Z` LZW maxbits to 9..16 (attacker-controlled, up to 31 → `1<<31` UB and a `maxmaxcode`-sized allocation that wraps on 32-bit). Mirrors the XADMaster `.Z` fix (#21). Bundled libxad; fork-local. Found by audit. | fork-local |
| 49 | `XADString.m` | correctness / i18n | Add a "confident UTF-8" pre-detector fast path to `+analyzedXADStringWithData:source:`. When a name carries no explicit encoding flag but its bytes are **strictly valid UTF-8** (RFC 3629 / Unicode Table 3-7 — overlong forms, surrogates, code points > U+10FFFF, truncated sequences and stray continuation bytes all rejected) **and** contain at least one 3-/4-byte sequence, decode it as UTF-8 instead of deferring to the universalchardet statistical guesser (`IsDataConfidentlyUTF8`). This fixes real-world filename mojibake on UTF-8 names stored *without* a flag — legacy zip lacking GP bit 11, GNU/ustar tar, LHA, RAR3 8-bit names — which universalchardet mis-guesses for short CJK names (its `nsUTF8Prober` confidence stays < the 0.95 shortcut below ~5 multibyte chars, so a legacy CJK prober can outscore it). The 3-byte-sequence requirement is the key to compat-safety: every CJK / kana / Hangul character is a 3-byte UTF-8 sequence (emoji 4-byte), so UTF-8 CJK recall stays **100%**, while a legacy 2-byte CJK pair that coincidentally forms valid UTF-8 almost always yields only 2-byte (C-lead) sequences. Measured over ~18k realistic legacy CJK names (SJIS/EUC-JP/GBK/Big5/CP949) the misfire rate is **< 0.03%** (vs ~0.5–1.7% for a plain "any valid UTF-8" rule). The shared detector is still fed, so mixed-encoding archives are unaffected; ASCII keeps its existing fast path. Same principle used by Python's `zipfile`, Go's `archive/zip` and 7-Zip. Verified by a standalone differential corpus test and a new cooViewer XCTest (`ArchiveSourceTests.testUnflaggedUTF8Names`). | upstreamable |
| 50 | `XADPath.m`, `XADMasterTests/XADPathTests.m` | correctness (upstream issue #192) | Fix the inverted early return in `-canonicalPathComponentsWithEncodingName:`: the guard read `!=NSNotFound && !=NSNotFound`, so a path containing **both** `.` and `..` components — exactly the case that needs normalization — was returned raw, skipping the dot-dropping passes below and corrupting `isCanonicallyEqual:` / `hasCanonicalPrefix:` / `firstCanonicalPathComponent` (consumed by `XADMacArchiveParser` for AppleDouble/ditto pairing; not a traversal risk — `sanitizedPathString` defends independently). History shows the intent: `HasDotPaths` ("either dot form present → normalize") was inlined into this early return during a big rewrite and the negation came out wrong. Flip both comparisons to `==NSNotFound`, matching the comment. Regression-tested by the new `XADPathTests` (the mixed-dot cases fail before the fix, pass after; plain/single-dot behavior locked by control cases). Tracked upstream as issue #192 (a third-party report, open and unfixed as of 2026-08-26). | upstreamable |
| 51 | `CRC.m` | performance / apple-silicon | Supersede change #11's single-stream loop on Apple platforms: delegate the `edb88320` fast path to the system zlib `crc32()` (multi-stream PMULL/CRC32 kernel, ~47 GB/s vs 12 GB/s measured on M4 Max; libz is already a link dependency everywhere via `CSZlibHandle`). The intrinsic loop remains for non-Apple `__ARM_FEATURE_CRC32` targets, sliced-16 for the rest. End-to-end (384 MB JPEG corpus, warm): stored cbz −35%, RAR4 −49%, RAR5 −41%. Byte-identical (conditioning wrappers; `CRCCalculationTests` + `CRCFastRegression`). | upstreamable |
| 52 | `CSHandle.[hm]`, `CSMemoryHandle.m`, `XADArchive.m` | performance | Additive API `-remainingFileContentsWithSizeHint:`: preallocates the declared uncompressed size, reads in large chunks, returns an **immutable** malloc-backed `NSData` (bridges into Swift `Data` without the `NSMutableData` copy). The hint is untrusted: ≤0 / ≥1 GB → classic path; undershoot → append-growth tail; overshoot → shrink; always drained to EOF so checksum wrappers keep their semantics. `contentsOfEntry:` passes `XADFileSizeKey`. Supersedes the "double copy in remainingFileContents" deferral below — the Swift-bridge copy made it measurable after all: stored cbz −41%, RAR5 −48% on top of #51. | upstreamable (API addition) |
| 53 | `CSZlibHandle.h`, `XADLZMA(2)Handle.h`, `XADRAR(5)Parser.m`, `CSStreamHandle.m`, `CSHandle.m` | performance | Larger input buffers on hot decode paths (zlib/LZMA handles 16 K→256 K, RAR bit reader 16 K→256 K, stream default 4 K→64 K, discard buffer 16 K→64 K). Deflated cbz −4% end-to-end; no behavior change. | upstreamable |
| 54 | `lzma/`, `XADLZMA(2)Handle.m`, `WinZipJPEG/Decompressor.c`, pbxproj | performance / apple-silicon | Update the embedded LZMA SDK from 4.6x (2008/2009) to 24.09 (public domain; filenames preserved, legacy `Types.h` kept for the untouched `Bra*` filters) and compile the SDK's `Asm/arm64/LzmaDecOpt.S` with `Z7_LZMA_DEC_OPT` gated to `__aarch64__ && __APPLE__` (portable C decoder elsewhere). Solid-LZMA2 7z extraction −31% (43→61 MB/s on literal-heavy JPEG data); compressible data −22%. Byte-identical output. | upstreamable |
| 55 | `XAD7ZipParser.m`, `XAD7ZipAESHandle.[hm]` | performance | Encrypted 7z: (a) process-global locked cache of derived AES keys keyed by (password, salt, logrounds) — resolves the long-standing `TODO: Cache keys.` (derivation is 2^19 chained SHA-256 rounds, ~28 ms per entry handle before); (b) on `__APPLE__`, CBC decryption via `CCCryptor` (hardware AES) and the derivation via batched `CC_SHA256` — same byte stream, reference implementations kept for other platforms. 20-page encrypted non-solid 7z: extraction 654→22 ms, random 10-page access 324→10 ms. | upstreamable |
| 56 | `XAD7ZipParser.m` | correctness | `case 0x04050000` (Compress/.Z coder) was missing its `return`: the freshly built `XADCompressHandle` was discarded and control fell through into the 7zAES case, so 7z archives containing Compress-coded entries decoded garbage (or failed). Found during the performance audit. | upstreamable |
| 57 | `XAD7ZipParser.[hm]`, `XADMacArchiveParser.m`, `XADStringCFString.m`, `XADPrefixCode.[hm]`, `XADZipParser.m` | performance | Open-path batch (2026-08-27 round 2, all SHA-identical): bulk-read the 7z Names property and slice on NUL terminators instead of per-character readUInt16LE + `appendFormat:@"%C"` (additive `parseNamesForHandle:propertySize:array:`; short blocks now raise instead of consuming the next property); test the AppleDouble `"._"` prefix before paying for whole-path UTF-8 decodes; thread-local memo of the last IANA name→encoding lookup; geometric growth for the prefix-code tree (was one Realloc per node); read umask once per process (two syscalls per entry gone, and the concurrent-parse race that could permanently record a transient `umask(0)` narrowed to one startup window). 2000-entry SJIS archives: 7z open −24% (8.1→6.1 ms), zip open −3%. | upstreamable |
| 58 | `CSInputBuffer.[hm]` | performance | Cache the parent handle's file offset in the struct: `CSInputFileOffset` cost one objc_msgSend per call and RAR5 queries the bit offset once per decoded symbol. The parent only moves via `_CSInputFillBuffer` / `CSInputSeekToFileOffset`, which both refresh the cache (the fill refreshes from the live handle, so it self-heals every buffer). RAR5 real-decode −3%; full-suite SHA-identical; ASan/UBSan mutant battery clean. | upstreamable |
| 59 | `XADArchive.[hm]` | feature / performance (additive API) | `-solidGroupOfEntry:` — value-stable solid-group id per entry (group leader's `XADIndexKey`; −1 when not solid-tracked), derived from the parser's per-entry dictionaries rather than object identity. Lets clients unlock entry-level parallel extraction for non-solid 7z/rar/lha and group-affine parallelism for block-split solid archives: a 6-worker group-aware harness measures non-solid 7z full extraction 192→37 ms (5.2×) and 64 MB-block solid 7z 6.41→1.20 s (5.3×), SHA-identical. | upstreamable |
| 60 | `XADRARAESHandle.[hm]`, `XADWinZipAESHandle.[hm]`, `XADZipCryptHandle.m` | performance | Extend the round-1 7zAES work to the other encrypted formats, `__APPLE__`-gated with vendored fallbacks, all byte-identical (real-archive SHA + differential key-derivation fuzzing): RAR3/4/5 CBC via `CCCryptor` (hardware AES) + a process-global locked derived-key cache + hardware batched `CC_SHA1` for the 2^18-round RAR≥3.6 derivation (the broken-hash path keeps the vendored loop); WinZip/7z AES-256 zips via hardware AES-CTR + `CCHmac`-SHA1 authentication; and a bulk `streamAtMost:` override for legacy PKZIP that drops the per-byte producer trampoline. Measured (20-page archives): RAR4 −27%, RAR5 −28%, WinZip-AES −53%, ZipCrypto −4%. | upstreamable |
| 61 | `XADLZMA2Handle.[hm]` | performance | Dict-reset index for solid backward seeks. A backward seek re-decoded a solid LZMA2 folder from offset 0; this lazily walks the chunk headers (only on the first backward seek), records every dict-reset point (uncompressed control `0x01` and LZMA reset-mode 3 — a dict-reset boundary is a valid stream start), and restarts `Lzma2Dec_Init` from the nearest reset ≤ target. Defensive parse: any malformed header abandons the index and falls back to restart-from-0, so unindexable/corrupt streams are unchanged; forward/spool paths never build it. Random 10-page access on a 384 MB default-created solid 7z 29.0 → 19.7 s (−32%, resets every 128 MB); `-mmt=1` single-block archives unchanged; sequential extraction unchanged; SHA-identical. | upstreamable |
| 62 | `XADLZHStaticHandle.[hm]` | performance / apple-silicon | Migrate lh4-7 (and the ARJ/Zoo streams that share this class) from the per-byte `XADLZSSHandle`/`CSByteStreamHandle` base to `XADFastLZSSHandle`. The block-Huffman decode is byte-for-byte unchanged (same symbols, offsets, lengths, window); only output emission becomes a batched `expandFromPosition:` loop, so matches ride the `LZSS.h` memcpy/memset fast path and the per-output-byte IMP dispatch is gone. `XADLZSSHandle` (many other decoders) is untouched. Measured (SHA-identical): JPEG lh5/6/7 ~−11% (literal-heavy → mostly dispatch removal), compressible-TIFF lh5 −47% (match-heavy → also the copy fast path). The #23 stack-VLA guard lives in this file's untouched allocAndParse methods and is re-exercised by the mutant battery (ASan/UBSan clean over 64 truncation/bitflip lzh mutants); the fork's full test suite stays green. | upstreamable |

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
method 14 (34). A second audit pass over the header/structure parsers and every `libxad/clients/*.c`
then found the same overflow classes in the parse phase: attacker-sized stack VLAs (Tar PAX 35,
`ar` 36, ISO9660 CE 37), 32-bit size/shift overflows feeding allocations or copies (StuffItX
Cyanide 38 / Arsenic 39 / English 40 / Brimstone-Darkhorse 43, NowCompress 44, libxad `.Z` 48),
out-of-bounds reads (7-Zip SFX 41, ARC/Distill 45, ISO9660 SL 37), unbounded loops (CFBF FAT chain
42, ISO9660 CE chain 37) and vendored libxad histogram/table overruns (LhF 46, ACE 47). After these
fixes the open+extract path runs clean under ASan across multi-million-iteration runs. Fuzzing is
nondeterministic — longer runs against a mature parser may still surface deeper edge cases; this
harness lives in the cooViewer scratch tree for reuse. UBSan also flags benign enum-range loads
inside the vendored `UniversalDetector` (Mozilla `universalchardet`); those are fixed in that
library's own fork, not here. One low-severity 1-byte lookahead over-read in `universalchardet`
`JpCntx.cpp` (`GetOrder` dereferencing `*(str+1)` at buffer end) is inherited from upstream Mozilla
and left as-is to avoid diverging the detector.

## Deferred (candidates for a future iteration)

Intentionally NOT changed yet, to keep this iteration low-risk and highly mergeable:

- **`NSDateXAD.m` `NSGregorianCalendar`→`NSCalendarIdentifierGregorian`** needs a `#if` guard
  (the constant is 10.10+, upstream targets 10.6) and only affects entry mod-times, which
  cooViewer never reads. Low value / added churn; deferred.
- **`wavpack/unpack_seek.c` unused variable** — third-party vendored code; report to the WavPack
  project rather than diverge the fork.
- **LHA `0x46` codepage extended header** in `XADLZHParser.m`: UNLHA32 records an explicit
  Windows code page (932/65001/936/…) that would let LHA names skip the guesser entirely. Deferred:
  low incidence (LHA *and* that specific header), the codepage→encoding mapping needs a portability
  guard (`CFStringConvertWindowsCodepageToEncoding` is Apple-only, upstream also targets Linux/
  GNUstep), and change #49 already covers the UTF-8 (65001) case. Revisit if LHA mojibake is reported.
- **Extract-path micro-throughput** — the 2026-08-27 measured pass (changes #51-#55) landed the
  items once deferred here: the `remainingFileContents` double copy turned out to be very
  measurable once the Swift `NSMutableData`→`Data` bridge copy was counted (change #52), and CRC
  did become a bottleneck once stored-cbz was profiled end-to-end (change #51). Still deferred:
  the 512 KB zero-filled prefetch in `-[CSHandle copyDataOfLengthAtMost:]` per archive open
  (driven by ISO9660's `requiredHeaderSize`), and `setvbuf` on `CSFileHandle` — the latter now
  looks *harmful* for the zip open path (stdio would refill a large buffer on every 2-byte read
  after each local-header seek), so it should not be revisited without that pattern in mind.
- **3-stream hardware CRC32 + GF(2) combine** in `CRC.m`: benchmarked at ~7× the sliced-16
  baseline (33 vs 4.6 GB/s) but never adopted, and now obsolete — change #51 delegates to the
  system zlib's kernel (~47 GB/s measured), which is faster than the hand-written 3-stream
  variant with none of the combine-table maintenance.
