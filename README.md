pbpaste_unified
========

Paste PNG into files on MacOS, much like `pbpaste` does for text. If the
clipboard contains text instead of an image, pbpaste_unified writes the text
directly.

However instead of `pbpaste_unified > thefile.png`, it's `pbpaste_unified thefile.png`,
so one does not accidentally barf binary into the console.

### Motivation

[http://apple.stackexchange.com/q/11100/4795](http://apple.stackexchange.com/q/11100/4795)

### Build

    $ make all

### Installation

From source:

    $ make all
    $ sudo make install

Or with Homebrew:

    $ brew install pbpaste_unified

### Usage

    $ pbpaste_unified hooray.png

    # If clipboard contains text, writes text to the file.
    $ pbpaste_unified --Prefer txt note.txt
    $ pbpaste_unified --Prefer rtf note.rtf
    $ pbpaste_unified --Prefer ps note.ps
    $ pbpaste_unified --Prefer png note.png
    $ pbpaste_unified --Prefer jpeg note.jpg

### Bonus and Disclaimers

Supported input formats are PNG, PDF, GIF, TIF, JPEG.

Supported output formats are PNG, GIF, JPEG, TIFF.

Output formats are determined by the provided filename extension,
falling back to PNG.

It's unclear if EXIF data in JPEG sources are preserved. There's an
issue with pasting into JPEG format from a GIF source.

### Error Handling

Minimal :'(
