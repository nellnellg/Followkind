"""One-time local password setup. Secrets are prompted, never saved."""
import getpass
import json
import urllib.request
import urllib.error

base = 'https://wjucsuzpflxznogsfdhx.supabase.co/auth/v1/admin'
email = 'nellnellg80@gmail.com'
key = getpass.getpass('Supabase secret key (hidden): ').strip()
password = getpass.getpass('New Followkind password (hidden, 12+ characters): ')
if len(password) < 12 or password != getpass.getpass('Repeat password (hidden): '):
    raise SystemExit('Passwords must match and have at least 12 characters. Nothing changed.')

def call(path, data=None):
    request = urllib.request.Request(base + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'},
        method='PUT' if data is not None else 'GET')
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise SystemExit('Setup failed (HTTP '+str(error.code)+'). Check the project secret key. No credentials were saved.')

user = None
for page in range(1, 101):
    users = call('/users?page='+str(page)+'&per_page=1000').get('users', [])
    user = next((item for item in users if item.get('email','').lower() == email), None)
    if user or len(users) < 1000:
        break
if not user:
    raise SystemExit('Coordinator account not found. Nothing changed.')
call('/users/'+user['id'], {'password':password})
print('Password set for your existing coordinator. Sign in to Followkind with email and password.')
