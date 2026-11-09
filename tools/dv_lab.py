"""Send Lua to the temporary, single-player-only file bridge (not shipped as an autorun)."""
import json
import time
import uuid
from pathlib import Path

IPC = Path(__file__).resolve().parents[3] / 'data/bgn_dv_lab'


def send(realm, code, timeout=20):
    token = uuid.uuid4().hex
    request = IPC / f'{realm}_request.json'
    tmp = request.with_suffix('.tmp')
    tmp.write_text(json.dumps({'id': token, 'code': code}), encoding='utf-8')
    tmp.replace(request)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            response = json.loads((IPC / f'{realm}_response.json').read_text(encoding='utf-8'))
            if response['id'] == token:
                if not response['ok']:
                    raise RuntimeError(response['result'])
                return response.get('result')
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        time.sleep(.05)
    raise TimeoutError(f'{realm} bridge did not respond')


if __name__ == '__main__':
    import sys
    print(json.dumps(send(sys.argv[1], Path(sys.argv[2]).read_text(encoding='utf-8-sig')), ensure_ascii=False, indent=2))
