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
from model import model

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
DB_TIMEOUT = int(os.getenv('DB_TIMEOUT', '30'))

# Check if we're running in development mode
is_development = os.getenv('IS_DEVELOPMENT', 'false').lower() == 'true'

# If running in development mode on a local machine and DB_HOST is 'db', 
# we may need to adjust it for direct connections
if is_development and not os.path.exists('/.dockerenv') and DB_HOST == 'db':
    DB_HOST = 'localhost'

def get_db_connection():
    """Connect to the database using environment variables."""
    # Log connection attempt for debugging
    connection_params = {
        'host': DB_HOST,
        'port': DB_PORT,
        'dbname': DB_NAME,
        'user': DB_USER,
        'password': '****'  # masked for security
    }
    print(f"Attempting database connection with: {connection_params}")
    
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=DB_TIMEOUT
        )
        print("Database connection successful")
        return conn
    except psycopg2.Error as e:
        error_msg = f"Database connection failed: {str(e)}"
        print(error_msg)
        
        # Try alternative connection if needed
        if DB_HOST != 'db' and not is_development:
            try:
                print("Trying fallback connection to 'db' service...")
                conn = psycopg2.connect(
                    host='db',
                    port=DB_PORT,
                    dbname=DB_NAME,
                    user=DB_USER,
                    password=DB_PASSWORD,
                    connect_timeout=DB_TIMEOUT
                )
                print("Fallback connection successful")
                return conn
            except psycopg2.Error as e2:
                print(f"Fallback connection failed: {str(e2)}")
        
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
    model_instance = model.MNISTModel().to(device)
    
    # Get model path directly from environment variable
    model_path = os.getenv('MODEL_PATH')
    
    # Debug: Print information about model path
    print(f"Loading model from: {model_path}")
    print(f"Model file exists: {os.path.exists(model_path)}")
    print(f"Directory listing:")
    model_dir = os.path.dirname(model_path)
    if os.path.exists(model_dir):
        print(f"Contents of {model_dir}: {os.listdir(model_dir)}")
    else:
        print(f"Directory {model_dir} does not exist")
    
    # Try to load model
    model_instance.load_state_dict(torch.load(model_path, map_location=device))
    model_instance.eval()
    return model_instance

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
    st.title("Digit Recogniser", anchor=False)
    
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
            else:
                st.write("Draw a digit to see prediction")
        else:
            st.write("Draw a digit to see prediction")

    # Display prediction history
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