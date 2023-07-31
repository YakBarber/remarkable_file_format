# reMarkable File Format

This repository provides a reverse-engineered file format spec for the [reMarkable tablet](https://remarkable.com)'s proprietary file format.

If you are *not* interested in developing your own parser or writer for the reMarkable file format, you probably should instead look at [`rmconvert`](https://github.com/yakbarber/rmconvert), my sister project aimed at building bi-directional conversion tooling for this file format. If you're looking to build tools yourself, read on.

**Note:** This file represents the *current* version of the reMarkable file format used on tablets with up-to-date firmware. If you are on an older (pre 3.0) version, you should instead look at [the work done by others](https://plasma.ninja/blog/devices/remarkable/binary/format/2017/12/26/reMarkable-lines-file-format.html) on the [older formats](https://github.com/matomatical/reMarkable-kaitai/blob/main/rm_v5.ksy).

## Explanation

The format spec in this repository is a single [Kaitai Struct](https://www.kaitai.io) YAML-style file ([rmv6.ksy](rmv6.ksy)). This file is a functional, nearly-complete specification of the [reMarkable tablet](https://remarkable.com)'s "v6" `.rm` (formerly `.lines`) file format, which was introduced with firmware version 3.0 at the end of 2022. The specification was reverse-engineered by me, Barry Van Tassell, during my 6-week batch at the [Recurse Center](https://www.recurse.com) in the summer of 2023.

I have done my best to follow Kaitai style norms, to include documentation, and to be clear about what is known, unknown, complete, and incomplete.

If you are interested in developing a parser for the reMarkable file format, you will want to check out the [Kaitai Struct documentation and tooling](https://doc.kaitai.io/), which will allow you to convert the spec into parsing code in a number of different languages.

Finally, it's worth pointing out that currently this specification only describes the format of the binary `.rm` files used to store all the vector details of your drawings and scribbles. The tablet also includes several text files with these `.rm` files, which are necessary but not described here. However, since they're text-based, you can open them up and read them yourself. The [unofficial reMarkable wiki](https://remarkablewiki.com) also has [an article](https://remarkablewiki.com/tech/filesystem#user_data_directory_structure) describing their structure.

## Getting to the files

Your reMarkable tablet, believe it or not, is actually just a Linux computer. ReMarkable's creators have been kind enough to give us root-level access to the tablet's internals. You can read more about this on the unofficial wiki and [reMarkable's offical support page](https://support.remarkable.com/s/article/Help), but the TL;DR is:

- You can access your tablet via `ssh`. In your tablet settings, tap on "Help," then "Copyrights and licenses." 
- Files are stored in a flat structure in `/home/root/.local/share/remarkable/xochitl`.
- Each notebook is stored as a collection of files and directories with the same UUID. Within the UUID-named directory, there will be a single `.rm` file for each page of the notebook, named with a different UUID. These `.rm` files are the subject of this repository.

## Covering my butt

1) Neither myself nor this work are associated with reMarkable in any way. I'm just some guy with a tablet who likes having control over his files.
2) This work is released under the [MIT License](LICENSE), which means you can essentially do whatever you want with it as long as you acknowledge my contribution and agree that it's not my fault if anything goes wrong.
3) **I am making no guarantees of the accuracy or fitness of this work.** Mucking around with the internals of your tablet and its files comes with risks, and it is your responsibilty to manage those risks for yourself.
4) If you find a bug or inaccuracy, please [submit an issue](https://github.com/YakBarber/remarkable_file_format/issues/new) to this repository, or even better, fork the repository and submit a pull request with a fix.

## Shoulders I am standing on

These links are to previous work I have referenced and taken inspiration from. For the most part, they target obsolete versions of the reMarkable file format.

[rM2svg (2019)](https://github.com/reHackable/maxio/blob/master/tools/rM2svg)
[original format documentation (2017-2019)](https://plasma.ninja/blog/devices/remarkable/binary/format/2017/12/26/reMarkable-lines-file-format.html)
[Rust-based parser based on 2019 documentation](https://github.com/ax3l/lines-are-rusty)
[filesystem layout and format of the non-binary metadata files (wiki)](https://remarkablewiki.com/tech/filesystem#user_data_directory_structure)
[Kaitai struct for parsing .rm v3 and v5 files (2020)](https://github.com/matomatical/reMarkable-kaitai/blob/main/rm_v5.ksy)

