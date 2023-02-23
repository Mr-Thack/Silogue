# Simple Prologue
I'm attempting to form it into a truly simple framework.
So simple, that even an idiot could reliably use it.

## Documentatoin
As of now, see the unit tests (in `tests/``).
When finished, actual documentation shall be added.

## Configuration
Configure your `.env` file.

## Bugs
If `virtualPath` is set to `/`, nothing works, nothing's served.
However, if `virtualPath` is set to anything else,
Prologue serves on `/` and the specified directory.
Remember: **It's not a bug; it's a feature!**