#!/usr/bin/env python3
"""Find Twig loops that iterate an element query directly.

    find-query-loops.py <project-config-dir> <templates-dir>

In Craft 6 an element query is a Laravel query builder and no longer
iterable. `{% for row in entry.matrixField %}` renders nothing, without an
error and without a deprecation warning, while `entry.matrixField|length`
still returns the right number. Append `.all()` to fix it.

The script reads the field handles of query-type fields (Matrix, Entries,
Assets, Categories, Tags, Users) from the project config and reports every
`{% for ... in <something>.<handle> %}` that does not call a fetch method.
It also lists loops over `craft.entries(...)`-style queries without `.all()`.
Variables that hold a query (`{% set rows = entry.matrixField %}`) are not
traced; review those by hand.
"""
import os
import re
import sys

import yaml

QUERY_FIELD_TYPES = ('Matrix', 'Entries', 'Assets', 'Categories', 'Tags', 'Users')
FETCH = re.compile(r'\.(all|collect|one|ids|column|pairs)\(\)')
FOR_LOOP = re.compile(r'\{%-?\s*for\s+[\w\s,]+\s+in\s+(.+?)\s*-?%\}', re.S)


def query_field_handles(config_dir):
    handles = set()
    for dirpath, _, files in os.walk(config_dir):
        if os.path.basename(dirpath) != 'fields':
            continue
        for name in files:
            if not name.endswith('.yaml'):
                continue
            data = yaml.safe_load(open(os.path.join(dirpath, name))) or {}
            field_type = str(data.get('type', '')).rsplit('\\', 1)[-1]
            if field_type in QUERY_FIELD_TYPES and data.get('handle'):
                handles.add(data['handle'])
    return handles


def main(config_dir, templates_dir):
    handles = query_field_handles(config_dir)
    if not handles:
        sys.exit('No query-type fields found. Is the project config path right?')
    field_access = re.compile(r'\.(' + '|'.join(sorted(handles)) + r')\b(?!\s*\()')
    hits = 0
    for dirpath, _, files in os.walk(templates_dir):
        for name in files:
            if not name.endswith(('.twig', '.html')):
                continue
            path = os.path.join(dirpath, name)
            text = open(path, encoding='utf-8', errors='replace').read()
            for match in FOR_LOOP.finditer(text):
                expr = match.group(1)
                if FETCH.search(expr):
                    continue
                is_field = field_access.search(expr)
                is_query = re.search(r'craft\.(entries|assets|users|categories|tags)\b', expr)
                if is_field or is_query:
                    line = text.count('\n', 0, match.start()) + 1
                    print(f'{path}:{line}: {match.group(0).strip()}')
                    hits += 1
    print(f'{hits} loop(s) to check. Query-type fields: {", ".join(sorted(handles))}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
