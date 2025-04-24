# Standard library imports
import os
import sys
import datetime
from pathlib import Path

# Third-party imports
import streamlit as st
import torch
import numpy as np
from PIL import Image
import psycopg2
import pandas as pd
from streamlit_drawable_canvas import st_canvas

# Environment variables setup
ENV_VARS = {
    'DB_SERVICE_NAME': None,
    'DB_PORT': None,
    'DB_NAME': None,
    'DB_USER': None,
    'DB_PASSWORD': None,
    'DB_TIMEOUT': None,
    'CONTAINER_WORKDIR_NAME': None,
    'TRAINED_MODEL_DIR_NAME': None,
    'TRAINED_MODEL_NAME': None,
    'MODEL_FILE_NAME': None
}

def load_environment_variables():
    """Load and validate environment variables, return processed configuration."""
    # Load environment variables
    for var in ENV_VARS:
        ENV_VARS[var] = os.getenv(var)
        if ENV_VARS[var] is None:
            st.error(f"Missing required environment variable: {var}")
            sys.exit(1)
    
    # Convert environment variables to appropriate types and create config
    config = {
        'db': {
            'host': ENV_VARS['DB_SERVICE_NAME'],
            'port': ENV_VARS['DB_PORT'],
            'database': ENV_VARS['DB_NAME'],
            'user': ENV_VARS['DB_USER'],
            'password': ENV_VARS['DB_PASSWORD'],
            'timeout': int(ENV_VARS['DB_TIMEOUT'])
        },
        'model': {
            'path': Path(f"/{ENV_VARS['CONTAINER_WORKDIR_NAME']}/{ENV_VARS['TRAINED_MODEL_DIR_NAME']}/{ENV_VARS['TRAINED_MODEL_NAME']}"),
            'file': ENV_VARS['MODEL_FILE_NAME']
        }
    }
    
    return config

# Load configuration at module level
CONFIG = load_environment_variables()

def get_db_connection():
    """Get a connection to the PostgreSQL database."""
    try:
        return psycopg2.connect(
            host=CONFIG['db']['host'],
            port=CONFIG['db']['port'],
            database=CONFIG['db']['database'],
            user=CONFIG['db']['user'],
            password=CONFIG['db']['password'],
            connect_timeout=CONFIG['db']['timeout']
        )
    except psycopg2.Error as e:
        st.error(f"Database connection error: {e}")
        return None

def log_prediction(predicted_digit, confidence, true_label):
    """Log a prediction to the database."""
    conn = get_db_connection()
    if not conn:
        return False
    
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO predictions (predicted_digit, true_label, confidence, timestamp) VALUES (%s, %s, %s, %s)",
                (predicted_digit, true_label, confidence, datetime.datetime.now())
            )
            conn.commit()
            return True
    except Exception as e:
        st.error(f"Error logging prediction: {e}")
        return False
    finally:
        conn.close()

def get_prediction_history(limit=10):
    """Get prediction history from the database."""
    conn = get_db_connection()
    if not conn:
        return []
    
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT timestamp, predicted_digit, true_label, confidence FROM predictions ORDER BY timestamp DESC LIMIT %s",
                (limit,)
            )
            return cur.fetchall()
    except Exception as e:
        st.error(f"Error fetching prediction history: {e}")
        return []
    finally:
        conn.close()

def load_model():
    """Load the trained model weights."""
    if not CONFIG['model']['path'].exists():
        st.error("No trained model found. Please train a model first.")
        st.info(f"Looking for model at: {CONFIG['model']['path']}")
        sys.exit(1)

    try:
        # Add model directory to Python path
        model_dir = CONFIG['model']['path'].parent
        if str(model_dir) not in sys.path:
            sys.path.append(str(model_dir))
        
        from model import MNISTModel
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        model = MNISTModel().to(device)
        model.load_state_dict(torch.load(CONFIG['model']['path'], map_location=device))
        model.eval()
        return model
    except Exception as e:
        st.error(f"Error loading model: {e}")
        sys.exit(1)

def process_image_for_prediction(image_data):
    """Process image data for model prediction."""
    image = image_data.convert('L').resize((28, 28))
    image_tensor = torch.tensor(np.array(image)).float() / 255.0
    return image_tensor.unsqueeze(0).unsqueeze(0)

def predict(model, image_tensor):
    """Make a prediction with the model."""
    device = next(model.parameters()).device
    image_tensor = image_tensor.to(device)
    
    with torch.no_grad():
        output = model(image_tensor)
        probabilities = torch.nn.functional.softmax(output, dim=1)
        prediction = output.argmax(dim=1)
        confidence = probabilities.max(dim=1)[0]
    
    return prediction.item(), confidence.item()

def main():
    st.title("Digit Recogniser")
    
    # Create two equal columns for layout
    col1, col2 = st.columns(2)
    
    model = load_model()
    
    # Drawing canvas in the left column
    with col1:
        canvas_result = st_canvas(
            fill_color="black",
            stroke_width=20,
            stroke_color="white",
            background_color="black",
            width=280,
            height=280,
            drawing_mode="freedraw",
            key="canvas",
        )
    
    # Prediction area in the right column
    with col2:
        # Process image if it exists
        if canvas_result.image_data is not None:
            image_tensor = process_image_for_prediction(Image.fromarray(canvas_result.image_data))
            predicted_digit, confidence = predict(model, image_tensor)
            default_value = predicted_digit
        else:
            predicted_digit = 0
            confidence = 0
            default_value = 0
        
        # Layout with aligned labels and values
        label_col, value_col = st.columns([0.3, 0.7])
        
        with label_col:
            st.write("Prediction:")
            st.write("Confidence:")
            st.write("True label:")
            st.write("")
        
        with value_col:
            st.write(f"{predicted_digit}")
            st.write(f"{confidence*100:.0f}%")
            true_label = st.number_input("", 
                                       min_value=0, 
                                       max_value=9, 
                                       value=default_value,
                                       step=1,
                                       label_visibility="collapsed")
            if st.button("Submit"):
                if log_prediction(predicted_digit, confidence, true_label):
                    st.info("Prediction logged to database")
                else:
                    st.warning("Failed to log prediction to database")
    
    # History section below both columns
    st.subheader("History")
    predictions = get_prediction_history()
    if predictions:
        df = pd.DataFrame(predictions, columns=["Timestamp", "Predicted Digit", "True Label", "Confidence"])
        df["Confidence"] = df["Confidence"].apply(lambda x: f"{x:.2f}")
        st.dataframe(df, hide_index=True)
    else:
        st.info("No predictions have been made yet")

if __name__ == '__main__':
    main() 