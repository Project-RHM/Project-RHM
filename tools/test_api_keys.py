"""All provider traffic is mocked; tests never use real keys or paid generation."""
import importlib.util
import io
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

import requests

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from api_keys import DeepSeekKeyValidator, ApiKeyError
spec = importlib.util.spec_from_file_location('api_key_test_app',ROOT/'app.py')
web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web)
KEY = 'example-not-a-real-api-key'


class ApiKeyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)/'keys.json'
        self.path.write_text(json.dumps({'default_user':'1','other_setting':42}))
        self.original = self.path.read_bytes()
        self.session = Mock()
        self.validator = DeepSeekKeyValidator(self.session)
        self.patches = [patch.object(web,'USER_API_KEYS_FILE',str(self.path)),patch.object(web,'API_KEY_VALIDATOR',self.validator)]
        for p in self.patches:
            p.start();self.addCleanup(p.stop)
        self.client = web.app.test_client()

    def response(self,status=200,payload=None):
        self.session.get.return_value = Mock(status_code=status)
        self.session.get.return_value.json.return_value = payload if payload is not None else {'is_available':True}

    def save(self,key=KEY):
        return self.client.post('/save_api_key',data={'api_key':key})

    def test_legacy_key_is_not_claimed_verified(self):
        data = self.client.get('/api_key_status').json
        self.assertTrue(data['has_api_key']);self.assertFalse(data['verified'])
        self.assertNotIn('default_user',data)
        self.session.get.assert_not_called()

    def test_short_or_malformed_inputs_never_contact_provider(self):
        for value in ('1','','abc def ghijk','a'*513,'\x01abcdefgh','秘密abcdefgh'):
            with self.subTest(value=value):
                self.assertFalse(self.save(value).json['success'])
                self.assertEqual(self.path.read_bytes(),self.original)
        self.session.get.assert_not_called()

    def test_success_saves_verified_status_without_returning_secret(self):
        self.response()
        response = self.save()
        self.assertTrue(response.json['success']);self.assertTrue(response.json['verified'])
        self.assertTrue(response.json['available']);self.assertNotIn(KEY,response.get_data(as_text=True))
        data = json.loads(self.path.read_text())
        self.assertEqual(data['other_setting'],42);self.assertEqual(data['default_user'],KEY)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode),0o600)
        status = self.client.get('/api_key_status')
        self.assertTrue(status.json['verified']);self.assertNotIn(KEY,status.get_data(as_text=True))
        self.assertEqual(status.headers['Cache-Control'],'no-store')
        args,kwargs = self.session.get.call_args
        self.assertEqual(args[0],'https://api.deepseek.com/user/balance')
        self.assertFalse(kwargs['allow_redirects']);self.assertIn('timeout',kwargs)

    def test_valid_authentication_without_balance_is_distinguished(self):
        self.response(payload={'is_available':False})
        data = self.save().json
        self.assertTrue(data['verified']);self.assertFalse(data['available'])
        self.assertIn('insufficient balance',data['message'])

    def test_provider_failures_preserve_saved_configuration(self):
        for status,code in ((401,'invalid_api_key'),(403,'invalid_api_key'),(402,'insufficient_balance'),(429,'validation_rate_limited'),(500,'validation_unavailable'),(302,'validation_unavailable')):
            with self.subTest(status=status):
                self.response(status)
                self.assertEqual(self.save().json['code'],code)
                self.assertEqual(self.path.read_bytes(),self.original)

    def test_network_failure_preserves_key_and_redacts_exception(self):
        self.session.get.side_effect = requests.Timeout('sensitive '+KEY)
        response = self.save()
        self.assertEqual(response.status_code,503)
        self.assertNotIn(KEY,response.get_data(as_text=True))
        self.assertEqual(self.path.read_bytes(),self.original)

    def test_malformed_success_response_is_not_accepted(self):
        for payload in ({},{'is_available':'true'},[],None):
            self.response(payload={} if payload is None else payload)
            self.assertFalse(self.save().json['success'])
            self.assertEqual(self.path.read_bytes(),self.original)

    def test_bad_json_is_not_accepted(self):
        self.response();self.session.get.return_value.json.side_effect=ValueError()
        self.assertFalse(self.save().json['success'])

    def test_removal_is_idempotent_and_preserves_other_settings(self):
        self.response();self.save()
        for _ in range(2):
            response=self.client.delete('/api_key')
            self.assertTrue(response.json['success']);self.assertFalse(response.json['has_api_key'])
        self.assertEqual(json.loads(self.path.read_text()),{'other_setting':42})

    def test_changed_secret_invalidates_stored_verification(self):
        self.response();self.save()
        data=json.loads(self.path.read_text());data['default_user']='changed'
        self.path.write_text(json.dumps(data))
        self.assertFalse(self.client.get('/api_key_status').json['verified'])

    def test_unverified_credentials_cannot_trigger_generation(self):
        response=self.client.post('/generate_context',data={'student_id':'TEST','original_pg_path':'none.pg'})
        self.assertEqual(response.status_code,400)
        self.session.get.assert_not_called()

    def import_config(self, raw, **headers):
        return self.client.post('/import_api_key', headers={'X-Rhema-Request':'1', **headers},
            data={'config':(io.BytesIO(raw),'../../untrusted.json')})

    def test_template_is_public_and_contains_no_saved_key(self):
        response=self.client.get('/api_key_template')
        self.assertEqual(response.status_code,200)
        self.assertEqual(json.loads(response.data)['api_key'],'PASTE_YOUR_KEY_HERE')
        self.assertIn('attachment',response.headers['Content-Disposition'])
        response.close()
        self.session.get.assert_not_called()

    def test_import_validates_key_and_model_without_exposing_secret(self):
        self.response()
        response=self.import_config(json.dumps({'provider':'DeepSeek','api_key':KEY,'model':'deepseek-v4-pro'}).encode())
        self.assertEqual(response.status_code,200,response.json)
        self.assertTrue(response.json['verified'])
        self.assertEqual(response.json['model'],'deepseek-v4-pro')
        self.assertNotIn(KEY,response.get_data(as_text=True))
        self.assertEqual(json.loads(self.path.read_text())['other_setting'],42)
        self.assertEqual(stat.S_IMODE(self.path.stat().st_mode),0o600)
        self.assertEqual([p.name for p in self.path.parent.iterdir()],['keys.json'])
        self.client.delete('/api_key')
        self.assertNotIn('default_user_model',json.loads(self.path.read_text()))

    def test_invalid_imports_do_not_contact_provider_or_change_key(self):
        cases=[b'',b'x'*8193,b'\xff',b'[]',b'{}',b'{"api_key":"PASTE_YOUR_KEY_HERE"}',
            b'{"api_key":"1"}',b'{"api_key":"abc123456","api_key":"duplicate"}',
            json.dumps({'api_key':KEY,'base_url':'https://untrusted.invalid'}).encode(),
            json.dumps({'api_key':KEY,'model':'unknown'}).encode(),
            json.dumps({'api_key':KEY,'provider':'Other'}).encode()]
        for raw in cases:
            with self.subTest(length=len(raw)):
                self.assertFalse(self.import_config(raw).json['success'])
                self.assertEqual(self.path.read_bytes(),self.original)
        self.session.get.assert_not_called()

    def test_rejected_import_preserves_saved_key(self):
        self.response(401)
        response=self.import_config(json.dumps({'api_key':KEY}).encode())
        self.assertEqual(response.json['code'],'invalid_api_key')
        self.assertEqual(self.path.read_bytes(),self.original)

    def test_cross_origin_import_is_rejected(self):
        response=self.import_config(json.dumps({'api_key':KEY}).encode(),Origin='https://untrusted.invalid')
        self.assertEqual(response.status_code,403)
        self.session.get.assert_not_called()


if __name__=='__main__':
    unittest.main(verbosity=2)
