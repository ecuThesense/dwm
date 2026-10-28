#!/bin/sh
# gnomerandommanpage.sh - print a random man page as name(section)
# find /usr/share/man/man1 -type f | shuf -n 1 |
#     sed 's|.*/||; s/\.gz$//; s/\.1$/(1)/'

find /usr/share/man/man1 -type f |
    shuf -n 1 |
    sed 's|.*/||; s/\.gz$//; s/\.1$//; s/$/ (1)/'
