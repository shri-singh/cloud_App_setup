# Sample Streamlit App

A minimal working Streamlit application to test your EC2 deployment.

## Files

| File | Purpose |
|---|---|
| `app.py` | Main Streamlit application |
| `requirements.txt` | Python package dependencies |
| `.env.example` | Template for environment variables (safe to commit) |

## Quick Start

```bash
# 1. Create your .env file from the example
cp .env.example .env
nano .env   # Fill in your actual values

# 2. Create virtual environment (use Python 3.11)
/usr/local/bin/python3.11 -m venv venv
source venv/bin/activate

# 3. Install dependencies
pip install --upgrade pip==24.0
pip install -r requirements.txt

# 4. Run the app
streamlit run app.py --server.port 8501 --server.address 0.0.0.0
```

## What the App Shows

- Environment status (reads `APP_ENV` from `.env`)
- Health check indicators
- Whether API keys are configured (without showing the values)
- Sample pandas DataFrame and line chart

## Environment Variables

| Variable | Description | Required |
|---|---|---|
| `APP_ENV` | `development` or `production` | No (defaults to `development`) |
| `OPENAI_API_KEY` | OpenAI API key | No (app checks if set) |
| `STREAMLIT_SERVER_PORT` | Port to run on | No (defaults to `8501`) |

## Notes

- Never commit your `.env` file — it contains secrets
- `.env.example` is safe to commit — it contains no real values
- The app intentionally does not display secret values in the UI
