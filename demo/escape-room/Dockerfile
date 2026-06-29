FROM python:3.12.10-slim-bookworm@sha256:fd95fa221297a88e1cf49c55ec1828edd7c5a428187e67b5d1805692d11588db

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY control_room.py coolant_pump.py ./
RUN chmod 0555 /app/control_room.py /app/coolant_pump.py

RUN useradd --create-home --uid 10001 demo
USER demo
