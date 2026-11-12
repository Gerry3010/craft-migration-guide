#!/usr/bin/env python3
"""Structural comparison of two project config folders.

    compare-project-config.py <old config/project> <new config/craft/project>

Get the old folder from Git (git archive HEAD config/project | tar -x -C /tmp/old)
and the new one by running `artisan craft:pc:write` after the migrations.

Prints, per YAML file, how many keys were removed, added and changed, a line
starting with !! for every field that vanished from a field layout, the
names of removed and added keys across all files, and the number of
sections, entry types, fields and volumes on both sides.
Needs PyYAML.
"""
import collections
import os
import sys

import yaml


def load(root):
    data = {}
    for dirpath, _, files in os.walk(root):
        for name in files:
            if name.endswith('.yaml'):
                path = os.path.join(dirpath, name)
                data[os.path.relpath(path, root)] = yaml.safe_load(open(path)) or {}
    return data


def flatten(node, prefix=''):
    out = {}
    if isinstance(node, dict):
        for key, value in node.items():
            out.update(flatten(value, f'{prefix}/{key}'))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            out.update(flatten(value, f'{prefix}[{index}]'))
    else:
        out[prefix] = node
    return out


def layout_field_uids(node):
    return {v for k, v in flatten(node).items() if k.endswith('/fieldUid') and v}


def main(old_root, new_root):
    old, new = load(old_root), load(new_root)
    removed, added = collections.Counter(), collections.Counter()

    for path in sorted(set(old) | set(new)):
        if path not in new:
            print(f'!! file removed: {path}')
        if path not in old:
            print(f'   file added: {path}')
        flat_old, flat_new = flatten(old.get(path, {})), flatten(new.get(path, {}))
        gone = [k for k in flat_old if k not in flat_new]
        came = [k for k in flat_new if k not in flat_old]
        changed = [k for k in flat_old if k in flat_new and flat_old[k] != flat_new[k]]

        lost_fields = layout_field_uids(old.get(path, {})) - layout_field_uids(new.get(path, {}))
        if lost_fields:
            print(f'!! {path}: fields gone from layout: {sorted(lost_fields)}')

        for key in gone:
            removed[key.split('/')[-1].split('[')[0]] += 1
        for key in came:
            added[key.split('/')[-1].split('[')[0]] += 1
        if gone or came or changed:
            print(f'{path}: -{len(gone)} +{len(came)} ~{len(changed)}')

    print('Removed keys:', dict(removed.most_common(40)))
    print('Added keys:', dict(added.most_common(40)))
    for kind in ('sections', 'entryTypes', 'fields', 'volumes'):
        count_old = sum(1 for p in old if p.startswith(kind + '/'))
        count_new = sum(1 for p in new if p.startswith(kind + '/'))
        marker = '' if count_old == count_new else '   <-- check'
        print(f'{kind}: {count_old} -> {count_new}{marker}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
