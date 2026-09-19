#!/usr/bin/env python3
"""Offline structural/traceability validation; review, ready and release-done gates.

No network, dependencies or application imports. Diagnostics are stable IDs plus
locations. Structural validation does not replace semantic or usability review.
"""
from __future__ import annotations
import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote

@dataclass(frozen=True)
class Diagnostic:
    code: str
    location: str
    message: str


def validate(root: Path, manifest_path: Path, *, mode: str = 'review', commit: str | None = None) -> list[Diagnostic]:
    root = root.resolve()
    manifest_path = manifest_path.resolve()
    spec = manifest_path.parent
    issues: list[Diagnostic] = []
    def fail(code, location, message):
        issues.append(Diagnostic(code, str(location), message))
    def text(value):
        return isinstance(value, str) and bool(value.strip())
    def file_ref(value, base, location, code='file.missing'):
        if not text(value):
            fail('schema.type', location, 'Expected a nonempty relative file path')
            return None
        path = (base / value).resolve()
        if Path(value).is_absolute() or not path.is_relative_to(root):
            fail('path.outside', location, 'Reference must stay inside the repository')
            return None
        if not path.is_file():
            fail(code, location, f'Missing file: {value}')
            return None
        return path
    if mode not in {'review', 'ready', 'done'}:
        fail('schema.enum', 'mode', 'Use review, ready or done')
        return issues
    if commit is not None and not re.fullmatch(r'[0-9a-f]{40}', commit):
        fail('evidence.commit', 'commit', 'Expected a complete Git commit SHA')
    if mode == 'done' and commit is None:
        fail('evidence.commit', 'commit', 'Done gate requires the exact tested commit')
    try:
        data = json.loads(manifest_path.read_text())
    except (OSError, ValueError) as error:
        fail('manifest.read', manifest_path, str(error))
        return issues
    if not isinstance(data, dict):
        fail('schema.type', '$', 'Manifest must be an object')
        return issues
    if type(data.get('schema_version')) is not int or data['schema_version'] != 1:
        fail('schema.version', 'schema_version', 'Only version 1 is supported')
    for field in ('release', 'revision', 'source_commit'):
        if not text(data.get(field)):
            fail('schema.type', field, 'Expected nonempty string')
    if not re.fullmatch(r'[0-9a-f]{40}', str(data.get('source_commit', ''))):
        fail('schema.type', 'source_commit', 'Expected complete Git SHA')
    if data.get('phase') not in {'proposal', 'implementation', 'complete'}:
        fail('schema.enum', 'phase', 'Unknown phase')
    if not isinstance(data.get('specification_files'), list) or not data['specification_files']:
        fail('schema.type', 'specification_files', 'Expected a nonempty list')
        return issues
    spec_files = []
    for value in data['specification_files']:
        f = file_ref(value, spec, 'specification_files')
        if f:
            spec_files.append(f)
    schemas = {
        'intents': (r'I-\d{2,}', {'definition': str}),
        'decisions': (r'D-\d{2,}', {'status': str, 'definition': str}),
        'milestones': (r'EP\d+', {'title': str, 'depends_on': list, 'spec_status': str,
            'implementation_status': str, 'exit_status': str, 'evidence': list}),
        'requirements': (r'EP-R\d{2,}', {'intent': str, 'milestone': str, 'specification': str,
            'status': str, 'scenarios': list, 'implementation_refs': list, 'test_refs': list, 'evidence': list}),
        'scenarios': (r'EP-S\d{2,}', {'requirements': list, 'given': str, 'when': str, 'then': str,
            'planned_validation_layers': list, 'result': str, 'evidence': list}),
    }
    indexed = {}
    malformed = False
    for group, (pattern, fields) in schemas.items():
        items = data.get(group)
        indexed[group] = {}
        if not isinstance(items, list) or not items:
            fail('schema.type', group, 'Expected a nonempty list')
            malformed = True
            continue
        for n, item in enumerate(items):
            loc = f'{group}[{n}]'
            if not isinstance(item, dict) or not isinstance(item.get('id'), str):
                fail('schema.type', loc, 'Expected an object with string id')
                malformed = True
                continue
            identity = item['id']
            if not re.fullmatch(pattern, identity):
                fail('id.format', loc, f'Invalid identifier {identity}')
            if identity in indexed[group]:
                fail('id.duplicate', loc, f'Duplicate identifier {identity}')
            indexed[group][identity] = item
            for field, kind in fields.items():
                if not isinstance(item.get(field), kind):
                    fail('schema.type', f'{loc}.{field}', f'Expected {kind.__name__}')
                    malformed = True
    if malformed:
        return issues
    def enum(value, choices, loc):
        if value not in choices:
            fail('schema.enum', loc, f'Unknown value {value!r}')
    def string_refs(values, loc):
        if any(not text(v) for v in values):
            fail('schema.type', loc, 'References must be nonempty strings')
            return []
        if len(values) != len(set(values)):
            fail('ref.duplicate', loc, 'Duplicate reference')
        return values
    approval = data.get('approval')
    if not isinstance(approval, dict):
        fail('schema.type', 'approval', 'Expected approval object')
        approval = {}
    enum(approval.get('status'), {'pending', 'accepted'}, 'approval.status')
    accepted = approval.get('status') == 'accepted'
    if accepted:
        if approval.get('revision') != data.get('revision'):
            fail('approval.revision', 'approval.revision', 'Approval must identify this revision')
        file_ref(approval.get('evidence'), spec, 'approval.evidence')
    requirements = indexed['requirements']
    scenarios = indexed['scenarios']
    milestones = indexed['milestones']
    needs_acceptance = mode != 'review' or any(r['status'] == 'implemented' for r in requirements.values())
    if needs_acceptance and not accepted:
        fail('approval.required', 'approval', 'Implementation requires an accepted revision')
    for i in indexed['intents'].values():
        file_ref(i['definition'], spec, i['id'])
    for d in indexed['decisions'].values():
        enum(d['status'], {'proposed', 'accepted', 'deferred'}, d['id'])
        file_ref(d['definition'], spec, d['id'])
        if needs_acceptance and d['status'] == 'proposed':
            fail('approval.required', d['id'], 'Proposed decision cannot authorize implementation')

    def evidence(records, loc, required=False):
        if required and not records:
            fail('evidence.required', loc, 'Passing/completed status requires evidence')
        for n, record in enumerate(records):
            if not isinstance(record, dict):
                fail('schema.type', loc, 'Evidence must be an object')
                continue
            if not re.fullmatch(r'[0-9a-f]{40}', str(record.get('commit', ''))):
                fail('evidence.commit', loc, 'Evidence needs full source commit')
            elif commit is not None and record['commit'] != commit:
                fail('evidence.commit', loc, 'Evidence is for a different tested commit')
            enum(record.get('result'), {'passed', 'failed', 'blocked', 'not_run', 'waived'}, loc)
            if required and record.get('result') != 'passed':
                fail('evidence.result', loc, 'Nonpassing evidence cannot establish completion')
            artifact = record.get('artifact')
            if isinstance(artifact, str) and artifact.startswith('https://'):
                # Existence and outcome of hosted artifacts require review; never fetch here.
                continue
            file_ref(artifact, root, f'{loc}[{n}].artifact', 'evidence.artifact')

    for m in milestones.values():
        mid = m['id']
        enum(m['spec_status'], {'proposed', 'accepted'}, mid)
        enum(m['implementation_status'], {'not_started', 'in_progress', 'completed'}, mid)
        enum(m['exit_status'], {'pending', 'passed', 'failed', 'blocked'}, mid)
        for dep in string_refs(m['depends_on'], mid):
            if dep not in milestones:
                fail('ref.milestone', mid, f'Unknown dependency {dep}')
        if m['implementation_status'] != 'not_started' and (not accepted or m['spec_status'] != 'accepted'):
            fail('approval.required', mid, 'Milestone implementation requires accepted specification')
        done = m['implementation_status'] == 'completed' or m['exit_status'] == 'passed'
        if mode == 'done' and not done:
            fail('completion.milestone', mid, 'Milestone exit is pending')
        if done and (m['implementation_status'] != 'completed' or m['exit_status'] != 'passed'):
            fail('completion.milestone', mid, 'Completion and exit status must agree')
        evidence(m['evidence'], mid, required=done)
        if done:
            for dep in string_refs(m['depends_on'], mid):
                if dep in milestones and milestones[dep]['exit_status'] != 'passed':
                    fail('completion.dependency', mid, f'Dependency {dep} has not passed')
    visited, active = set(), set()
    def visit(mid):
        if mid in active:
            fail('milestone.cycle', mid, 'Dependency cycle')
            return
        if mid in visited or mid not in milestones:
            return
        active.add(mid)
        for dep in string_refs(milestones[mid]['depends_on'], mid):
            visit(dep)
        active.remove(mid)
        visited.add(mid)
    for mid in milestones:
        visit(mid)

    for r in requirements.values():
        rid = r['id']
        enum(r['status'], {'proposed', 'accepted', 'implemented'}, rid)
        if r['intent'] not in indexed['intents']:
            fail('ref.intent', rid, 'Unknown intent')
        if r['milestone'] not in milestones:
            fail('ref.milestone', rid, 'Unknown milestone')
        f = file_ref(r['specification'], spec, rid)
        if f and not re.search(r'^###\s+' + re.escape(rid) + r'\s', f.read_text(), re.MULTILINE):
            fail('requirement.definition', rid, 'Normative requirement heading is missing')
        if not r['scenarios']:
            fail('scenario.coverage', rid, 'Requirement has no scenarios')
        for sid in string_refs(r['scenarios'], rid):
            if sid not in scenarios:
                fail('ref.scenario', rid, f'Missing scenario {sid}')
            elif rid not in scenarios[sid]['requirements']:
                fail('scenario.reciprocal', rid, f'Scenario {sid} must link back')
        implemented = r['status'] == 'implemented'
        if needs_acceptance and r['status'] == 'proposed':
            fail('approval.required', rid, 'Proposed requirement cannot pass readiness')
        milestone_done = r['milestone'] in milestones and milestones[r['milestone']]['exit_status'] == 'passed'
        if (mode == 'done' or milestone_done) and not implemented:
            fail('completion.requirement', rid, 'Requirement is not implemented')
        if implemented and (not r['implementation_refs'] or not r['test_refs']):
            fail('implementation.references', rid, 'Implementation requires real source/test references')
        for ref in r['implementation_refs']:
            file_ref(ref, root, rid, 'implementation.missing')
        for ref in r['test_refs']:
            if not isinstance(ref, dict) or not text(ref.get('symbol')):
                fail('schema.type', rid, 'Test reference needs path and symbol')
                continue
            path = file_ref(ref.get('path'), root, rid, 'test.missing')
            if path and not re.search(r'^\s*(?:(?:private|public|internal|static|class|async)\s+)*(?:func|def)\s+' + re.escape(ref['symbol']) + r'\s*\(', path.read_text(), re.MULTILINE):
                fail('test.symbol', rid, f'Test declaration not found: {ref["symbol"]}')
        evidence(r['evidence'], rid, required=implemented)
        if implemented or milestone_done or mode == 'done':
            for sid in string_refs(r['scenarios'], rid):
                if sid in scenarios and scenarios[sid]['result'] != 'passed':
                    fail('completion.scenario', sid, 'Applicable scenario is not passed')
    layers = {'unit', 'integration', 'persistence', 'property', 'contract', 'ui', 'manual', 'spec', 'review'}
    for s in scenarios.values():
        sid = s['id']
        for field in ('given', 'when', 'then'):
            if not text(s[field]):
                fail('scenario.assertion', f'{sid}.{field}', 'Given/When/Then must be nonempty')
        if not s['requirements']:
            fail('scenario.reciprocal', sid, 'Scenario has no requirements')
        for rid in string_refs(s['requirements'], sid):
            if rid not in requirements:
                fail('ref.requirement', sid, f'Unknown requirement {rid}')
            elif sid not in requirements[rid]['scenarios']:
                fail('scenario.reciprocal', sid, 'Requirement must link back')
        if not s['planned_validation_layers']:
            fail('scenario.coverage', sid, 'Validation layer required')
        for layer in string_refs(s['planned_validation_layers'], sid):
            enum(layer, layers, sid)
        enum(s['result'], {'not_run', 'passed', 'failed', 'blocked', 'waived'}, sid)
        evidence(s['evidence'], sid, required=s['result'] == 'passed')
    declared = set()
    for path in spec_files:
        if path.suffix == '.md':
            declared.update(re.findall(r'^###\s+(EP-R\d+)\s', path.read_text(), re.MULTILINE))
    for rid in declared - requirements.keys():
        fail('requirement.orphan', rid, 'Normative requirement is absent from manifest')
    for path in spec_files:
        if path.suffix != '.md':
            continue
        for link in re.findall(r'\[[^\]]+\]\(([^)]+)\)', path.read_text()):
            if link.startswith(('https://', 'http://', 'mailto:', '#')):
                continue
            target = unquote(link.split('#', 1)[0])
            file_ref(target, path.parent, path.relative_to(root), 'link.missing')
    return issues


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--manifest', default='docs/releases/easy-pro/TRACEABILITY.json')
    parser.add_argument('--mode', choices=('review', 'ready', 'done'), default='review')
    parser.add_argument('--commit', help='Exact commit whose completion evidence is being checked')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args(argv)
    issues = validate(args.root, args.root / args.manifest, mode=args.mode, commit=args.commit)
    if args.json:
        print(json.dumps({'passed': not issues, 'diagnostics': [asdict(d) for d in issues]}, indent=2))
    else:
        for d in issues:
            print(f'{d.code}: {d.location}: {d.message}')
        print(f'Specification {args.mode}: {"FAIL" if issues else "PASS"} ({len(issues)} diagnostics)')
    return 1 if issues else 0

if __name__ == '__main__':
    sys.exit(main())
