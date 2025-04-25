# Standard library imports
import os
import sys

# Third-party imports
import streamlit as st
from streamlit_drawable_canvas import st_canvas
import requests


# Load environment variables, return processed configuration
def load_environment_variables():
    for var in ENV_VARS:
        ENV_VARS[var] = os.getenv(var)
        if ENV_VARS[var] is None:
            st.error(f"Missing required environment variable: {var}")
            sys.exit(1)
    config = {
        'api_base_url': f"http://{ENV_VARS['WEBSERVER_SERVICE_NAME']}:{ENV_VARS['WEBSERVER_PORT']}",
        'history_limit': int(ENV_VARS['PREDICTION_HISTORY_LIMIT']),
        'canvas_size': 10 * int(ENV_VARS['MNIST_DATASET_IMAGE_SIZE'])
    }
    return config

# Get prediction history from the webserver API
def get_prediction_history():
    try:
        response = requests.get(
            f"{CONFIG['api_base_url']}/prediction-history",
            params={"limit": CONFIG['history_limit']}
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        st.error(f"Error fetching prediction history: {e}")
        return []

# Get prediction from the webserver API
def get_prediction(image_data):
    try:
        if image_data is not None and len(image_data.shape) == 3:
            image_data_list = image_data.tolist()
            response = requests.post(
                f"{CONFIG['api_base_url']}/predict",
                json={"image_data": image_data_list}
            )
            response.raise_for_status()
            result = response.json()
            return result["predicted_digit"], result["confidence"]
        else:
            st.error("Invalid image data")
            return None, None
    except requests.exceptions.RequestException as e:
        st.error(f"Error getting prediction from server: {e}")
        return None, None

# Log a prediction using the webserver API
def log_prediction(predicted_digit, confidence, true_label):
    try:
        response = requests.post(
            f"{CONFIG['api_base_url']}/log-prediction",
            json={
                "predicted_digit": predicted_digit,
                "confidence": confidence,
                "true_label": true_label
            }
        )
        response.raise_for_status()
        return True
    except requests.exceptions.RequestException as e:
        st.error(f"Error logging prediction: {e}")
        return False

# Main function to run the webapp
def main():
    st.title("Digit Recogniser")
    
    # Create two equal columns for layout
    col1, col2 = st.columns(2)
    
    # Drawing canvas in the left column
    with col1:
        canvas_result = st_canvas(
            fill_color="black",
            stroke_width=20,
            stroke_color="white",
            background_color="black",
            width=CONFIG['canvas_size'],
            height=CONFIG['canvas_size'],
            drawing_mode="freedraw",
            key="canvas",
        )
    
    # Prediction area in the right column
    with col2:
        # Process image if it exists and has been drawn on
        if (canvas_result.image_data is not None and 
            canvas_result.json_data is not None and 
            canvas_result.json_data["objects"]):  # Check if there are drawn objects
            # Get prediction from webserver
            predicted_digit, confidence = get_prediction(canvas_result.image_data)
            default_value = predicted_digit if predicted_digit is not None else 0
        else:
            predicted_digit = None
            confidence = None
            default_value = 0
        
        # Layout with aligned labels and values
        label_col, value_col = st.columns([0.3, 0.7])
        
        with label_col:
            st.write("Prediction:")
            st.write("Confidence:")
            st.write("True label:")
            st.write("")
        
        with value_col:
            st.write(f"{predicted_digit if predicted_digit is not None else 'N/A'}")
            st.write(f"{confidence*100:.0f}%" if confidence is not None else "N/A")
            true_label = st.number_input("", 
                                       min_value=0, 
                                       max_value=9, 
                                       value=default_value,
                                       step=1,
                                       label_visibility="collapsed")
            if st.button("Submit"):
                if predicted_digit is not None and confidence is not None:
                    if log_prediction(predicted_digit, confidence, true_label):
                        st.info("Prediction logged successfully")
                    else:
                        st.warning("Failed to log prediction")
                else:
                    st.warning("No prediction available to log")
    
    st.subheader("History")
    predictions = get_prediction_history()
    if predictions:
        st.dataframe(
            data=predictions,
            column_config={
                "timestamp": st.column_config.DatetimeColumn(
                    "Timestamp",
                    format="YYYY-MM-DD HH:mm:ss"
                ),
                "predicted_digit": "Predicted Digit",
                "true_label": "True Label",
                "confidence": st.column_config.NumberColumn(
                    "Confidence",
                    format="%.2f"
                )
            },
            hide_index=True
        )
    else:
        st.info("No predictions have been made yet")

ENV_VARS = {
    'WEBSERVER_SERVICE_NAME': None,
    'WEBSERVER_PORT': None,
    'PREDICTION_HISTORY_LIMIT': None,
    'MNIST_DATASET_IMAGE_SIZE': None,
}
CONFIG = load_environment_variables()

if __name__ == '__main__':
    main()