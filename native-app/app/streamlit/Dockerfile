FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app source
COPY streamlit_app.py .

# Streamlit config: disable CORS/XSRF for SPCS ingress
RUN mkdir -p /root/.streamlit
RUN printf '[server]\nheadless = true\nport = 8501\naddress = "0.0.0.0"\nenableCORS = false\nenableXsrfProtection = false\n' > /root/.streamlit/config.toml

EXPOSE 8501

ENTRYPOINT ["streamlit", "run", "streamlit_app.py"]
