#!/usr/bin/env python3
"""Prevent deployment-only retries from publishing an outdated feed merge."""
import re
import sys


def validate(current, base, published):
    if not re.fullmatch(r'[a-f0-9]{64}', published):
        raise ValueError('Missing signed feed revision; rerun the whole Release workflow')
    if base != 'absent' and not re.fullmatch(r'[a-f0-9]{64}', base):
        raise ValueError('Missing base feed revision; rerun the whole Release workflow')
    if current not in (base, published):
        raise ValueError('The public feed changed; rerun the whole Release workflow to merge it')


if __name__ == '__main__':
    try:
        validate(*sys.argv[1:])
    except ValueError as error:
        sys.exit(str(error))
