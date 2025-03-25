#!/bin/bash

# Activate the virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
fi

# Make sure the required Python packages are installed
pip install -r requirements.txt

# Run the Streamlit app
export PYTHONPATH=$PWD
streamlit run app/app.py 