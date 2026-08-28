> ## cooViewer downstream fork
>
> This is a **downstream fork** of [MacPaw/XADMaster](https://github.com/MacPaw/XADMaster),
> vendored by the macOS comic viewer [cooViewer](https://github.com/shunnag/cooViewer).
> All credit for XADMaster belongs to its original authors (Dag Ågren / MacPaw and
> contributors); this fork only carries a small, surgical, re-mergeable set of changes.
> Every change is documented in [`MODERNIZATION.md`](MODERNIZATION.md); the summary:
>
> - **Security / correctness hardening (changes 1–50, 56).** A memory-safety pass
>   (AddressSanitizer + UndefinedBehaviorSanitizer fuzzing plus a static audit) fixing
>   OOB reads/writes, integer/shift UB, a `memcpy`/`memmove` overlap, and a handful of
>   parser correctness bugs (e.g. an inverted path-normalization guard, a 7z Compress-coder
>   fall-through). Each is the smallest local edit and independently upstreamable.
> - **Apple-Silicon performance (changes 10–11, 51–64), all `#if __APPLE__`/`__aarch64__`
>   guarded with the portable path preserved and all output byte-identical (SHA-verified):**
>   hardware CRC32 via system zlib, an immutable preallocated `contentsOfEntry:` path that
>   avoids the Swift bridge copy, the embedded LZMA SDK updated to 24.09 with the arm64
>   assembler decoder, CommonCrypto hardware AES/SHA for encrypted 7z/RAR/zip with derived-key
>   caching, an LZMA2 dict-reset index for solid backward seeks, an additive
>   `solidGroupOfEntry:` API enabling entry/group-level parallel extraction, the LHA lh4-7
>   decoder moved onto the batched FastLZSS base, an in-memory zip central-directory parse,
>   and assorted allocation/dispatch cleanups. Measured on Apple M4 Max: e.g. stored cbz
>   extraction 2.5×, RAR 3×, solid 7z −25 %, encrypted 7z ≈30×.
>
> The fork stays MRC (not ARC), keeps the LGPL 2.1 licensing, and preserves the
> Linux/Windows/GNUstep build paths. Upstreaming these as PRs to MacPaw/XADMaster is welcome.

# Objective-C library for archive and file unarchiving and extraction

![XADMaster](.github/header.png)

[![Build Status](https://travis-ci.org/MacPaw/XADMaster.svg?branch=master)](https://travis-ci.org/MacPaw/XADMaster)
* Supports multiple archive formats such as Zip, Tar, Gzip, Bzip2, 7-Zip, Rar, LhA, StuffIt, several old Amiga file and disk archives, CAB, LZX. Read [the wiki page](http://code.google.com/p/theunarchiver/wiki/SupportedFormats) for a more thorough listing of formats.
* Supports split archives for certain formats, like RAR.
* Uses [libxad](http://sourceforge.net/projects/libxad/) for older and more obscure formats. This is an old Amiga library for handling unpacking of archives.
* Depends on [UniversalDetector Library](https://github.com/MacPaw/universal-detector). Uses character set autodetection code from Mozilla to auto-detect the encoding of the filenames in the archives. 
* The unarchiving engine itself is multi-platform, and command-line tools exist for Linux, Windows and other OSes.
* Originally developed by [Dag Ågren](https://github.com/DagAgren)


# Building

XADMaster relies on directories structure. To start development you'll need to clone the main project with Universal Detector library:
```
git clone https://github.com/MacPaw/XADMaster.git
git clone https://github.com/MacPaw/universal-detector.git UniversalDetector
```
The resulting directory structure should look like:

```
<development-directory>
  /XADMaster
  /UniversalDetector
```

# Usages

- [The Unarchiver](https://theunarchiver.com/) application.


# License

This software is distributed under the [LGPL 2.1](https://www.gnu.org/licenses/lgpl-2.1.html) license. Please read LICENSE for information on the software availability and distribution.
