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
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from model.model import MNISTModel

# Load environment variables
project_root = os.path.dirname(os.path.abspath(__file__))

# Load environment variables from .env file
env_file = os.path.join(project_root, '.env')
if os.path.exists(env_file):
    load_dotenv(env_file)
else:
    print("Warning: No environment file found. Using default values.")

# Database connection parameters
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'mnist_db')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'postgres')

# Check if we're running directly on the host machine (not in Docker)
is_running_locally = not os.environ.get('HOSTNAME', '').startswith('mnist-digit-')

# If running locally and DB_HOST is set to 'db', we need to use localhost instead
if is_running_locally and DB_HOST == 'db':
    DB_HOST = 'localhost'

def get_db_connection():
    """Connect to the database using environment variables."""
    error_msg = None
    
    # Log connection attempt for debugging
    connection_params = {
        'host': DB_HOST,
        'port': DB_PORT,
        'dbname': DB_NAME,
        'user': DB_USER,
        'password': '****' # masked for security
    }
    print(f"Attempting database connection with: {connection_params}")
    
    # When in Docker, always try 'db' hostname first
    if os.path.exists('/.dockerenv') or os.environ.get('HOSTNAME', '').startswith('mnist-digit-'):
        print("Docker environment detected, trying 'db' hostname first...")
        try:
            conn = psycopg2.connect(
                host='db',
                port=DB_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD,
                connect_timeout=10
            )
            print("Docker network connection successful")
            return conn
        except psycopg2.Error as e:
            error_msg = f"Docker network connection failed: {str(e)}"
            print(error_msg)
    
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=10  # Increased timeout
        )
        print("Database connection successful")
        return conn
    except psycopg2.Error as e:
        error_msg = f"Primary connection failed: {str(e)}"
        print(error_msg)
        
        # Try fallback connection if needed
        if DB_HOST != 'db':
            try:
                print("Trying fallback connection to 'db' service...")
                conn = psycopg2.connect(
                    host='db',
                    port=DB_PORT,
                    dbname=DB_NAME,
                    user=DB_USER,
                    password=DB_PASSWORD,
                    connect_timeout=10
                )
                print("Fallback connection successful")
                return conn
            except psycopg2.Error as e:
                error_msg = f"{error_msg}\nFallback connection failed: {str(e)}"
                print(f"Fallback connection failed: {str(e)}")
        
        print(f"All connection attempts failed: {error_msg}")
        return None

def log_prediction(prediction, true_label, confidence):
    try:
        conn = get_db_connection()
        if conn is None:
            st.warning("Could not connect to database. Prediction not saved.")
            return False
            
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
        return True
    except Exception as e:
        st.error(f"Error saving prediction: {str(e)}")
        return False

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
    except Exception:
        return pd.DataFrame()

def load_model():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = MNISTModel().to(device)
    
    # Get model path from environment variable
    model_path = os.getenv('MODEL_PATH', '/app/model/saved_models/mnist_model.pth')
    
    # Check if model exists at the specified path
    if not os.path.exists(model_path):
        # Fallback to local development path as a backup
        project_root = os.path.dirname(os.path.abspath(__file__))
        fallback_path = os.path.join(project_root, 'model', 'saved_models', 'mnist_model.pth')
        
        if os.path.exists(fallback_path):
            model_path = fallback_path
            print(f"Using fallback model path: {model_path}")
        else:
            st.error(f"Model file not found at: {model_path} or {fallback_path}")
            return None
    
    print(f"Loading model from: {model_path}")
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
    
    # Add more space after the title
    st.markdown("<br>", unsafe_allow_html=True)
    
    # Initialize session state
    if 'prediction' not in st.session_state:
        st.session_state.prediction = None
        st.session_state.confidence = None

    # Layout with two columns for drawing and result
    col1, col2 = st.columns([1, 1])

    # Create a canvas for drawing in the left column
    with col1:
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

    # Display prediction result and controls in the right column
    with col2:
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
                
                # Display results
                st.markdown(f"**Prediction:** {st.session_state.prediction}")
                st.markdown(f"**Confidence:** {st.session_state.confidence:.0%}")
                
                # Add submit option
                st.markdown(f"**True label:**")
                true_label = st.number_input("", 
                                        min_value=0, max_value=9, step=1,
                                        value=int(prediction),
                                        label_visibility="collapsed")
                
                if st.button("Submit"):
                    if log_prediction(prediction, true_label, confidence):
                        st.success("Prediction logged successfully!")
                    # Error message is already shown by log_prediction if it fails
            else:
                st.write("Draw a digit to see prediction")
        else:
            st.write("Draw a digit to see prediction")

    # Display prediction history below (removed the divider line)
    st.markdown("### History")
    history_df = get_prediction_history()
    if not history_df.empty:
        # Calculate dynamic height based on number of rows (about 35px per row, plus 35px for header)
        table_height = min(35 * (len(history_df) + 1), 300)
        
        st.dataframe(
            history_df,
            hide_index=True,
            column_config={
                "timestamp": st.column_config.DatetimeColumn(
                    "timestamp",
                    format="YYYY-MM-DD HH:mm:ss"
                ),
                "pred": "prediction",
                "label": "label"
            },
            height=table_height
        )
    else:
        st.info("No prediction history yet")

if __name__ == "__main__":
    main() 