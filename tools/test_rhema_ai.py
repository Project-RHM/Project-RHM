"""Mocked provider tests: no real credentials, paid requests or generated code execution."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

from flask import Flask
import requests

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from api_keys import save_verified
from rhema_ai import DeepSeekCompletionClient, CompletionError, clean_completion, register_ai_routes

KEY='QA-DUMMY-KEY-NOT-ACTUAL'
HEADERS={'X-Rhema-Request':'1'}


class CompletionRoutesTests(unittest.TestCase):
    def setUp(self):
        temporary=tempfile.TemporaryDirectory();self.addCleanup(temporary.cleanup)
        self.key_file=Path(temporary.name)/'credentials.json'
        self.provider=Mock();self.provider.complete.return_value='$1.expr, $3.expr)'
        app=Flask(__name__)
        register_ai_routes(app,ROOT,lambda:self.key_file,self.provider)
        self.client=app.test_client()
        clock=patch('rhema_ai.time.monotonic',return_value=100)
        self.clock=clock.start();self.addCleanup(clock.stop)

    def verified(self):
        save_verified(self.key_file,KEY,{'provider':'DeepSeek','available':True,'verified_at':'2026-11-05'},model='deepseek-flash')

    def complete(self,**changes):
        data={'prefix':'expr = bool_and(','suffix':'','declarations':'synth expr on E','consent':True,**changes}
        return self.client.post('/api/rhema/complete',json=data,headers=HEADERS)

    def test_unverified_key_cannot_trigger_completion(self):
        self.assertEqual(self.complete().json['code'],'key_required')
        self.provider.complete.assert_not_called()

    def test_consent_origins_types_and_limits_are_enforced(self):
        for changes in ({'consent':False},{'prefix':6001*'x'},{'suffix':True},{'declarations':2001*'x'},{'filename':'private.env'}):
            self.assertEqual(self.complete(**changes).status_code,400)
        self.assertEqual(self.client.post('/api/rhema/complete',json={},headers={**HEADERS,'Origin':'https://untrusted.invalid'}).status_code,403)
        self.assertEqual(self.client.post('/api/rhema/complete',json={}).status_code,403)
        self.provider.complete.assert_not_called()

    def test_remote_clients_and_untrusted_hostnames_cannot_use_saved_key(self):
        self.verified()
        for options in ({'environ_overrides':{'REMOTE_ADDR':'203.0.113.1'}},
                        {'base_url':'http://untrusted.invalid'}):
            response=self.client.post('/api/rhema/complete',json={'consent':True},headers=HEADERS,**options)
            self.assertEqual(response.status_code,403)
        self.provider.complete.assert_not_called()

    def test_valid_completion_uses_bounded_context_and_canonical_functions(self):
        self.verified();response=self.complete()
        self.assertEqual(response.status_code,200,response.json)
        self.assertEqual(response.json['completion'],'$1.expr, $3.expr)')
        self.assertEqual(response.headers['Cache-Control'],'no-store')
        key,model,messages=self.provider.complete.call_args.args
        self.assertEqual((key,model),(KEY,'deepseek-flash'))
        self.assertIn('bool_and(arg1, arg2)',messages[0]['content'])
        self.assertNotIn('matrix_inverse(arg1)',messages[0]['content'])
        self.assertNotIn(KEY,json.dumps(messages))
        self.assertNotIn(KEY,response.get_data(as_text=True))

    def test_rate_limit_does_not_call_provider_twice(self):
        self.verified();self.assertTrue(self.complete().json['success'])
        self.assertEqual(self.complete().json['code'],'completion_busy')
        self.assertEqual(self.provider.complete.call_count,1)
        self.clock.return_value+=2
        self.assertTrue(self.complete().json['success'])

    def test_credentials_in_context_are_not_sent(self):
        self.verified()
        for source in (KEY,'let key = "sk-abcdefghijklmnop"'):
            self.assertEqual(self.complete(prefix=source).json['code'],'sensitive_context')
        self.provider.complete.assert_not_called()

    def test_invalid_provider_output_is_not_offered(self):
        self.verified()
        for output in ('```rhema\nfoo\n```','unknown_builtin(1)','api_key = secret',KEY,'x'*301):
            self.clock.return_value+=2;self.provider.complete.return_value=output
            self.assertEqual(self.complete().json['completion'],'')

    def test_provider_failure_is_a_safe_error_and_keeps_key(self):
        self.verified();before=self.key_file.read_bytes()
        self.provider.complete.side_effect=CompletionError('DeepSeek reports insufficient balance.','insufficient_balance',400)
        response=self.complete()
        self.assertEqual(response.status_code,400)
        self.assertNotIn(KEY,response.get_data(as_text=True))
        self.assertEqual(self.key_file.read_bytes(),before)


class CompletionClientTests(unittest.TestCase):
    def setUp(self):
        self.session=Mock();self.client=DeepSeekCompletionClient(self.session)

    def test_request_only_targets_official_endpoint(self):
        self.session.post.return_value=Mock(status_code=200)
        self.session.post.return_value.json.return_value={'choices':[{'message':{'content':'str(1)'}}]}
        self.assertEqual(self.client.complete(KEY,'deepseek-flash',[]),'str(1)')
        args,kwargs=self.session.post.call_args
        self.assertEqual(args[0],'https://api.deepseek.com/chat/completions')
        self.assertFalse(kwargs['allow_redirects'])
        self.assertEqual(kwargs['json']['thinking'],{'type':'disabled'})
        self.assertEqual(kwargs['json']['max_tokens'],160)
        self.assertNotIn(KEY,json.dumps(kwargs['json']))

    def test_network_errors_never_expose_exception_or_key(self):
        self.session.post.side_effect=requests.Timeout(KEY)
        with self.assertRaises(CompletionError) as caught:self.client.complete(KEY,'deepseek-flash',[])
        self.assertNotIn(KEY,str(caught.exception))

    def test_http_and_invalid_json_are_handled(self):
        for status in (302,401,402,403,429,500):
            self.session.post.return_value=Mock(status_code=status)
            with self.assertRaises(CompletionError):self.client.complete(KEY,'deepseek-flash',[])
        self.session.post.return_value=Mock(status_code=200)
        self.session.post.return_value.json.return_value={'choices':[]}
        with self.assertRaises(CompletionError):self.client.complete(KEY,'deepseek-flash',[])

    def test_filter_keeps_fragments_but_not_fenced_prose_or_unknown_calls(self):
        known={'bool_and','cond'}
        self.assertEqual(clean_completion('$1.expr, $3.expr)','expr = bool_and(','',known),'$1.expr, $3.expr)')
        self.assertEqual(clean_completion('require (cost >= 1)','','',known),'require (cost >= 1)')
        self.assertEqual(clean_completion('invented(1)','','',known),'')
        self.assertEqual(clean_completion(')','',')',known),'')
        self.assertEqual(clean_completion('first\nsecond','','',known),'first')


if __name__=='__main__':unittest.main()
