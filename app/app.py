import streamlit as st
import torch
import numpy as np
from PIL import Image
import io
import sys
import os
import datetime
import psycopg2
import pandas as pd
from dotenv import load_dotenv
from streamlit_drawable_canvas import st_canvas

# Add the model directory to Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from model.model import MNISTModel

# Load environment variables
load_dotenv()

# Database connection parameters
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'mnist_db')
DB_USER = os.getenv('DB_USER', 'dormouse')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')

def get_db_connection():
    try:
        # Use Unix domain socket connection
        conn = psycopg2.connect(dbname=DB_NAME)
        return conn
    except psycopg2.Error as e:
        st.error(f"Database connection failed: {str(e)}")
        return None

def log_prediction(prediction, true_label, confidence):
    try:
        conn = get_db_connection()
        if conn is None:
            return
            
        cur = conn.cursor()
        cur.execute(
            """
            INSERT INTO predictions (timestamp, predicted_digit, true_label, confidence)
            VALUES (%s, %s, %s, %s)
            """,
            (datetime.datetime.now(), prediction, true_label, confidence)
        )
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        st.error(f"Failed to log prediction: {str(e)}")

def get_prediction_history():
    try:
        conn = get_db_connection()
        if conn is None:
            return pd.DataFrame()
            
        query = """
        SELECT timestamp, predicted_digit as pred, true_label as label
        FROM predictions
        ORDER BY timestamp DESC
        LIMIT 10
        """
        df = pd.read_sql_query(query, conn)
        conn.close()
        return df
    except Exception as e:
        st.error(f"Failed to fetch history: {str(e)}")
        return pd.DataFrame()

def load_model():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = MNISTModel().to(device)
    
    # Get the absolute path to the model file
    current_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(os.path.dirname(current_dir), 'saved_models', 'mnist_model.pth')
    
    if not os.path.exists(model_path):
        st.error(f"Model file not found at {model_path}. Please train the model first.")
        return None
        
    model.load_state_dict(torch.load(model_path, map_location=device))
    model.eval()
    return model

def preprocess_image(image):
    # Convert to grayscale
    image = image.convert('L')
    # Resize to 28x28
    image = image.resize((28, 28))
    # Convert to numpy array and normalize
    image = np.array(image)
    image = image.astype('float32') / 255.0
    # Normalize using MNIST mean and std
    image = (image - 0.1307) / 0.3081
    # Prepare for PyTorch (add batch and channel dimensions)
    image = torch.from_numpy(image).unsqueeze(0).unsqueeze(0)
    return image

def main():
    st.title("Digit Recognizer", anchor=False)

    # Initialize session state
    if 'prediction' not in st.session_state:
        st.session_state.prediction = None
        st.session_state.confidence = None

    # Create a canvas for drawing
    canvas_result = st_canvas(
        stroke_width=20,
        stroke_color='#FFFFFF',
        background_color='#000000',
        height=280,
        width=280,
        drawing_mode="freedraw",
        key="canvas",
    )
    
    # Initialize the model
    model = load_model()
    
    if model is None:
        st.stop()

    col1, col2 = st.columns([2, 3])

    with col1:
        if canvas_result.image_data is not None:
            # Convert the canvas to PIL Image
            image = Image.fromarray(canvas_result.image_data.astype('uint8'))
            if image.getextrema() != (0, 0):  # Check if the image is not empty
                # Preprocess the image
                processed_image = preprocess_image(image)
                
                # Get prediction
                prediction, confidence = model.predict(processed_image)
                st.session_state.prediction = prediction
                st.session_state.confidence = confidence

    with col2:
        if st.session_state.prediction is not None:
            st.write(f"Prediction: {st.session_state.prediction}")
            st.write(f"Confidence: {st.session_state.confidence:.0%}")
            
            # Allow user to input true label
            true_label = st.number_input("True label:", 
                                       min_value=0, 
                                       max_value=9,
                                       step=1)

            if st.button('Submit'):
                # Log the prediction
                log_prediction(st.session_state.prediction, true_label, st.session_state.confidence)
                st.success("Prediction logged successfully!")

    # Display prediction history
    st.subheader("History")
    history_df = get_prediction_history()
    if not history_df.empty:
        st.dataframe(
            history_df,
            hide_index=True,
            column_config={
                "timestamp": st.column_config.DatetimeColumn(
                    "timestamp",
                    format="YYYY-MM-DD HH:mm:ss"
                )
            }
        )

if __name__ == "__main__":
    main() 