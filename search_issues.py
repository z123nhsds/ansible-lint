import urllib.request, json
url = "https://api.github.com/search/issues?q=repo:ansible/ansible-lint+PYTHONPATH+pre-commit+requirements_file"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
res = urllib.request.urlopen(req)
issues = json.loads(res.read())
for i in issues.get('items', []):
    print(f"#{i['number']}: {i['title']}")
