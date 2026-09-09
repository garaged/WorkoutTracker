"""Behavioral fixtures for the Easy/Pro specification gate; no network or Xcode."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from spec_check import validate

COMMIT = 'a' * 40

class SpecificationGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.spec = self.root / 'docs'
        self.spec.mkdir()
        (self.spec / 'BEHAVIOR.md').write_text('### EP-R01 — Example\n')
        (self.spec / 'README.md').write_text('[Behavior](BEHAVIOR.md)\n')
        (self.spec / 'APPROVAL.md').write_text('Accepted 2026-09-09')
        self.manifest = {
            'schema_version': 1, 'release': 'easy-pro', 'revision': '2026-09-09',
            'phase': 'proposal', 'source_commit': COMMIT,
            'specification_files': ['README.md', 'BEHAVIOR.md'],
            'approval': {'status': 'pending', 'revision': None, 'evidence': None},
            'intents': [{'id': 'I-01', 'definition': 'README.md'}],
            'decisions': [{'id': 'D-01', 'status': 'proposed', 'definition': 'README.md'}],
            'milestones': [{'id': 'EP0', 'title': 'Baseline', 'depends_on': [],
                'spec_status': 'proposed', 'implementation_status': 'not_started',
                'exit_status': 'pending', 'evidence': []}],
            'requirements': [{'id': 'EP-R01', 'intent': 'I-01', 'milestone': 'EP0',
                'specification': 'BEHAVIOR.md', 'status': 'proposed',
                'scenarios': ['EP-S01'], 'implementation_refs': [], 'test_refs': [], 'evidence': []}],
            'scenarios': [{'id': 'EP-S01', 'requirements': ['EP-R01'],
                'given': 'A paused timer', 'when': 'It resumes', 'then': 'Paused time is excluded',
                'planned_validation_layers': ['unit'], 'result': 'not_run', 'evidence': []}]}

    def check(self, mode='review'):
        (self.spec / 'TRACEABILITY.json').write_text(json.dumps(self.manifest))
        return validate(self.root, self.spec / 'TRACEABILITY.json', mode=mode, commit=COMMIT)

    def assertCode(self, code, mode='review'):
        self.assertIn(code, [d.code for d in self.check(mode)])

    def accept(self):
        self.manifest['phase'] = 'implementation'
        self.manifest['approval'] = {'status': 'accepted', 'revision': '2026-09-09', 'evidence': 'APPROVAL.md'}
        self.manifest['decisions'][0]['status'] = 'accepted'
        self.manifest['requirements'][0]['status'] = 'accepted'
        self.manifest['milestones'][0]['spec_status'] = 'accepted'

    def complete(self):
        self.accept()
        (self.root / 'source.swift').write_text('struct Timer {}\n')
        (self.root / 'tests.swift').write_text('func testPauseExcludesTime() {}\n')
        (self.spec / 'RESULT.md').write_text('Passed controlled clock test')
        evidence = {'commit': COMMIT, 'result': 'passed', 'artifact': 'docs/RESULT.md'}
        r = self.manifest['requirements'][0]
        r.update(status='implemented', implementation_refs=['source.swift'],
                 test_refs=[{'path': 'tests.swift', 'symbol': 'testPauseExcludesTime'}], evidence=[evidence])
        self.manifest['scenarios'][0].update(result='passed', evidence=[evidence])
        self.manifest['milestones'][0].update(implementation_status='completed', exit_status='passed', evidence=[evidence])

    def test_valid_proposal_is_allowed_for_review(self):
        self.assertEqual([], self.check())
    def test_proposal_cannot_pass_ready(self):
        self.assertCode('approval.required', 'ready')
    def test_accepted_unimplemented_baseline_passes_ready(self):
        self.accept()
        self.assertEqual([], self.check('ready'))
    def test_accepted_baseline_cannot_pass_done(self):
        self.accept()
        self.assertCode('completion.requirement', 'done')
    def test_valid_completed_fixture_passes_done(self):
        self.complete()
        self.assertEqual([], self.check('done'))
    def test_duplicate_id_rejected(self):
        self.manifest['requirements'].append(copy.deepcopy(self.manifest['requirements'][0]))
        self.assertCode('id.duplicate')
    def test_unknown_intent_rejected(self):
        self.manifest['requirements'][0]['intent'] = 'I-99'
        self.assertCode('ref.intent')
    def test_unknown_milestone_rejected(self):
        self.manifest['requirements'][0]['milestone'] = 'EP9'
        self.assertCode('ref.milestone')
    def test_dependency_cycle_rejected(self):
        self.manifest['milestones'][0]['depends_on'] = ['EP0']
        self.assertCode('milestone.cycle')
    def test_missing_scenario_rejected(self):
        self.manifest['requirements'][0]['scenarios'] = []
        self.assertCode('scenario.coverage')
    def test_orphan_scenario_rejected(self):
        self.manifest['scenarios'][0]['requirements'] = ['EP-R99']
        self.assertCode('ref.requirement')
    def test_one_way_link_rejected(self):
        self.manifest['scenarios'][0]['requirements'] = []
        self.assertCode('scenario.reciprocal')
    def test_blank_assertion_rejected(self):
        self.manifest['scenarios'][0]['then'] = ' '
        self.assertCode('scenario.assertion')
    def test_missing_behavior_definition_rejected(self):
        (self.spec / 'BEHAVIOR.md').write_text('No normative requirement here')
        self.assertCode('requirement.definition')
    def test_broken_local_link_rejected(self):
        (self.spec / 'README.md').write_text('[Missing](missing.md)')
        self.assertCode('link.missing')
    def test_implemented_unapproved_rejected(self):
        self.manifest['requirements'][0]['status'] = 'implemented'
        self.assertCode('approval.required')
    def test_nonexistent_test_file_rejected(self):
        self.complete()
        self.manifest['requirements'][0]['test_refs'][0]['path'] = 'missing.swift'
        self.assertCode('test.missing')
    def test_nonexistent_test_symbol_rejected(self):
        self.complete()
        self.manifest['requirements'][0]['test_refs'][0]['symbol'] = 'notATest'
        self.assertCode('test.symbol')
    def test_comment_does_not_count_as_test(self):
        self.complete()
        (self.root / 'tests.swift').write_text('// func testPauseExcludesTime() {}')
        self.assertCode('test.symbol')
    def test_stale_commit_evidence_rejected(self):
        self.complete()
        self.manifest['scenarios'][0]['evidence'][0]['commit'] = 'b' * 40
        self.assertCode('evidence.commit')
    def test_passed_without_evidence_rejected(self):
        self.manifest['scenarios'][0]['result'] = 'passed'
        self.assertCode('evidence.required')
    def test_completed_with_pending_scenario_rejected(self):
        self.complete()
        self.manifest['scenarios'][0]['result'] = 'not_run'
        self.assertCode('completion.scenario')
    def test_schema_version_rejected(self):
        self.manifest['schema_version'] = 99
        self.assertCode('schema.version')
    def test_invalid_field_type_rejected(self):
        self.manifest['requirements'] = 'not a list'
        self.assertCode('schema.type')
    def test_unknown_status_rejected(self):
        self.manifest['requirements'][0]['status'] = 'sort_of_done'
        self.assertCode('schema.enum')
    def test_reference_escape_rejected(self):
        self.complete()
        self.manifest['requirements'][0]['implementation_refs'] = ['../outside.swift']
        self.assertCode('path.outside')
    def test_approval_revision_must_match(self):
        self.accept()
        self.manifest['approval']['revision'] = 'older'
        self.assertCode('approval.revision', 'ready')

if __name__ == '__main__':
    unittest.main()
