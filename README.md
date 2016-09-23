# id3lib
LiveCode script library for reading id3 tags (originally by Mark Smith)

id3lib
Version: 1.0.3

Unfortunately the original author of this library stack, Mark Smith, died in 2009. He did some really nice work!
I've only made a few minor changes in an effort to keep his library up to date with newer verions of LiveCode 
(use 'byte' instead of 'char') and to work around some improperly encoded ID3 tags (unicode 'year' frames for example)
that I've encountered while using the lib. 
There are still bugs and functionality missing. Writing picture frames is broken and/or unfinished as well,
it fails reading certain cover art pictures. I hope to correct these problems or, failing that, finish writing my own id3 library from scratch, which I started before finding Mark's stack, at some point.
In the mean-time, I've added two "brute-force" picture-data extraction functions which may be of use to outside of the realm of mp3/id3 tags, these are extractPNGfromAnyFile and extractJPEGfromAnyFile.

Paul McClernan
Date: April 26th 2015

id3lib
Version: 1.0.2
Author: Mark Smith (mark at maseurope.net)
Date: 28th May 2007

Rest in peace Mark. 


