"""Visual definitions use the real Rhema compiler/runtime in isolated folders."""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from flask import Flask

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from teacher_builder import is_form_preset, register_teacher_routes
from visual_builder import STARTERS, VisualError, compile_spec, literal, ref, starter, step
from visual_library import OPERATIONS, RENDERERS, CONTEXTS


class VisualCompilerTests(unittest.TestCase):
    def test_registry_only_uses_existing_builtins_with_the_correct_arity(self):
        # Ask the compiler itself, as the web editor does: the table of
        # builtins is not kept in one source file that a pattern could read.
        bridge = ROOT / 'generator/_build/default/rhema/bin/rhema_builder_main.exe'
        inventory = json.loads(subprocess.run([str(bridge), 'completions'], check=True,
                                              capture_output=True, text=True).stdout)
        signatures = {entry['name']: entry['arity'] for entry in inventory['functions']}
        self.assertGreater(len(OPERATIONS), 100)
        self.assertEqual(len(OPERATIONS), len({o['id'] for o in OPERATIONS}))
        for op in OPERATIONS:
            if not op['operator']:
                self.assertEqual(signatures.get(op['id']), len(op['arguments']), op['id'])
        self.assertTrue(set(RENDERERS.values()) <= signatures.keys())

    def test_names_never_become_rhema_keywords_and_source_is_deterministic(self):
        spec = copy.deepcopy(STARTERS['boolean'])
        first = compile_spec(spec)
        self.assertEqual(first, compile_spec(spec))
        self.assertIn('let vb_left = bool_var("p")', first['source'])
        self.assertIn('context "Numeric"', first['source'])
        self.assertEqual(first['types']['expression'], 'Boolean')

    def test_forward_circular_and_unknown_references_are_rejected(self):
        for name in ('result', 'not_defined'):
            spec = copy.deepcopy(STARTERS['polynomial'])
            spec['steps'][0]['arguments'][0] = ref(name)
            with self.subTest(name=name), self.assertRaisesRegex(VisualError, 'earlier'):
                compile_spec(spec)

    def test_incompatible_types_and_equation_answers_are_rejected(self):
        spec = copy.deepcopy(STARTERS['polynomial'])
        spec['steps'][1]['arguments'] = [ref('a')]
        with self.assertRaisesRegex(VisualError, 'Polynomial'):
            compile_spec(spec)
        spec = starter('Equation', [], [step('p','polynomial_variable',literal('x')), step('eq','polynomial_equation',ref('p'),ref('p'))], 'Solve {eq}.', 'eq')
        with self.assertRaisesRegex(VisualError, 'direct answer'):
            compile_spec(spec)

    def test_duplicate_names_bad_ranges_and_boolean_literals(self):
        spec = copy.deepcopy(STARTERS['polynomial'])
        spec['parameters'][1]['name'] = 'a'
        with self.assertRaisesRegex(VisualError, 'more than once'):
            compile_spec(spec)
        for lo, hi in ((4, 1), (0, 0)):
            spec = copy.deepcopy(STARTERS['polynomial'])
            spec['parameters'][0].update(min=lo,max=hi)
            with self.assertRaises(VisualError):
                compile_spec(spec)
        self.assertIn('(1 = 1)', compile_spec(STARTERS['set'])['source'])

    def test_unsupported_functions_raw_code_and_unknown_fields_are_rejected(self):
        for injected in ('Sys.command', 'eval', 'unknown_builtin', ['add']):
            spec = copy.deepcopy(STARTERS['polynomial'])
            spec['steps'][0]['operation'] = injected
            with self.subTest(operation=injected), self.assertRaises(VisualError):
                compile_spec(spec)
        spec = copy.deepcopy(STARTERS['polynomial'])
        spec['steps'][0]['arguments'][3] = literal('x"); END_PGML')
        with self.assertRaises(VisualError):
            compile_spec(spec)
        spec['steps'][0]['source'] = 'anything'
        with self.assertRaises(VisualError):
            compile_spec(spec)

    def test_plain_question_text_is_not_raw_pgml(self):
        spec = copy.deepcopy(STARTERS['polynomial'])
        spec['prompt'] = 'Text [@danger] $value _underline and {p}.'
        result = compile_spec(spec)['source']
        self.assertIn('\\\\[',result)
        self.assertIn('[`{vb_display_1}`]',result)
        for prompt in ('END_PGML', 'Unknown {other}', 'An incomplete {p', 'A null\0character'):
            spec['prompt'] = prompt
            with self.subTest(prompt=prompt), self.assertRaises(VisualError):
                compile_spec(spec)

    def test_constraints_must_be_truth_values(self):
        spec = copy.deepcopy(STARTERS['polynomial'])
        spec['constraints'] = [{'ref':'a','expected':True}]
        with self.assertRaisesRegex(VisualError,'true/false'):
            compile_spec(spec)

    def test_finite_set_insertion_rejects_intervals_but_union_accepts_finite_sets(self):
        specification=starter('Sets',[],[step('interval','set_interval',literal(0),literal(4),literal(True),literal(True)),
            step('result','set_insert',ref('interval'),literal(2))],'Find {interval}.','result')
        with self.assertRaisesRegex(VisualError,'FiniteSet'):
            compile_spec(specification)
        specification['steps']=[step('finite','set_empty'),step('result','set_union',ref('finite'),ref('finite'))]
        specification['prompt']='Find the set union.'
        self.assertEqual(compile_spec(specification)['types']['result'],'Set')


class VisualRouteTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        (self.root / 'static').symlink_to(ROOT / 'static', target_is_directory=True)
        generator = self.root / 'generator'
        generator.mkdir()
        for name in ('_build','stdlib'):
            (generator/name).symlink_to(ROOT/'generator'/name,target_is_directory=True)
        self.grammars = generator/'grammars'
        self.grammars.mkdir()
        app = Flask(__name__)
        register_teacher_routes(app,self.root)
        self.client = app.test_client()

    def post(self, action, spec=None, **extra):
        return self.client.post('/teacher/visual/'+action,json={'name':'my_visual.rhm','specification':spec or copy.deepcopy(STARTERS['polynomial']),**extra})

    def test_catalog_and_every_starter_pass_real_check_and_generation(self):
        catalog = self.client.get('/teacher/visual/catalog').json
        self.assertTrue(catalog['success'])
        for name, spec in catalog['starters'].items():
            with self.subTest(starter=name):
                response=self.post('check',spec)
                self.assertEqual(response.status_code,200,response.json)
                self.assertIn('synth value on Q',response.json['source'])
        self.assertEqual(list((self.root/'generator/generated_questions').glob('*')),[])
        self.assertFalse(list(self.grammars.glob('.visual_check_*')))

    def test_polynomial_answer_and_deterministic_student_generation(self):
        spec=copy.deepcopy(STARTERS['polynomial'])
        for parameter,value in zip(spec['parameters'],(2,-3,1,2)):
            parameter.update(min=value,max=value)
        first=self.post('preview',spec,count=2,student_id='STUDENT_01')
        again=self.post('preview',spec,count=2,student_id='STUDENT_01')
        self.assertEqual(first.status_code,200,first.json)
        self.assertEqual([q['answer'] for q in first.json['preview']],['5','5'])
        self.assertEqual(first.json['pgml_code'],again.json['pgml_code'])
        self.assertNotEqual(first.json['pgml_path'],again.json['pgml_path'])
        self.assertTrue((self.root/'generator'/first.json['ast_path']).is_file())
        self.assertTrue((self.root/'generator'/first.json['visualization_path']).is_file())
        metadata=(self.root/'generator'/first.json['pgml_path']).with_suffix('.meta.json')
        self.assertEqual(json.loads(metadata.read_text())['student_id'],'STUDENT_01')

    def test_boolean_evaluation_uses_assignments_and_reserved_display_names(self):
        spec=copy.deepcopy(STARTERS['boolean'])
        spec['parameters'][0]['mode']='true'
        spec['parameters'][1]['mode']='false'
        result=self.post('preview',spec,count=1)
        self.assertEqual(result.status_code,200,result.json)
        self.assertEqual(result.json['preview'][0]['answer'],'false')
        self.assertIn('p = ', result.json['pgml_code'])
        self.assertIn('context',result.json['source'])

    def test_composed_matrix_and_formula_operations_use_existing_libraries(self):
        matrix=starter('Determinant',[],[step('m','matrix2',*(literal(n) for n in (1,2,3,4))),step('result','matrix_determinant',ref('m'))], 'Find the determinant of {m}.','result')
        response=self.post('preview',matrix,count=1)
        self.assertEqual(response.status_code,200,response.json)
        self.assertEqual(response.json['preview'][0]['answer'],'-2')
        formula=starter('Differentiate',[],[step('x','formula_variable',literal('x')),step('p','formula_power',ref('x'),literal(3)),step('result','differentiate',ref('p'),literal('x'))],'Differentiate {p}.','result')
        response=self.post('check',formula)
        self.assertEqual(response.status_code,200,response.json)

    def test_every_catalog_adapter_executes_with_compatible_mathematical_values(self):
        base=[step('fx','formula_variable',literal('x')),step('zero','formula_constant',literal(0)),
              step('px','polynomial_variable',literal('x')),step('eq','equation',ref('fx'),ref('zero')),
              step('boolean_expr','bool_var',literal('p')),step('matrix','matrix_identity',literal(3)),
              step('vector','vector3',literal(1),literal(2),literal(3)),
              step('interval','set_interval',literal(0),literal(4),literal(True),literal(True)),step('finite','set_empty')]
        values={'Formula':'fx','Polynomial':'px','Equation':'eq','Boolean':'boolean_expr','Matrix':'matrix','Vector':'vector','Set':'interval','FiniteSet':'finite'}
        for operation in OPERATIONS:
            with self.subTest(operation=operation['id']):
                args=[literal(a['default']) if a['default'] is not None else ref(values[a['type']]) for a in operation['arguments']]
                steps=copy.deepcopy(base)+[step('result',operation['id'],*args)]
                answer='result'
                if operation['output'] not in CONTEXTS:
                    steps.append(step('fallback','add',literal(1),literal(1)));answer='fallback'
                specification=starter('Library adapter check',[],steps,'Compute the requested result.',answer)
                response=self.post('check',specification)
                self.assertEqual(response.status_code,200,response.json)

    def test_bool_count_argument_order_and_boolean_answer_context(self):
        spec=starter('Count models',[],[step('p','bool_var',literal('p')),step('q','bool_var',literal('q')),step('e','bool_and',ref('p'),ref('q')),step('result','bool_count',ref('e'),literal('and'))],'Count AND in {e}.','result')
        response=self.post('preview',spec,count=1)
        self.assertEqual(response.status_code,200,response.json)
        self.assertEqual(response.json['preview'][0]['answer'],'1')
        spec['answer']='e'
        response=self.post('preview',spec,count=1)
        self.assertEqual(response.status_code,200,response.json)
        self.assertIn('Context("Boolean")',response.json['pgml_code'])

    def test_check_and_failed_constraint_leave_no_history_outputs(self):
        spec=copy.deepcopy(STARTERS['polynomial'])
        spec['steps'].append(step('impossible','equal',literal(1),literal(2)))
        spec['constraints']=[{'ref':'impossible','expected':True}]
        response=self.post('save',spec)
        self.assertEqual(response.status_code,400,response.json)
        self.assertFalse((self.grammars/'my_visual.rhm').exists())
        self.assertEqual(list((self.root/'generator/generated_questions').glob('*')),[])
        self.assertFalse(list(self.grammars.glob('.visual_check_*')))

    def test_save_reopen_configure_and_update(self):
        response=self.post('save')
        self.assertEqual(response.status_code,200,response.json)
        first=response.json
        self.assertFalse(is_form_preset(self.grammars,'my_visual.rhm'))
        self.assertEqual((self.grammars/'my_visual.rhm').read_text(),first['source'])
        definition=self.client.get('/teacher/visual/definition?name=my_visual.rhm').json
        self.assertEqual(definition['revision'],first['revision'])
        schema=self.client.get('/teacher/schema?grammar=my_visual.rhm').json
        self.assertTrue(schema['success'],schema)
        self.assertEqual({f.get('label') for f in schema['schema']['fields'] if f['kind']=='range'},{'a','b','c','k'})
        configured=self.client.post('/teacher/generate',json={'grammar':'my_visual.rhm','configuration':{'values':{}},'count':1,'student_id':'FORM'})
        self.assertEqual(configured.status_code,200,configured.json)
        spec=copy.deepcopy(STARTERS['polynomial'])
        spec['steps'][-1]=step('result','polynomial_degree',ref('d'))
        spec['prompt']='Given {p}, find the degree of its derivative.'
        updated=self.post('save',spec,revision=first['revision'])
        self.assertEqual(updated.status_code,200,updated.json)
        self.assertNotEqual(updated.json['revision'],first['revision'])
        self.assertTrue(list((self.grammars/'.visual/history/my_visual.rhm').glob('*/source.rhm')))
        stale=self.post('save',revision=first['revision'])
        self.assertEqual(stale.status_code,409,stale.json)

    def test_manual_source_edits_and_existing_files_are_never_overwritten(self):
        self.assertEqual(self.post('save').status_code,200)
        definition=self.client.get('/teacher/visual/definition?name=my_visual.rhm').json
        path=self.grammars/'my_visual.rhm'
        changed=path.read_text()+'\n# changed in source mode\n'
        path.write_text(changed)
        self.assertEqual(self.client.get('/teacher/visual/definition?name=my_visual.rhm').status_code,409)
        self.assertEqual(self.post('save',revision=definition['revision']).status_code,409)
        self.assertEqual(path.read_text(),changed)
        for name in ('arithmetic.rhm','existing.rhm'):
            if name=='existing.rhm':(self.grammars/name).write_text('preserve me')
            self.assertEqual(self.post('save',name=name).status_code,409)
        self.assertEqual((self.grammars/'existing.rhm').read_text(),'preserve me')

    def test_path_links_invalid_json_and_cross_origin_writes(self):
        for name in ('../evil.rhm','/tmp/evil.rhm','.hidden.rhm','x.json'):
            self.assertEqual(self.post('save',name=name).status_code,400)
        target=self.grammars/'target.rhm'
        target.write_text('preserve')
        (self.grammars/'my_visual.rhm').symlink_to(target)
        self.assertEqual(self.post('save').status_code,409)
        self.assertEqual(target.read_text(),'preserve')
        self.assertEqual(self.client.post('/teacher/visual/check',json=[]).status_code,400)
        self.assertEqual(self.client.post('/teacher/visual/check',json={'specification':STARTERS['polynomial']},headers={'Origin':'https://other.example'}).status_code,403)
        self.assertEqual(self.client.post('/teacher/visual/check',data='x'*131073,content_type='application/json').status_code,413)

    def test_metadata_failure_rolls_back_an_update(self):
        saved=self.post('save').json
        path=self.grammars/'my_visual.rhm'
        before=path.read_bytes()
        spec=copy.deepcopy(STARTERS['polynomial']);spec['width']=20
        replace=os.replace
        def fail_metadata(source,target):
            if Path(target).suffix=='.json':raise OSError('simulated storage failure')
            return replace(source,target)
        with patch('visual_builder.os.replace',side_effect=fail_metadata):
            response=self.post('save',spec,revision=saved['revision'])
        self.assertEqual(response.status_code,500,response.json)
        self.assertEqual(path.read_bytes(),before)
        self.assertEqual(self.client.get('/teacher/visual/definition?name=my_visual.rhm').status_code,200)

    def test_definition_metadata_must_match_source(self):
        self.assertEqual(self.post('save').status_code,200)
        path=self.grammars/'.visual/my_visual.rhm.json'
        record=json.loads(path.read_text());record['specification']['width']=24;path.write_text(json.dumps(record))
        self.assertEqual(self.client.get('/teacher/visual/definition?name=my_visual.rhm').status_code,409)


if __name__=='__main__':
    unittest.main()
