```
python -m venv .venv

. ./.venv/bin/activate

pip install dash pandas

pip freeze > requirements.txt

docker build . -t montumodi/test-dash-v2

docker push montumodi/test-dash-v2:latest

```