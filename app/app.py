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

# Load environment variables - first try local/.env.local, then fall back to .env for production
env_file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'local', '.env.local')
if os.path.exists(env_file_path):
    load_dotenv(env_file_path)
else:
    # Use .env for production or fall back to default load_dotenv behavior
    production_env = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
    if os.path.exists(production_env):
        load_dotenv(production_env)
    else:
        load_dotenv()

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
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=10  # Increased timeout
        )
        return conn
    except psycopg2.Error:
        # When using Docker Compose, the service name 'db' should be used
        if DB_HOST != 'db' and 'docker' in os.environ.get('HOSTNAME', ''):
            try:
                conn = psycopg2.connect(
                    host='db',
                    port=DB_PORT,
                    dbname=DB_NAME,
                    user=DB_USER,
                    password=DB_PASSWORD,
                    connect_timeout=10
                )
                return conn
            except psycopg2.Error:
                pass
        
        # Try Docker container connection
        if DB_HOST == 'localhost':
            try:
                # Get container IP
                import subprocess
                result = subprocess.run(
                    ["docker", "inspect", "-f", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", "mnist-digit-recognizer-db-1"],
                    capture_output=True, text=True, check=True
                )
                container_ip = result.stdout.strip()
                
                if container_ip:
                    conn = psycopg2.connect(
                        host=container_ip,
                        port=DB_PORT,
                        dbname=DB_NAME,
                        user=DB_USER,
                        password=DB_PASSWORD,
                        connect_timeout=10
                    )
                    return conn
            except Exception:
                pass
        
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
    except Exception:
        pass

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
                    log_prediction(prediction, true_label, confidence)
                    st.success("Prediction logged!")
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